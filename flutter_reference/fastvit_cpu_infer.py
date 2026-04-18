import argparse
import json
from pathlib import Path

import cv2
import numpy as np
import onnxruntime as ort


MODEL_PATH = Path(__file__).resolve().parent / "fastvit_sa24_h_e_bifpn_256_fp32.onnx"
INPUT_SIZE = 256
THRESHOLD = 0.3
PREWARM_RUNS = 3


class FastvitCpuInfer:
    def __init__(self, model_path: Path = MODEL_PATH):
        if not model_path.exists():
            raise FileNotFoundError(f"Model not found: {model_path}")
        self.session = ort.InferenceSession(str(model_path), providers=["CPUExecutionProvider"])
        self.input_name = self.session.get_inputs()[0].name
        self.output_names = [o.name for o in self.session.get_outputs()]
        if "heatmap" not in self.output_names:
            raise RuntimeError(f"Unexpected model outputs: {self.output_names}")
        self._prewarm()

    def _prewarm(self) -> None:
        dummy = np.zeros((1, 3, INPUT_SIZE, INPUT_SIZE), dtype=np.float32)
        for _ in range(PREWARM_RUNS):
            self.session.run(None, {self.input_name: dummy})

    @staticmethod
    def _preprocess(image_bgr: np.ndarray) -> tuple[np.ndarray, tuple[int, int]]:
        h, w = image_bgr.shape[:2]
        resized = cv2.resize(image_bgr, (INPUT_SIZE, INPUT_SIZE), interpolation=cv2.INTER_LINEAR)
        x = resized.transpose(2, 0, 1).astype(np.float32)[None] / 255.0
        return x, (h, w)

    @staticmethod
    def _postprocess(heatmap: np.ndarray, original_hw: tuple[int, int]) -> np.ndarray:
        h, w = original_hw
        corners = []
        for ch in heatmap[0][:4]:
            hm = cv2.resize(ch.astype(np.float32), (w, h), interpolation=cv2.INTER_LINEAR)
            mask = (hm >= THRESHOLD).astype(np.uint8) * 255
            contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            if not contours:
                continue
            contour = max(contours, key=cv2.contourArea)
            m = cv2.moments(contour)
            if abs(m["m00"]) < 1e-6:
                continue
            corners.append([float(m["m10"] / m["m00"]), float(m["m01"] / m["m00"])])
        return np.asarray(corners, dtype=np.float32)

    @staticmethod
    def _order_points_clockwise(pts: np.ndarray) -> np.ndarray:
        if pts.shape != (4, 2):
            raise ValueError("Expected exactly 4 points for perspective transform.")
        center = np.mean(pts, axis=0)
        angles = np.arctan2(pts[:, 1] - center[1], pts[:, 0] - center[0])
        idx = np.argsort(angles)
        ordered = pts[idx]
        start = np.argmin(ordered.sum(axis=1))
        ordered = np.roll(ordered, -start, axis=0)
        return ordered.astype(np.float32)

    @classmethod
    def _rectify_document(cls, image_bgr: np.ndarray, polygon: np.ndarray) -> np.ndarray:
        pts = cls._order_points_clockwise(polygon)
        tl, tr, br, bl = pts

        width_top = np.linalg.norm(tr - tl)
        width_bottom = np.linalg.norm(br - bl)
        max_w = max(int(round(width_top)), int(round(width_bottom)))

        height_right = np.linalg.norm(br - tr)
        height_left = np.linalg.norm(bl - tl)
        max_h = max(int(round(height_right)), int(round(height_left)))

        max_w = max(32, max_w)
        max_h = max(32, max_h)

        dst = np.array(
            [[0, 0], [max_w - 1, 0], [max_w - 1, max_h - 1], [0, max_h - 1]],
            dtype=np.float32,
        )
        m = cv2.getPerspectiveTransform(pts, dst)
        return cv2.warpPerspective(image_bgr, m, (max_w, max_h), flags=cv2.INTER_CUBIC)

    def infer(self, image_path: Path) -> dict:
        image_bgr = cv2.imread(str(image_path), cv2.IMREAD_COLOR)
        if image_bgr is None:
            raise FileNotFoundError(f"Cannot read image: {image_path}")
        x, original_hw = self._preprocess(image_bgr)
        outputs = self.session.run(None, {self.input_name: x})
        out_map = {k: v for k, v in zip(self.output_names, outputs)}
        polygon = self._postprocess(out_map["heatmap"], original_hw)

        rectified_path = ""
        if polygon.shape == (4, 2):
            rectified = self._rectify_document(image_bgr, polygon)
            save_dir = Path(__file__).resolve().parent
            rectified_file = save_dir / f"{image_path.stem}_fastvit_rectified.jpg"
            cv2.imwrite(str(rectified_file), rectified)
            rectified_path = str(rectified_file)

        return {
            "image": str(image_path),
            "model": str(MODEL_PATH),
            "provider": "CPUExecutionProvider",
            "prewarm_runs": PREWARM_RUNS,
            "corners_found": int(len(polygon)),
            "polygon": polygon.tolist(),
            "rectified_image": rectified_path,
        }


def main() -> None:
    parser = argparse.ArgumentParser(description="Fastvit SA24 CPU-only document corner inference.")
    parser.add_argument("image", type=Path, help="Input image path")
    args = parser.parse_args()

    engine = FastvitCpuInfer()
    result = engine.infer(args.image)
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
