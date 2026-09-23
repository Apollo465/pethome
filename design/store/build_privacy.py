"""把 privacy-policy.md 转成可直接部署的 privacy-policy.html。

只支持这份文档用到的 Markdown 子集：一级/二级标题、表格、段落、**加粗**、行内 `代码`。
改政策时只改 .md，然后重跑本脚本，网页版就不会和源文件漂移。

    python build_privacy.py
"""
import html
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MD = ROOT / "privacy-policy.md"
OUT = ROOT / "privacy-policy.html"

STYLE = """
  :root { color-scheme: light; }
  body {
    margin: 0; padding: 32px 20px 64px;
    background: #FFF9F6; color: #1F1B18;
    font-family: -apple-system, "PingFang SC", "Microsoft YaHei", "Helvetica Neue", Arial, sans-serif;
    line-height: 1.8; font-size: 16px;
  }
  main { max-width: 760px; margin: 0 auto; }
  h1 { font-size: 26px; line-height: 1.4; margin: 0 0 8px; }
  h2 { font-size: 18px; margin: 32px 0 8px; padding-top: 8px; }
  p { margin: 10px 0; }
  .meta { color: #8A8078; font-size: 14px; margin: 0 0 24px; }
  strong { font-weight: 700; }
  table { border-collapse: collapse; width: 100%; margin: 12px 0; font-size: 14px; }
  th, td { border: 1px solid #F0E9E4; padding: 8px 10px; text-align: left; vertical-align: top; }
  th { background: #FFEDE4; font-weight: 600; }
  code { background: #FFEDE4; padding: 1px 5px; border-radius: 4px; font-size: 14px; }
  .brand { display: flex; align-items: center; gap: 10px; margin-bottom: 20px; }
  .brand i {
    width: 34px; height: 34px; border-radius: 10px; display: inline-block;
    background: linear-gradient(135deg, #FFB77F, #ED6534);
  }
  .brand span { font-weight: 700; font-size: 18px; }
"""


def inline(text: str) -> str:
    text = html.escape(text, quote=False)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"`(.+?)`", r"<code>\1</code>", text)
    return text


def convert(md: str) -> str:
    out: list[str] = []
    lines = md.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i].rstrip()
        if not line:
            i += 1
            continue

        if line.startswith("# "):
            out.append(f"<h1>{inline(line[2:])}</h1>")
        elif line.startswith("## "):
            out.append(f"<h2>{inline(line[3:])}</h2>")
        elif line.startswith("|"):
            rows: list[list[str]] = []
            while i < len(lines) and lines[i].lstrip().startswith("|"):
                cells = [c.strip() for c in lines[i].strip().strip("|").split("|")]
                if not all(re.fullmatch(r":?-{2,}:?", c) for c in cells):
                    rows.append(cells)
                i += 1
            head, *body = rows
            out.append("<table><thead><tr>"
                       + "".join(f"<th>{inline(c)}</th>" for c in head)
                       + "</tr></thead><tbody>"
                       + "".join("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in r) + "</tr>" for r in body)
                       + "</tbody></table>")
            continue
        elif line.startswith("更新日期") or line.startswith("生效日期"):
            out.append(f'<p class="meta">{inline(line)}</p>')
        else:
            out.append(f"<p>{inline(line)}</p>")
        i += 1
    return "\n".join(out)


def main() -> int:
    body = convert(MD.read_text(encoding="utf-8"))
    OUT.write_text(
        "<!doctype html>\n<html lang=\"zh-CN\">\n<head>\n"
        "<meta charset=\"utf-8\">\n"
        "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
        "<title>爪心 隐私政策</title>\n"
        f"<style>{STYLE}</style>\n</head>\n<body>\n<main>\n"
        "<div class=\"brand\"><i></i><span>爪心</span></div>\n"
        f"{body}\n</main>\n</body>\n</html>\n",
        encoding="utf-8",
    )
    print("wrote", OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
