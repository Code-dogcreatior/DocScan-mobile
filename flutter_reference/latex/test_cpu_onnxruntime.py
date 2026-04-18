# -*- encoding: utf-8 -*-
"""CPU-only onnxruntime 独立测试脚本（不依赖rapid_latex_ocr模块）"""
import re
import time
from pathlib import Path
from typing import List, Tuple, Union

import cv2
import numpy as np
from onnxruntime import GraphOptimizationLevel, InferenceSession, SessionOptions
from PIL import Image
from tokenizers import Tokenizer
from tokenizers.models import BPE


# ==================== 配置 ====================
MODEL_DIR = Path(__file__).parent / "models"
MODEL_DIR.mkdir(parents=True, exist_ok=True)


# ==================== 模型路径 ====================
def get_model_path(file_name: str) -> Path:
    save_path = MODEL_DIR / file_name
    if not save_path.exists():
        raise FileNotFoundError(f"模型不存在: {save_path}")
    return save_path


# ==================== 工具函数 ====================
def verify_exist(model_path: Union[Path, str]):
    if not isinstance(model_path, Path):
        model_path = Path(model_path)
    if not model_path.exists():
        raise FileNotFoundError(f"{model_path} does not exist!")
    if not model_path.is_file():
        raise FileExistsError(f"{model_path} must be a file")


# ==================== OrtInferSession ====================
class OrtInferSession:
    def __init__(self, model_path: Union[str, Path], num_threads: int = -1):
        verify_exist(model_path)
        self.num_threads = num_threads
        self._init_sess_opt()

        cpu_ep = "CPUExecutionProvider"
        cpu_provider_options = {"arena_extend_strategy": "kSameAsRequested"}
        EP_list = [(cpu_ep, cpu_provider_options)]
        try:
            self.session = InferenceSession(
                str(model_path), sess_options=self.sess_opt, providers=EP_list
            )
        except TypeError:
            self.session = InferenceSession(str(model_path), sess_options=self.sess_opt)

    def _init_sess_opt(self):
        self.sess_opt = SessionOptions()
        self.sess_opt.log_severity_level = 4
        self.sess_opt.enable_cpu_mem_arena = False
        if self.num_threads != -1:
            self.sess_opt.intra_op_num_threads = self.num_threads
        self.sess_opt.graph_optimization_level = GraphOptimizationLevel.ORT_ENABLE_ALL

    def __call__(self, input_content: List[np.ndarray]) -> np.ndarray:
        input_dict = dict(zip(self.get_input_names(), input_content))
        return self.session.run(None, input_dict)

    def get_input_names(self):
        return [v.name for v in self.session.get_inputs()]


# ==================== LoadImage ====================
class LoadImage:
    def __call__(self, img: Union[str, Path, np.ndarray, bytes]) -> np.ndarray:
        if isinstance(img, (str, Path)):
            if not Path(img).exists():
                raise FileNotFoundError(f"Image not found: {img}")
            img = np.array(Image.open(img))
        elif isinstance(img, bytes):
            img = np.array(Image.open(io.BytesIO(img)))
        elif isinstance(img, np.ndarray):
            pass
        else:
            raise ValueError(f"Unsupported image type: {type(img)}")
        return self.convert_img(img)

    @staticmethod
    def convert_img(img: np.ndarray) -> np.ndarray:
        if img.ndim == 2:
            return cv2.cvtColor(img, cv2.COLOR_GRAY2BGR)
        if img.ndim == 3:
            channel = img.shape[2]
            if channel == 1:
                return cv2.cvtColor(img, cv2.COLOR_GRAY2BGR)
            if channel == 2:
                r, g = img[:, :, 0], img[:, :, 1]
                gray = (0.299 * r + 0.587 * g + 0.114 * r).astype(np.uint8)
                alpha = img[:, :, 1]
                not_a = 255 - alpha
                not_a_3ch = np.stack([not_a] * 3, axis=-1)
                result = np.where(alpha[:, :, None] > 0, np.stack([img[:, :, 0], img[:, :, 0], img[:, :, 0]], axis=-1), not_a_3ch).astype(np.uint8)
                return result
            if channel == 4:
                r, g, b, a = img[:, :, 0], img[:, :, 1], img[:, :, 2], img[:, :, 3]
                new_img = np.stack([b, g, r], axis=-1)
                not_a = 255 - a
                not_a_3ch = np.stack([not_a] * 3, axis=-1)
                result = np.where(a[:, :, None] > 0, new_img, not_a_3ch).astype(np.uint8)
                return result
            if channel == 3:
                return cv2.cvtColor(img, cv2.COLOR_RGB2BGR)
        raise ValueError(f"Unsupported image shape: {img.shape}")


