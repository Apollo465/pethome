"""生成应用介绍图（应用市场用，1080×1920）以及可直接上传的纯截图。

做法：先用 Edge 渲染「底色 + 标题 + 品牌标记」的 SVG，再用 Pillow 把真机截图
按圆角裁切、加投影贴上去。截图会裁掉系统状态栏，只留 App 内容。

输出：
    design/store/out/promo-1..N.png    带标题的应用介绍图
    design/store/out/screenshot-1..N.png  纯截图（未加任何装饰）
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "app-icon"))
from mark_geometry import body  # noqa: E402  同一套爪心几何
from render import shoot  # noqa: E402

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "out"
SHOTS_DIR = ROOT / "shots"

W, H = 1080, 1920
SHOT_TOP = 137          # 真机截图里系统状态栏的高度
SHOT_W = 760            # 贴图宽度
SHOT_X = (W - SHOT_W) // 2
SHOT_Y = 356
RADIUS = 44

# (截图文件, 大标题, 副标题)
PAGES = [
    ("s_home.jpeg", "AI 帮你科学养宠", "档案、待办、问答，一个 App 管好"),
    ("s_food.jpeg", "能不能吃，一秒查清楚", "结论来自本地知识库，不由 AI 随意生成"),
    ("s_chat.jpeg", "回答会带上它的档案", "3 岁 2 个月、4.2kg，建议才对得上"),
    ("s_mine.jpeg", "数据只留在你手机上", "不申请相册权限，云端 AI 默认关闭"),
]


def background_svg(title: str, subtitle: str) -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
  <defs>
    <radialGradient id="top" cx="0.5" cy="0.06" r="0.75">
      <stop offset="0" stop-color="#FFE3D2" stop-opacity="0.95"/>
      <stop offset="1" stop-color="#FFE3D2" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="mark" x1="0.2" y1="0" x2="0.8" y2="1">
      <stop offset="0" stop-color="#FFFFFF"/>
      <stop offset="0.55" stop-color="#FFF7F4"/>
      <stop offset="1" stop-color="#FFE6D8"/>
    </linearGradient>
  </defs>
  <rect width="{W}" height="{H}" fill="#FFF9F6"/>
  <rect width="{W}" height="{H}" fill="url(#top)"/>

  <!-- 品牌标记 -->
  <rect x="96" y="88" width="72" height="72" rx="22" fill="#FF8A5B"/>
  <g transform="translate(132 124) scale(0.062) translate(-546 -518)">
    <g transform="rotate(-8 512 545)">
      {body('url(#mark)', 0.45)}
    </g>
  </g>
  <text x="192" y="139" font-family="Microsoft YaHei, PingFang SC, sans-serif"
    font-size="38" font-weight="bold" fill="#1F1B18">爪心</text>

  <text x="96" y="268" font-family="Microsoft YaHei, PingFang SC, sans-serif"
    font-size="62" font-weight="bold" fill="#1F1B18">{title}</text>
  <text x="96" y="330" font-family="Microsoft YaHei, PingFang SC, sans-serif"
    font-size="30" fill="#8A8078">{subtitle}</text>
</svg>"""


def rounded(img: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.width - 1, img.height - 1), radius=radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def shadow(img: Image.Image, blur: int = 26, dy: int = 16, alpha: int = 60) -> Image.Image:
    pad = blur * 3
    canvas = Image.new("RGBA", (img.width + pad * 2, img.height + pad * 2), (0, 0, 0, 0))
    canvas.paste(img, (pad, pad), img)
    sh = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sh.paste(Image.new("RGBA", img.size, (138, 58, 18, alpha)), (pad, pad + dy), img.split()[3])
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    sh.alpha_composite(canvas)
    return sh


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "screenshots").mkdir(parents=True, exist_ok=True)

    for i, (shot, title, subtitle) in enumerate(PAGES, start=1):
        src = SHOTS_DIR / shot
        if not src.exists():
            print(f"缺少截图：{src}")
            return 1

        (OUT / f"bg-{i}.svg").write_text(background_svg(title, subtitle), encoding="utf-8")
        bg = Image.open(shoot(f"promo-bg-{i}", [str(OUT / f"bg-{i}.svg")], size=(W, H), out_dir=OUT)).convert("RGBA")

        raw = Image.open(src).convert("RGB").crop((0, SHOT_TOP, 1320, 2856))
        raw.save(OUT / "screenshots" / f"screenshot-{i}.png")

        scaled = raw.resize((SHOT_W, int(raw.height * SHOT_W / raw.width)), Image.LANCZOS)
        card = shadow(rounded(scaled, RADIUS))
        bg.alpha_composite(card, (SHOT_X - (card.width - SHOT_W) // 2, SHOT_Y - (card.height - scaled.height) // 2))
        bg.convert("RGB").save(OUT / f"promo-{i}.png")
        print(f"promo-{i}.png  {title}")

    print("输出目录:", OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
