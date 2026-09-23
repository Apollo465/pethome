"""爪心 App 图标渲染/预览脚本。

把 design/app-icon 下的 SVG 渲染成 PNG（方案 A 的前景层由 mark_geometry.py 生成）：
  * out/bg.png            底色层（1024，不透明）
  * out/fg-<concept>.png  前景层（1024，透明）
  * out/preview-<style>.png  底色+前景 的模拟应用图标（不透明）
  * out/contact-sheet.png 方案对照图，含圆角/圆形遮罩与 72px 小尺寸

依赖：Edge（Chromium）无头渲染 + Pillow。只用标准库和 Pillow，不改动工程源码。
"""
import html
import shutil
import subprocess
import sys
import time
from pathlib import Path

from PIL import Image, ImageDraw

from mark_geometry import write_icon_source

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "out"
RENDER = ROOT / "render"
EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
SIZE = 1024

CONCEPTS = {
    # 方案 A 的前景层由 mark_geometry.py 生成，保证和 App 内品牌素材同一套几何
    "a": "out/concept-a-paw-heart.svg",
    "b": "concept-b-chat-cat.svg",
    "c": "concept-c-heart-pet.svg",
}


def _wh(size) -> tuple[int, int]:
    if isinstance(size, (tuple, list)):
        return int(size[0]), int(size[1])
    return int(size), int(size)


def page(layers: list[str], size=SIZE) -> str:
    w, h = _wh(size)
    uris = []
    for name in layers:
        # 允许传绝对路径（其它目录的脚本会这么用）
        path = Path(name)
        resolved = path if path.is_absolute() else ROOT / name
        uris.append(f'<img class="layer" src="{html.escape(resolved.resolve().as_uri())}" alt="">')
    imgs = "\n".join(uris)
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>
html,body{{margin:0;padding:0;background:transparent;overflow:hidden}}
#stage{{position:relative;width:{w}px;height:{h}px}}
.layer{{position:absolute;left:0;top:0;width:{w}px;height:{h}px;display:block}}
</style></head><body><div id="stage">{imgs}</div></body></html>"""


def shoot(name: str, layers: list[str], size=SIZE, out_dir: Path | None = None,
          asset_dir: Path | None = None) -> Path:
    """把若干 SVG 叠加渲染成 PNG。

    name/layers 是相对 design/app-icon 的文件名；输出默认落在 out/，
    也可以指定 out_dir，以及 layers 所在的目录 asset_dir。
    """
    RENDER.mkdir(parents=True, exist_ok=True)
    target_dir = out_dir or OUT
    target_dir.mkdir(parents=True, exist_ok=True)
    if asset_dir is not None and asset_dir != ROOT:
        layers = [str((asset_dir / Path(n).name).relative_to(ROOT)) for n in layers]
    page_path = RENDER / f"{name}.html"
    page_path.write_text(page(layers, size), encoding="utf-8")
    png = target_dir / f"{name}.png"
    w, h = _wh(size)
    if png.exists():
        png.unlink()
    cmd = [
        EDGE,
        "--headless=new",
        "--disable-gpu",
        "--hide-scrollbars",
        "--no-first-run",
        "--no-default-browser-check",
        f"--user-data-dir={RENDER / ('profile-' + name)}",
        "--default-background-color=00000000",
        "--force-device-scale-factor=1",
        "--virtual-time-budget=3000",
        f"--window-size={w},{h}",
        f"--screenshot={png}",
        page_path.as_uri(),
    ]
    profile = RENDER / f"profile-{name}"
    try:
        subprocess.run(cmd, check=True, capture_output=True)
        # Chromium 的启动进程会先返回，截图是异步落盘的，这里等文件稳定
        for _ in range(80):
            if png.exists() and png.stat().st_size > 0:
                first = png.stat().st_size
                time.sleep(0.2)
                if png.stat().st_size == first:
                    return png
            time.sleep(0.25)
        raise RuntimeError(f"screenshot not produced: {png}")
    finally:
        # 用完就删，别在工程里留一堆 Chromium profile
        shutil.rmtree(profile, ignore_errors=True)


def mask(size: int, style: str, ss: int = 4) -> Image.Image:
    """返回 size×size 的抗锯齿遮罩，style: 'squircle' | 'circle'。"""
    big = size * ss
    m = Image.new("L", (big, big), 0)
    d = ImageDraw.Draw(m)
    if style == "circle":
        d.ellipse((0, 0, big - 1, big - 1), fill=255)
    else:
        d.rounded_rectangle((0, 0, big - 1, big - 1), radius=int(big * 0.26), fill=255)
    return m.resize((size, size), Image.LANCZOS)


def masked(icon: Image.Image, size: int, style: str) -> Image.Image:
    im = icon.resize((size, size), Image.LANCZOS).convert("RGBA")
    im.putalpha(mask(size, style))
    return im


def main() -> None:
    write_icon_source(OUT / "concept-a-paw-heart.svg")
    shoot("bg", ["background.svg"])
    previews: list[tuple[str, Image.Image]] = []
    for key, svg in CONCEPTS.items():
        shoot(f"fg-{key}", [svg])
        shot = Image.open(shoot(f"preview-{key}", ["background.svg", svg])).convert("RGBA")
        previews.append((key, shot))

    # 对照图：每行一个方案，列出圆角遮罩 / 圆形遮罩 / 72px / 44px
    cell = 300
    pad = 26
    cols = [("squircle", cell), ("circle", cell), ("plain", 104), ("plain", 64)]
    width = pad + len(cols) * (cell + pad)
    height = pad + len(previews) * (cell + pad)
    sheet = Image.new("RGB", (width, height), "#F3F0EE")
    for row, (key, shot) in enumerate(previews):
        x = pad
        y = pad + row * (cell + pad)
        for style, size in cols:
            if style == "plain":
                tile = shot.resize((size, size), Image.LANCZOS)
                bg_tile = Image.new("RGB", (size, size), "#F3F0EE")
                bg_tile.paste(tile, (0, 0), tile)
                tile = bg_tile
                pos = (x, y + (cell - size) // 2)
            else:
                tile = masked(shot, size, style)
                bg_tile = Image.new("RGB", (size, size), "#F3F0EE")
                bg_tile.paste(tile, (0, 0), tile)
                tile = bg_tile
                pos = (x, y + (cell - size) // 2)
            sheet.paste(tile, pos)
            x += cell + pad
    sheet.save(OUT / "contact-sheet.png")

    # 上架用的静态图标：216×216，圆角遮罩，透明底
    masked(dict(previews)["a"], 216, "squircle").save(OUT / "store-216.png")

    print("rendered:", ", ".join(p.name for p in sorted(OUT.glob("*.png"))))
    print("concepts:", ", ".join(k for k, _ in previews))


if __name__ == "__main__":
    sys.exit(main())