# ==================== PreProcess ====================
class PreProcess:
    def __init__(self, max_dims: List[int], min_dims: List[int]):
        self.max_dims, self.min_dims = max_dims, min_dims
        self.mean = np.array([0.7931, 0.7931, 0.7931]).astype(np.float32)
        self.std = np.array([0.1738, 0.1738, 0.1738]).astype(np.float32)

    @staticmethod
    def pad(img: Image.Image, divable: int = 32) -> Image.Image:
        threshold = 128
        data = np.array(img.convert("LA"))
        if data[..., -1].var() == 0:
            data = (data[..., 0]).astype(np.uint8)
        else:
            data = (255 - data[..., -1]).astype(np.uint8)

        data = (data - data.min()) / (data.max() - data.min() + 1e-8) * 255
        if data.mean() > threshold:
            gray = 255 * (data < threshold).astype(np.uint8)
        else:
            gray = 255 * (data > threshold).astype(np.uint8)
            data = 255 - data

        coords = cv2.findNonZero(gray)
        a, b, w, h = cv2.boundingRect(coords)
        rect = data[b:b + h, a:a + w]
        im = Image.fromarray(rect).convert("L")
        dims = []
        for x in [w, h]:
            div, mod = divmod(x, divable)
            dims.append(divable * (div + (1 if mod > 0 else 0)))

        padded = Image.new("L", tuple(dims), 255)
        padded.paste(im, (0, 0, im.size[0], im.size[1]))
        return padded

    def minmax_size(self, img: Image.Image) -> Image.Image:
        if self.max_dims is not None:
            ratios = [a / b for a, b in zip(img.size, self.max_dims)]
            if any([r > 1 for r in ratios]):
                size = np.array(img.size) // max(ratios)
                size = np.maximum(size, 1)
                img = img.resize(tuple(size.astype(int)), Image.BILINEAR)

        if self.min_dims is not None:
            padded_size = [max(img_dim, min_dim) for img_dim, min_dim in zip(img.size, self.min_dims)]
            new_pad_size = tuple(padded_size)
            if new_pad_size != img.size:
                padded_im = Image.new("L", new_pad_size, 255)
                padded_im.paste(img, img.getbbox())
                img = padded_im
        return img

    def normalize(self, img: np.ndarray, max_pixel_value=255.0) -> np.ndarray:
        mean = self.mean * max_pixel_value
        std = self.std * max_pixel_value
        denominator = np.reciprocal(std, dtype=np.float32)
        img = img.astype(np.float32)
        img -= mean
        img *= denominator
        return img

    @staticmethod
    def to_gray(img) -> np.ndarray:
        gray = cv2.cvtColor(img, cv2.COLOR_RGB2GRAY)
        return cv2.cvtColor(gray, cv2.COLOR_GRAY2RGB)

    @staticmethod
    def transpose_and_four_dim(img: np.ndarray) -> np.ndarray:
        return img.transpose(2, 0, 1)[:1][None, ...]


# ==================== TokenizerCls ====================
class TokenizerCls:
    def __init__(self, json_file: Union[Path, str]):
        self.tokenizer = Tokenizer(BPE()).from_file(str(json_file))

    def token2str(self, tokens) -> List[str]:
        if len(tokens.shape) == 1:
            tokens = tokens[None, :]
        dec = [self.tokenizer.decode(tok.tolist()) for tok in tokens]
        return [
            "".join(detok.split(" "))
            .replace("Ġ", " ")
            .replace("[EOS]", "")
            .replace("[BOS]", "")
            .replace("[PAD]", "")
            .strip()
            for detok in dec
        ]


