"""把选中的图标方案写进鸿蒙工程资源。

用法：
    python apply_icon.py            # 用默认方案 A（爪心 + 星火）
    python apply_icon.py --concept b

写入的文件：
    AppScope/resources/base/media/foreground.png   前景层（1024，透明）
    AppScope/resources/base/media/background.png   底色层（1024）
    AppScope/resources/base/media/app_icon.png     合成图（1024，备用）
    entry/src/main/resources/base/media/foreground.png
    entry/src/main/resources/base/media/background.png
    entry/src/main/resources/base/media/startIcon.png  启动页图标（144，圆角透明）

原模板图标会先备份到 design/app-icon/original/。
"""
import argparse
import shutil
import sys
from pathlib import Path

from PIL import Image

from mark_geometry import write_icon_source
from render import SIZE, shoot, mask

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parent.parent
APPSCOPE = PROJECT / "AppScope" / "resources" / "base" / "media"
ENTRY = PROJECT / "entry" / "src" / "main" / "resources" / "base" / "media"
BACKUP = ROOT / "original"

CONCEPTS = {
    # 方案 A 由 mark_geometry.py 生成，改几何只需改那一处
    "a": "out/concept-a-paw-heart.svg",
    "b": "concept-b-chat-cat.svg",
    "c": "concept-c-heart-pet.svg",
}


def write(concept: str) -> None:
    write_icon_source(ROOT / "out" / "concept-a-paw-heart.svg")
    svg = CONCEPTS[concept]
    fg_path = shoot(f"fg-{concept}", [svg])
    preview_path = shoot(f"preview-{concept}", ["background.svg", svg])
    bg_path = ROOT / "out" / "bg.png"
    if not bg_path.exists():
        bg_path = shoot("bg", ["background.svg"])

    fg = Image.open(fg_path).convert("RGBA")
    bg = Image.open(bg_path).convert("RGBA")
    preview = Image.open(preview_path).convert("RGBA")

    # 备份模板图标，只做一次
    BACKUP.mkdir(parents=True, exist_ok=True)
    for label, src in (("appscope", APPSCOPE / "foreground.png"),
                       ("appscope", APPSCOPE / "background.png"),
                       ("appscope", APPSCOPE / "app_icon.png"),
                       ("entry", ENTRY / "foreground.png"),
                       ("entry", ENTRY / "background.png"),
                       ("entry", ENTRY / "startIcon.png")):
        target = BACKUP / f"{label}-{src.name}"
        if src.exists() and not target.exists():
            shutil.copy2(src, target)

    fg.save(APPSCOPE / "foreground.png")
    bg.convert("RGB").save(APPSCOPE / "background.png")
    preview.convert("RGB").save(APPSCOPE / "app_icon.png")
    fg.save(ENTRY / "foreground.png")
    bg.convert("RGB").save(ENTRY / "background.png")

    # 启动页图标：圆角遮罩 + 透明背景，贴在米色启动底色上不会出现方块
    start = preview.resize((144, 144), Image.LANCZOS)
    start.putalpha(mask(144, "squircle"))
    start.save(ENTRY / "startIcon.png")

    print(f"applied concept {concept} -> {APPSCOPE} , {ENTRY}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--concept", choices=sorted(CONCEPTS), default="a")
    args = parser.parse_args()
    write(args.concept)
    return 0


if __name__ == "__main__":
    sys.exit(main())
