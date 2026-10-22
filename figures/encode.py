"""Encode a folder of PNG frames into one looping animated WebP.

    uv run --with pillow python figures/encode.py <frames-dir> <out.webp> [--fps 20] [--quality 82]

Flutter decodes animated WebP with `Image.asset` (one file per figure and theme,
much smaller than a frame sequence of PNGs).
"""
import argparse
import glob
import os

from PIL import Image


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("frames")
    parser.add_argument("out")
    parser.add_argument("--fps", type=float, default=20.0)
    parser.add_argument("--quality", type=int, default=82)
    args = parser.parse_args()

    paths = sorted(glob.glob(os.path.join(args.frames, "*.png")))
    if not paths:
        raise SystemExit(f"no frames in {args.frames}")

    frames = [Image.open(path).convert("RGB").convert("RGBA") for path in paths]
    first = frames[0]
    if len(frames) == 1:
        first.save(args.out, format="WEBP", quality=args.quality, method=6)
    else:
        first.save(
            args.out,
            format="WEBP",
            save_all=True,
            append_images=frames[1:],
            duration=round(1000 / args.fps),
            loop=0,
            quality=args.quality,
            method=6,
        )
    size = os.path.getsize(args.out) / 1024
    print(f"{args.out}  {len(frames)} frames  {size:.0f} KB")


if __name__ == "__main__":
    main()
