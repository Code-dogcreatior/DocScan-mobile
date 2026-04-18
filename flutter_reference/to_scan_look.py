"""
Post-process images in rectified/ to a perfect scanner-like appearance.
Uses Normalized Convolution Background Estimation to perfectly preserve colors.
"""

import argparse
import os
import cv2
import numpy as np

IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".bmp", ".tif", ".tiff", ".webp"}

def _odd(n: int) -> int:
    n = int(n)
    return n if n % 2 == 1 else n + 1

# ==============================================================================
# 终极 Adaptive 模式：归一化卷积背景估计 + 等比例色彩无损拉伸
# ==============================================================================
def to_scan_adaptive(
    bgr: np.ndarray,
    sharpen: bool = True,
    preserve_color_blocks: bool = True,
    color_sat_th: int = 64,
    color_chroma_th: int = 72,
    color_min_area_ratio: float = 0.008,
    color_blend: float = 0.28,
    ink_boost: float = 0.22,
    ink_sat_max: int = 70,
    ink_val_max: int = 175,
) -> np.ndarray:
    """
    自适应高清彩色扫描算法（无色偏版）：
    1. 归一化卷积提取完美的彩色光照贴图，防止文字色彩污染背景。
    2. 逐像素白平衡除法，完美消灭折痕和纸张底色（如蓝色/黄色发暗）。
    3. 基于 Value 的比例缩放，压黑文字的同时，保证彩色墨水 100% 不偏色。
    """
    h, w = bgr.shape[:2]
    
    # ---------------------------------------------------------
    # 第一步：提取完美无瑕的彩色背景光照图 (Normalized Convolution)
    # ---------------------------------------------------------
    # 缩小图像以获得巨大的感受野并提升速度
    work_size = 600
    scale = max(1.0, max(w, h) / work_size)
    sw, sh = int(w / scale), int(h / scale)
    small_bgr = cv2.resize(bgr, (sw, sh), interpolation=cv2.INTER_AREA)
    small_gray = cv2.cvtColor(small_bgr, cv2.COLOR_BGR2GRAY)
    
    # 用形态学膨胀找到局部的“纸张最亮值”
    k_morph = _odd(max(15, min(sw, sh) // 15))
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (k_morph, k_morph))
    bg_gray_small = cv2.dilate(small_gray, kernel)
    
    # 生成纸张蒙版：只保留那些接近局部最亮值的像素（文字部分变为0）
    paper_mask = (small_gray.astype(np.float32) > (bg_gray_small.astype(np.float32) - 25.0)).astype(np.float32)
    paper_mask_3d = np.expand_dims(paper_mask, axis=2)
    
    # 使用极大的高斯模糊进行“归一化卷积”晕染
    k_blur = _odd(max(31, min(sw, sh) // 5))
    sum_color = cv2.GaussianBlur(small_bgr.astype(np.float32) * paper_mask_3d, (k_blur, k_blur), 0)
    sum_weight = cv2.GaussianBlur(paper_mask, (k_blur, k_blur), 0)
    sum_weight_3d = np.expand_dims(sum_weight, axis=2) + 1e-6
    
    # 得到纯净的背景图（包含折痕阴影和纸张色偏，但没有任何文字的颜色）
    bg_bgr_small = sum_color / sum_weight_3d
    bg_bgr = cv2.resize(bg_bgr_small, (w, h), interpolation=cv2.INTER_CUBIC)
    
    # ---------------------------------------------------------
    # 第二步：消除阴影与纸张色偏 (Flatten Illumination)
    # ---------------------------------------------------------
    # BGR 直接除以 BGR 背景：带有蓝色色偏的折痕被除以蓝色的背景，直接变成纯白！
    # 这种物理除法相当于为每一个像素做了精确的白平衡。
    flat_bgr = (bgr.astype(np.float32) / (bg_bgr + 1e-6)) * 255.0
    flat_bgr = np.clip(flat_bgr, 0, 255)
    
    # ---------------------------------------------------------
    # 第三步：对比度拉伸（绝对保色法）
    # ---------------------------------------------------------
    # 为了让黑字更黑，我们不能直接减去一个常量（会改变色彩比例）。
    # 我们提取最大亮度值 (Value)，计算一个缩放比例系数，然后等比例应用给 RGB。
    val = np.max(flat_bgr, axis=2)
    
    # 自适应寻找图片的“黑点”
    black_pt = np.percentile(val, 2)
    black_pt = np.clip(black_pt, 10, 80)
    white_pt = 240.0 # 大于 240 的认为是白纸，强制拉白
    
    # 对亮度进行线性拉伸
    val_new = (val - black_pt) * (255.0 / max(1.0, white_pt - black_pt))
    val_new = np.clip(val_new, 0, 255)
    
    # 计算新亮度与旧亮度的比值
    ratio = val_new / (val + 1e-6)
    
    # 等比例缩放 BGR。因为 R,G,B 乘以相同的系数，色相 (Hue) 绝对不会发生任何改变！
    final_bgr = flat_bgr * np.expand_dims(ratio, axis=-1)
    final_bgr = np.clip(final_bgr, 0, 255).astype(np.uint8)
    
    # ---------------------------------------------------------
    # 第四步：稳健彩色块保护 + 背景纯白化
    # ---------------------------------------------------------
    # 只保护“高饱和 + 高色度 + 面积足够大”的彩色区域，避免把大面积蓝灰纸底误判为彩色。
    protect_mask = np.zeros((h, w), dtype=np.uint8)
    if preserve_color_blocks:
        hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)
        sat = hsv[:, :, 1].astype(np.int16)
        max_c = np.max(bgr, axis=2).astype(np.int16)
        min_c = np.min(bgr, axis=2).astype(np.int16)
        chroma = max_c - min_c

        cand = ((sat >= int(color_sat_th)) & (chroma >= int(color_chroma_th))).astype(np.uint8)
        # 先做闭运算填孔，再按连通域过滤小块噪声。
        cand = cv2.morphologyEx(
            cand,
            cv2.MORPH_CLOSE,
            cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7)),
        )
        n, labels, stats, _ = cv2.connectedComponentsWithStats(cand, connectivity=8)
        min_area = int(max(800, h * w * float(color_min_area_ratio)))
        for i in range(1, n):
            if stats[i, cv2.CC_STAT_AREA] >= min_area:
                protect_mask[labels == i] = 1

        blend = float(np.clip(color_blend, 0.0, 1.0))
        if blend > 0.0 and np.any(protect_mask):
            mixed = (
                final_bgr.astype(np.float32) * (1.0 - blend)
                + bgr.astype(np.float32) * blend
            )
            mixed = np.clip(mixed, 0, 255).astype(np.uint8)
            final_bgr[protect_mask == 1] = mixed[protect_mask == 1]

    # 彩色保护区也允许轻度白化，避免“保色过头”导致整页发灰。
    white_thresh = 236
    white_mask = np.min(final_bgr, axis=2) > white_thresh
    final_bgr[white_mask] = 255
    
    # ---------------------------------------------------------
    # 第五步：仅针对疑似文字区域进行压黑（避免影响彩色区域）
    # ---------------------------------------------------------
    boost = float(np.clip(ink_boost, 0.0, 0.6))
    if boost > 0.0:
        hsv_out = cv2.cvtColor(final_bgr, cv2.COLOR_BGR2HSV)
        sat_out = hsv_out[:, :, 1]
        val_out = hsv_out[:, :, 2]
        ink_mask = ((sat_out <= int(ink_sat_max)) & (val_out <= int(ink_val_max))).astype(np.float32)
        ink_mask = cv2.GaussianBlur(ink_mask, (5, 5), 0)
        ink_mask = np.clip(ink_mask, 0.0, 1.0)[..., None]
        darkened = final_bgr.astype(np.float32) * (1.0 - boost)
        final_bgr = (
            final_bgr.astype(np.float32) * (1.0 - ink_mask)
            + darkened * ink_mask
        )
        final_bgr = np.clip(final_bgr, 0, 255).astype(np.uint8)
    
    # ---------------------------------------------------------
    # 第六步：适度锐化文字
    # ---------------------------------------------------------
    if sharpen:
        blurred = cv2.GaussianBlur(final_bgr, (0, 0), 1.5)
        final_bgr = cv2.addWeighted(final_bgr, 1.5, blurred, -0.5, 0)
        
    return final_bgr