# ==================== Decoder ====================
class Decoder:
    def __init__(self, decoder_path: Union[Path, str]):
        self.max_seq_len = 512
        self.session = OrtInferSession(decoder_path)

    def __call__(self, start_tokens, seq_len=256, eos_token=None, temperature=1.0, filter_thres=0.9, context=None):
        num_dims = len(start_tokens.shape)
        b, t = start_tokens.shape
        out = start_tokens
        mask = np.full_like(start_tokens, True, dtype=bool)

        for _ in range(seq_len):
            x = out[:, -self.max_seq_len:]
            mask = mask[:, -self.max_seq_len:]
            ort_outs = self.session([x.astype(np.int64), mask, context])[0]
            np_preds = ort_outs
            np_logits = np_preds[:, -1, :]
            np_filtered_logits = self.npp_top_k(np_logits, thres=filter_thres)
            np_probs = self.softmax(np_filtered_logits / temperature, axis=-1)
            sample = self.multinomial(np_probs.squeeze(), 1)[None, ...]
            out = np.concatenate([out, sample], axis=-1)
            mask = np.pad(mask, [(0, 0), (0, 1)], "constant", constant_values=True)

            if eos_token is not None and (np.cumsum(out == eos_token, axis=1)[:, -1] >= 1).all():
                break

        out = out[:, t:]
        if num_dims == 1:
            out = out.squeeze(0)
        return out

    @staticmethod
    def softmax(x, axis=None):
        def logsumexp(a, axis=None, keepdims=False):
            a_max = np.amax(a, axis=axis, keepdims=True)
            if a_max.ndim > 0:
                a_max[~np.isfinite(a_max)] = 0
            elif not np.isfinite(a_max):
                a_max = 0
            tmp = np.exp(a - a_max)
            with np.errstate(divide="ignore"):
                s = np.sum(tmp, axis=axis, keepdims=keepdims)
                out = np.log(s)
            if not keepdims:
                a_max = np.squeeze(a_max, axis=axis)
            out += a_max
            return out
        return np.exp(x - logsumexp(x, axis=axis, keepdims=True))

    def npp_top_k(self, logits, thres=0.9):
        k = int((1 - thres) * logits.shape[-1])
        val, ind = self.np_top_k(logits, k)
        probs = np.full_like(logits, float("-inf"))
        np.put_along_axis(probs, ind, val, axis=1)
        return probs

    @staticmethod
    def np_top_k(a: np.ndarray, k: int, axis=-1, largest=True, sorted=True):
        if axis is None:
            axis_size = a.size
        else:
            axis_size = a.shape[axis]
        assert 1 <= k <= axis_size
        a = np.asanyarray(a)
        if largest:
            index_array = np.argpartition(a, axis_size - k, axis=axis)
            topk_indices = np.take(index_array, -np.arange(k) - 1, axis=axis)
        else:
            index_array = np.argpartition(a, k - 1, axis=axis)
            topk_indices = np.take(index_array, np.arange(k), axis=axis)
        topk_values = np.take_along_axis(a, topk_indices, axis=axis)
        if sorted:
            sorted_indices_in_topk = np.argsort(topk_values, axis=axis)
            if largest:
                sorted_indices_in_topk = np.flip(sorted_indices_in_topk, axis=axis)
            sorted_topk_values = np.take_along_axis(topk_values, sorted_indices_in_topk, axis=axis)
            sorted_topk_indices = np.take_along_axis(topk_indices, sorted_indices_in_topk, axis=axis)
            return sorted_topk_values, sorted_topk_indices
        return topk_values, topk_indices

    @staticmethod
    def multinomial(weights, num_samples, replacement=True):
        weights = np.asarray(weights)
        weights /= np.sum(weights)
        indices = np.arange(len(weights))
        return np.random.choice(indices, size=num_samples, replace=replacement, p=weights)


# ==================== EncoderDecoder ====================
class EncoderDecoder:
    def __init__(self, encoder_path, decoder_path, bos_token, eos_token, max_seq_len):
        self.bos_token = bos_token
        self.eos_token = eos_token
        self.max_seq_len = max_seq_len
        self.encoder = OrtInferSession(encoder_path)
        self.decoder = Decoder(decoder_path)

    def __call__(self, x: np.ndarray, temperature: float = 0.25):
        ort_input_data = np.array([self.bos_token] * len(x))[:, None]
        context = self.encoder([x])[0]
        output = self.decoder(
            ort_input_data,
            self.max_seq_len,
            eos_token=self.eos_token,
            context=context,
            temperature=temperature,
        )
        return output


# ==================== 模型路径 ====================
def get_model_path(file_name: str) -> Path:
    save_path = MODEL_DIR / file_name
    if not save_path.exists():
        raise FileNotFoundError(f"模型不存在: {save_path}")
    return save_path


