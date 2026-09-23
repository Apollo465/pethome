"""爪心标记的唯一几何来源。

标记 = 四个脚趾（爪）+ 心形掌垫（心）+ 高光 + 一颗星火（AI）。
图标前景、应用内品牌素材、主题封面三处都从这里取，改一处即可全局生效。

坐标系固定为 1024×1024 画布；各处的旋转/缩放/投影由调用方在外面包一层。
"""

# 四个脚趾：外侧略小、整体呈扇形，读起来是"爪"
TOES = """
    <ellipse cx="352" cy="450" rx="54" ry="71" transform="rotate(-26 352 450)"/>
    <ellipse cx="452" cy="382" rx="58" ry="78" transform="rotate(-9 452 382)"/>
    <ellipse cx="572" cy="382" rx="58" ry="78" transform="rotate(9 572 382)"/>
    <ellipse cx="672" cy="450" rx="54" ry="71" transform="rotate(26 672 450)"/>
"""

# 主掌垫：一颗心。凹口加深、占比略大，"心"的读法更明确；脚趾保持原来的体量，"爪"也不丢
PAD = """
    <path d="M512 842
      C384 740 316 664 316 594
      C316 524 378 484 425 484
      C470 484 500 510 512 566
      C524 510 554 484 599 484
      C646 484 708 524 708 594
      C708 664 640 740 512 842 Z"/>
"""

# 掌垫左上的柔光
SHEEN = """
    <ellipse cx="436" cy="600" rx="46" ry="27" fill="#FFFFFF" opacity="__SHEEN__"
      transform="rotate(-28 436 600)"/>
"""

# 星火：右上角那一点灵光，代表 AI。刻意不做成机器人
SPARK = """
    <path d="M786 274
      C797 318 808 327 844 340
      C808 353 797 362 786 406
      C775 362 764 353 728 340
      C764 327 775 318 786 274 Z"/>
    <circle cx="712" cy="240" r="18" opacity="0.9"/>
"""

PATHS = TOES + PAD + SHEEN + SPARK


def body(fill: str, sheen: float = 0.45) -> str:
    """返回标记本体（不含外层变换），fill 可以是颜色或 url(#grad)。"""
    return f'<g fill="{fill}">\n{PATHS.replace("__SHEEN__", str(sheen))}\n  </g>'


def icon_foreground_svg(canvas: int = 1024) -> str:
    """App 图标的前景层：带投影、整体倾斜、并在安全区内放大一点。"""
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{canvas}" height="{canvas}" viewBox="0 0 {canvas} {canvas}">
  <defs>
    <linearGradient id="padA" x1="0.2" y1="0" x2="0.8" y2="1">
      <stop offset="0" stop-color="#FFFFFF"/>
      <stop offset="0.55" stop-color="#FFF7F4"/>
      <stop offset="1" stop-color="#FFE6D8"/>
    </linearGradient>
    <filter id="shadowA" x="-40%" y="-40%" width="180%" height="180%">
      <feDropShadow dx="0" dy="18" stdDeviation="20" flood-color="#8E3A12" flood-opacity="0.30"/>
    </filter>
  </defs>
  <g transform="translate(540 528) scale(1.06) translate(-540 -528)">
    <g filter="url(#shadowA)" transform="rotate(-8 512 545)">
      {body('url(#padA)', 0.45)}
    </g>
  </g>
</svg>"""


def cover_mark_svg(canvas_w: int, canvas_h: int, cx: float, cy: float, scale: float,
                   fill: str = 'url(#coverMark)') -> str:
    """主题封面里用的标记：透明画布，标记放在 (cx, cy) 并按 scale 缩放。"""
    # 标记原始包围盒中心约在 (546, 514)
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{canvas_w}" height="{canvas_h}"
  viewBox="0 0 {canvas_w} {canvas_h}">
  <defs>
    <linearGradient id="coverMark" x1="0.2" y1="0" x2="0.8" y2="1">
      <stop offset="0" stop-color="#FFFFFF"/>
      <stop offset="0.55" stop-color="#FFF7F4"/>
      <stop offset="1" stop-color="#FFE6D8"/>
    </linearGradient>
  </defs>
  <g transform="translate({cx} {cy}) scale({scale}) translate(-546 -514)">
    <g transform="rotate(-8 512 545)">
      {body(fill, 0.45)}
    </g>
  </g>
</svg>"""


def write_icon_source(path) -> str:
    """把图标前景层写成一个 SVG 文件，供渲染/打包脚本使用。"""
    from pathlib import Path as _Path

    p = _Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(icon_foreground_svg(), encoding="utf-8")
    return str(p)