def process_image(bgr: np.ndarray, args) -> np.ndarray:
    return to_scan_adaptive(
        bgr,
        sharpen=not args.no_sharpen,
        preserve_color_blocks=not args.no_preserve_color_blocks,
        color_sat_th=args.color_sat_th,
        color_chroma_th=args.color_chroma_th,
        color_min_area_ratio=args.color_min_area_ratio,
        color_blend=args.color_blend,
        ink_boost=args.ink_boost,
        ink_sat_max=args.ink_sat_max,
        ink_val_max=args.ink_val_max,
    )


def list_images(folder: str):
    for name in sorted(os.listdir(folder)):
        ext = os.path.splitext(name)[1].lower()
        if ext in IMAGE_EXTS:
            yield name


def main():
    parser = argparse.ArgumentParser(
        description="Turn rectified document images into perfect scanner-style output."
    )
    parser.add_argument(
        "--input",
        "-i",
        default="./rectified",
        help="Folder containing rectified images (default: ./rectified)",
    )
    parser.add_argument(
        "--output",
        "-o",
        default="./rectified_scan",
        help="Output folder (default: ./rectified_scan)",
    )
    parser.add_argument(
        "--no-sharpen",
        action="store_true",
        help="Disable image sharpening.",
    )
    parser.add_argument(
        "--no-preserve-color-blocks",
        action="store_true",
        help="Disable large colorful block protection.",
    )
    parser.add_argument(
        "--color-sat-th",
        type=int,
        default=64,
        help="HSV saturation threshold for colorful block protection (default: 64).",
    )
    parser.add_argument(
        "--color-chroma-th",
        type=int,
        default=72,
        help="RGB chroma threshold for colorful block protection (default: 72).",
    )
    parser.add_argument(
        "--color-min-area-ratio",
        type=float,
        default=0.008,
        help="Minimum connected area ratio to protect as colorful block (default: 0.008).",
    )
    parser.add_argument(
        "--color-blend",
        type=float,
        default=0.28,
        help="Blend ratio of original color in protected regions, 0-1 (default: 0.28).",
    )
    parser.add_argument(
        "--ink-boost",
        type=float,
        default=0.22,
        help="Selective text darkening strength, 0-0.6 (default: 0.22).",
    )
    parser.add_argument(
        "--ink-sat-max",
        type=int,
        default=70,
        help="Max saturation considered as text-like region (default: 70).",
    )
    parser.add_argument(
        "--ink-val-max",
        type=int,
        default=175,
        help="Max value considered as text-like region (default: 175).",
    )
    args = parser.parse_args()

    in_dir = os.path.abspath(args.input)
    out_dir = os.path.abspath(args.output)
    
    if not os.path.isdir(in_dir):
        print(f"输入目录未找到: {in_dir}")
        return
        
    os.makedirs(out_dir, exist_ok=True)

    names = list(list_images(in_dir))
    if not names:
        print(f"目录中没有找到图片: {in_dir}")
        return

    ok_count = 0
    for name in names:
        path = os.path.join(in_dir, name)
        bgr = cv2.imread(path)
        if bgr is None:
            print(f"跳过（读取失败）: {path}")
            continue
            
        out = process_image(bgr, args)
        
        out_path = os.path.join(out_dir, name)
        success = cv2.imwrite(out_path, out)
        if success:
            ok_count += 1
            print(f"处理成功: {out_path}")
        else:
            print(f"保存失败: {out_path}")

    print(f"\n全部完成！共处理 {ok_count}/{len(names)} 张图片。")

if __name__ == "__main__":
    main()