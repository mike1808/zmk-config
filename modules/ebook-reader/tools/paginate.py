#!/usr/bin/env python3
"""Convert a plain-text book into a C array of pages for the ZMK ebook reader.

Usage:
    python3 paginate.py --input book.txt --output ebook_data.c

Font defaults match pixel_operator_mono at 160x60px text area:
    --chars-per-line 20  (8px char width, 160px wide)
    --lines-per-page 4   (13px line height, 60px tall)
"""

import argparse
import re
import textwrap


def strip_gutenberg(text: str) -> str:
    """Remove Project Gutenberg header and footer boilerplate."""
    start_match = re.search(r"\*\*\* START OF (THE|THIS) PROJECT GUTENBERG", text, re.IGNORECASE)
    end_match = re.search(r"\*\*\* END OF (THE|THIS) PROJECT GUTENBERG", text, re.IGNORECASE)
    if start_match:
        text = text[start_match.end():]
    if end_match:
        end_pos = re.search(r"\*\*\* END OF (THE|THIS) PROJECT GUTENBERG", text, re.IGNORECASE)
        if end_pos:
            text = text[:end_pos.start()]
    return text


def normalize(text: str) -> str:
    """Normalize line endings and collapse excessive blank lines."""
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def split_paragraphs(text: str) -> list[str]:
    """Split text into paragraphs on blank lines."""
    return [p.strip() for p in text.split("\n\n") if p.strip()]


def wrap_paragraphs(paragraphs: list[str], chars_per_line: int) -> list[str]:
    """Word-wrap each paragraph and return list of lines."""
    lines = []
    for para in paragraphs:
        # Collapse internal whitespace within paragraph
        para = re.sub(r"[ \t]+", " ", para.replace("\n", " ")).strip()
        wrapped = textwrap.wrap(para, width=chars_per_line)
        lines.extend(wrapped)
        lines.append("")  # blank line between paragraphs
    # Remove trailing blank lines
    while lines and lines[-1] == "":
        lines.pop()
    return lines


def paginate(lines: list[str], lines_per_page: int) -> list[list[str]]:
    """Group lines into pages."""
    pages = []
    for i in range(0, len(lines), lines_per_page):
        pages.append(lines[i:i + lines_per_page])
    return pages


def escape_c_string(s: str) -> str:
    """Escape a string for use as a C string literal."""
    s = s.replace("\\", "\\\\")
    s = s.replace('"', '\\"')
    s = s.replace("\n", "\\n")
    return s


def emit_c(pages: list[list[str]], output_path: str) -> None:
    lines_out = []
    lines_out.append('#include "ebook_data.h"')
    lines_out.append("")
    lines_out.append("const char * const ebook_pages[] = {")
    for page_lines in pages:
        content = "\n".join(page_lines)
        lines_out.append(f'    "{escape_c_string(content)}",')
    lines_out.append("};")
    lines_out.append("")
    lines_out.append(f"const uint16_t ebook_total_pages = {len(pages)};")
    lines_out.append("")

    with open(output_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines_out))

    print(f"Written {len(pages)} pages to {output_path}")


def main():
    parser = argparse.ArgumentParser(description="Paginate a book for the ZMK ebook reader.")
    parser.add_argument("--input", required=True, help="Input .txt file")
    parser.add_argument("--output", required=True, help="Output ebook_data.c path")
    parser.add_argument("--chars-per-line", type=int, default=20,
                        help="Characters per line (default 20, matches pixel_operator_mono at 160px)")
    parser.add_argument("--lines-per-page", type=int, default=4,
                        help="Lines per page (default 4, matches pixel_operator_mono 13px at 60px height)")
    args = parser.parse_args()

    with open(args.input, "r", encoding="utf-8", errors="replace") as f:
        text = f.read()

    text = strip_gutenberg(text)
    text = normalize(text)
    paragraphs = split_paragraphs(text)
    lines = wrap_paragraphs(paragraphs, args.chars_per_line)
    pages = paginate(lines, args.lines_per_page)
    emit_c(pages, args.output)


if __name__ == "__main__":
    main()
