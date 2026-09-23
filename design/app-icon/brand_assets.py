"""生成应用内品牌素材 + 主题封面（几何全部来自 mark_geometry，避免改一处漏一处）。

输出：
    out/concept-a-paw-heart.svg                      App 图标前景层
    entry/.../media/brand_mark_cream.png             奶白爪印，配橙色底
    entry/.../media/brand_mark_orange.png            橙色爪印，配白色底
    entry/.../media/brand_icon.png                   圆角小图标，配启动封面/关于页
    out/store-cover.png                              1080×1920 主题封面
    out/store-216.png                                应用市场图标
"""
import sys
from pathlib import Path

from PIL import Image

from mark_geometry import body, cover_mark_svg, write_icon_source
from render import OUT, ROOT, masked, shoot, mask

ENTRY_MEDIA = ROOT.parent.parent / "entry" / "src" / "main" / "resources" / "base" / "media"
CANVAS = 1024
FILL_RATIO = 0.78   # App 内素材里主体的占比，比图标留白少一点
COVER_MARK_HEIGHT = 330

PALETTES = {
    # 用在橙色/深色底上：奶白主体 + 明显一点的高光
    "cream": {"stops": [("#FFFFFF", 0), ("#FFF7F4", 0.55), ("#FFE6D8", 1)], "sheen": 0.45},
    # 用在白色卡片上：橙色主体，高光收敛，避免看起来像脏点
    "orange": {"stops": [("#FFB27C", 0), ("#FF8A5B", 0.5), ("#EF6A37", 1)], "sheen": 0.2},
}


def mark_svg(palette: str, transform: str) -> str:
    stops = "\n".join(
        f'      <stop offset="{offset}" stop-color="{color}"/>'
        for color, offset in PALETTES[palette]["stops"]
    )
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{CANVAS}" height="{CANVAS}"
  viewBox="0 0 {CANVAS} {CANVAS}">
  <defs>
    <linearGradient id="markGrad" x1="0.2" y1="0" x2="0.8" y2="1">
{stops}
    </linearGradient>
  </defs>
  <g transform="{transform}">
    <g transform="rotate(-8 512 545)">
      {body('url(#markGrad)', PALETTES[palette]['sheen'])}
    </g>
  </g>
</svg>"""


def main() -> int:
    # 1) 图标前景层（供 apply_icon.py / render.py 使用）
    write_icon_source(OUT / "concept-a-paw-heart.svg")

    # 2) 量出标记范围，算居中和放大
    probe = OUT / "mark-probe.svg"
    probe.write_text(mark_svg("cream", "none"), encoding="utf-8")
    box = Image.open(shoot("mark-probe", ["out/mark-probe.svg"], out_dir=OUT)).convert("RGBA").getbbox()
    cx = (box[0] + box[2]) / 2
    cy = (box[1] + box[3]) / 2
    height = box[3] - box[1]
    scale = FILL_RATIO * CANVAS / max(box[2] - box[0], height)
    transform = (f"translate({CANVAS / 2} {CANVAS / 2}) scale({scale:.4f}) "
                 f"translate({-cx:.2f} {-cy:.2f})")
    print(f"mark bbox={box} center=({cx:.0f},{cy:.0f}) scale={scale:.3f}")

    # 3) 应用内品牌素材
    ENTRY_MEDIA.mkdir(parents=True, exist_ok=True)
    for name in ("cream", "orange"):
        src = OUT / f"mark-{name}.svg"
        src.write_text(mark_svg(name, transform), encoding="utf-8")
        shoot(f"brand_mark_{name}", [f"out/mark-{name}.svg"], size=256,
              out_dir=ENTRY_MEDIA, asset_dir=ROOT)

    icon = Image.open(shoot("preview-a", ["background.svg", "out/concept-a-paw-heart.svg"])).convert("RGBA")
    icon = icon.resize((256, 256), Image.LANCZOS)
    icon.putalpha(mask(256, "squircle"))
    icon.save(ENTRY_MEDIA / "brand_icon.png")

    # 4) 主题封面：底 → 标记 → 文字 三层叠出来
    cover_scale = COVER_MARK_HEIGHT / height
    (OUT / "cover-mark.svg").write_text(
        cover_mark_svg(1080, 1920, 540, 430, cover_scale), encoding="utf-8")
    shoot("store-cover",
          ["store-cover-bg.svg", "out/cover-mark.svg", "store-cover-text.svg"],
          size=(1080, 1920), out_dir=OUT)

    # 5) 应用市场图标
    masked(Image.open(OUT / "preview-a.png").convert("RGBA"), 216, "squircle").save(OUT / "store-216.png")

    print("wrote:", ", ".join(p.name for p in sorted(ENTRY_MEDIA.glob("brand_*.png"))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
