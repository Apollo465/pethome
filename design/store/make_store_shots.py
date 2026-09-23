"""生成上架用的应用介绍图（1080x1920），只依赖 Pillow，不需要浏览器渲染。

与 make_promo.py 的区别：那个脚本用 Edge 渲染 SVG 背景（依赖浏览器自动化），
这个脚本直接用 Pillow 画底色 + 标题，再把真机截图贴上去，跑起来更稳。

用法：
    python design/store/make_store_shots.py

输出：
    design/store/out/promo-1..4.png          带标题的介绍图（可直接上传 AGC）
    design/store/out/screenshots/screenshot-1..4.png   纯截图
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "out"
SHOTS = ROOT / "shots" / "new"

W, H = 1080, 1920
SHOT_TOP = 137          # 真机截图顶部系统状态栏高度
SHOT_W = 760
SHOT_X = (W - SHOT_W) // 2
SHOT_Y = 356
RADIUS = 44

BG = (255, 249, 246)
TEXT_MAIN = (31, 27, 24)
TEXT_SUB = (138, 128, 120)

PAGES = [
    ("n2_home_pet.jpeg", "档案、待办、提醒", "一个 App 管好，数据只留在手机上"),
    ("n7_food.jpeg", "能不能吃，一秒查清楚", "结论来自本地知识库"),
    ("n8_chat.jpeg", "回答会带上它的档案", "答案来自本地知识库，应用不联网"),
    ("n9_mine.jpeg", "数据只留在这台手机", "不申请相册权限，应用无联网能力"),
]


def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        "C:/Windows/Fonts/msyhbd.ttc" if bold else "C:/Windows/Fonts/msyh.ttc",
        "C:/Windows/Fonts/msyh.ttc",
        "C:/Windows/Fonts/simhei.ttf",
    ]
    for path in candidates:
        if Path(path).exists():
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                continue
    return ImageFont.load_default()


def rounded_mask(size, radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def with_shadow(card: Image.Image) -> Image.Image:
    blur, dy, pad = 26, 16, 78
    canvas = Image.new("RGBA", (card.width + pad * 2, card.height + pad * 2), (0, 0, 0, 0))
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow.paste(Image.new("RGBA", card.size, (138, 58, 18, 60)), (pad, pad + dy), card.split()[3])
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(shadow)
    canvas.paste(card, (pad, pad), card)
    return canvas


def build(index: int, shot: str, title: str, subtitle: str) -> int:
    src = SHOTS / shot
    if not src.exists():
        print(f"缺少截图：{src}")
        return 1

    canvas = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(canvas)
    # 顶部淡淡的橙色光晕，和 App 的暖色调一致
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((-260, -560, W + 260, 420), fill=(255, 227, 210, 150))
    glow = glow.filter(ImageFilter.GaussianBlur(120))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), glow).convert("RGB")
    draw = ImageDraw.Draw(canvas)

    # 品牌块
    draw.rounded_rectangle((96, 88, 168, 160), radius=22, fill=(255, 138, 91))
    draw.text((192, 100), "爪心", font=load_font(40, True), fill=TEXT_MAIN)
    draw.text((96, 210), title, font=load_font(62, True), fill=TEXT_MAIN)
    draw.text((96, 292), subtitle, font=load_font(30), fill=TEXT_SUB)

    raw = Image.open(src).convert("RGB").crop((0, SHOT_TOP, 1320, 2856))
    raw.save(OUT / "screenshots" / f"screenshot-{index}.png")

    scaled = raw.resize((SHOT_W, int(raw.height * SHOT_W / raw.width)), Image.LANCZOS).convert("RGBA")
    scaled.putalpha(rounded_mask(scaled.size, RADIUS))
    card = with_shadow(scaled)
    canvas = canvas.convert("RGBA")
    canvas.alpha_composite(card, (SHOT_X - (card.width - SHOT_W) // 2, SHOT_Y - (card.height - scaled.height) // 2))
    canvas.convert("RGB").save(OUT / f"promo-{index}.png")
    print(f"promo-{index}.png  {title}")
    return 0


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "screenshots").mkdir(parents=True, exist_ok=True)
    for i, (shot, title, subtitle) in enumerate(PAGES, start=1):
        code = build(i, shot, title, subtitle)
        if code != 0:
            return code
    print("输出目录:", OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