# ==================== LaTeXOCR ====================
class LaTeXOCR:
    def __init__(self):
        self.image_resizer_path = get_model_path("image_resizer.onnx")
        self.encoder_path = get_model_path("encoder.onnx")
        self.decoder_path = get_model_path("decoder.onnx")
        self.tokenizer_json = get_model_path("tokenizer.json")

        self.max_dims = [672, 192]
        self.min_dims = [32, 32]
        self.temperature = 0.00001

        self.load_img = LoadImage()
        self.pre_pro = PreProcess(max_dims=self.max_dims, min_dims=self.min_dims)
        self.image_resizer = OrtInferSession(self.image_resizer_path)

        self.encoder_decoder = EncoderDecoder(
            encoder_path=self.encoder_path,
            decoder_path=self.decoder_path,
            bos_token=1,
            eos_token=2,
            max_seq_len=512,
        )
        self.tokenizer = TokenizerCls(self.tokenizer_json)

    def __call__(self, img: Union[str, Path, np.ndarray, bytes]) -> Tuple[str, float]:
        s = time.perf_counter()

        img = self.load_img(img)
        resizered_img = self.loop_image_resizer(img)
        dec = self.encoder_decoder(resizered_img, temperature=self.temperature)
        decode = self.tokenizer.token2str(dec)
        pred = self.post_process(decode[0])

        elapse = time.perf_counter() - s
        return pred, elapse

    def loop_image_resizer(self, img: np.ndarray) -> np.ndarray:
        pillow_img = Image.fromarray(img)
        pad_img = self.pre_pro.pad(pillow_img)
        input_image = self.pre_pro.minmax_size(pad_img).convert("RGB")
        r, w, h = 1, input_image.size[0], input_image.size[1]
        for _ in range(10):
            h = int(h * r)
            final_img, pad_img = self.pre_process(input_image, r, w, h)
            resizer_res = self.image_resizer([final_img.astype(np.float32)])[0]
            argmax_idx = int(np.argmax(resizer_res, axis=-1))
            w = (argmax_idx + 1) * 32
            if w == pad_img.size[0]:
                break
            r = w / pad_img.size[0]
        return final_img

    def pre_process(self, input_image: Image.Image, r, w, h) -> Tuple[np.ndarray, Image.Image]:
        if r > 1:
            resize_func = Image.Resampling.BILINEAR
        else:
            resize_func = Image.Resampling.LANCZOS
        resize_img = input_image.resize((w, h), resize_func)
        pad_img = self.pre_pro.pad(self.pre_pro.minmax_size(resize_img))
        cvt_img = np.array(pad_img.convert("RGB"))
        gray_img = self.pre_pro.to_gray(cvt_img)
        normal_img = self.pre_pro.normalize(gray_img)
        final_img = self.pre_pro.transpose_and_four_dim(normal_img)
        return final_img, pad_img

    @staticmethod
    def post_process(s: str) -> str:
        text_reg = r"(\\(operatorname|mathrm|text|mathbf)\s?\*? {.*?})"
        letter = "[a-zA-Z]"
        noletter = r"[\W_^\d]"
        names = [x[0].replace(" ", "") for x in re.findall(text_reg, s)]
        s = re.sub(text_reg, lambda match: str(names.pop(0)), s)
        news = s
        while True:
            s = news
            news = re.sub(r"(?!\\ )(%s)\s+?(%s)" % (noletter, noletter), r"\1\2", s)
            news = re.sub(r"(?!\\ )(%s)\s+?(%s)" % (noletter, letter), r"\1\2", news)
            news = re.sub(r"(%s)\s+?(%s)" % (letter, noletter), r"\1\2", news)
            if news == s:
                break
        return s


# ==================== 测试 ====================
if __name__ == "__main__":
    img_path = Path(__file__).parent / "ScreenShot_2026-04-02_093315_359.png"

    if not img_path.exists():
        print(f"图片不存在: {img_path}")
        exit(1)

    print(f"测试图片: {img_path}")
    print("-" * 50)

    print("初始化模型（CPU模式）...")
    model = LaTeXOCR()

    print("预热中...")
    _, _ = model(str(img_path))

    print("\n开始测试...")
    result, elapse = model(str(img_path))

    print("-" * 50)
    print(f"识别结果: {result}")
    print(f"识别时间: {elapse:.4f} 秒")
