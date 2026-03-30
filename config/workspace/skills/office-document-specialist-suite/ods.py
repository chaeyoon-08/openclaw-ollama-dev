#!/usr/bin/env python3
# ref: https://python-docx.readthedocs.io
"""
Office Document Specialist Suite — ods.py
Word 문서 생성 스크립트

사용법:
  python3 ods.py template-report --output /path/result.docx --title "제목" --author "작성자"
"""

import argparse
import os
import sys
from datetime import datetime

from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
from docx.oxml import OxmlElement


def set_heading_color(paragraph, r, g, b):
    for run in paragraph.runs:
        run.font.color.rgb = RGBColor(r, g, b)


def add_horizontal_rule(doc):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(4)
    p.paragraph_format.space_after = Pt(4)
    pPr = p._p.get_or_add_pPr()
    pBdr = OxmlElement("w:pBdr")
    bottom = OxmlElement("w:bottom")
    bottom.set(qn("w:val"), "single")
    bottom.set(qn("w:sz"), "6")
    bottom.set(qn("w:space"), "1")
    bottom.set(qn("w:color"), "7C3AED")
    pBdr.append(bottom)
    pPr.append(pBdr)


def cmd_template_report(args):
    """표준 보고서 템플릿 생성"""
    output = args.output
    title = args.title
    author = args.author or "Clari AI"
    date_str = datetime.now().strftime("%Y년 %m월 %d일")

    os.makedirs(os.path.dirname(os.path.abspath(output)), exist_ok=True)

    doc = Document()

    # ── 페이지 여백 설정 ──────────────────────────────────
    section = doc.sections[0]
    section.top_margin = Inches(1.0)
    section.bottom_margin = Inches(1.0)
    section.left_margin = Inches(1.2)
    section.right_margin = Inches(1.2)

    # ── 제목 ──────────────────────────────────────────────
    title_para = doc.add_heading(title, level=0)
    title_para.alignment = WD_ALIGN_PARAGRAPH.CENTER
    for run in title_para.runs:
        run.font.size = Pt(24)
        run.font.color.rgb = RGBColor(0x7C, 0x3A, 0xED)
        run.font.bold = True

    # ── 메타 정보 ─────────────────────────────────────────
    meta = doc.add_paragraph()
    meta.alignment = WD_ALIGN_PARAGRAPH.CENTER
    meta_run = meta.add_run(f"작성자: {author}  |  작성일: {date_str}")
    meta_run.font.size = Pt(10)
    meta_run.font.color.rgb = RGBColor(0x6B, 0x6B, 0x8A)

    add_horizontal_rule(doc)

    # ── 섹션 1: 개요 ─────────────────────────────────────
    h1 = doc.add_heading("1. 개요", level=1)
    set_heading_color(h1, 0x7C, 0x3A, 0xED)
    doc.add_paragraph("이 문서는 Clari AI가 생성한 보고서 템플릿입니다. 내용을 수정하여 사용하세요.")

    # ── 섹션 2: 주요 내용 ─────────────────────────────────
    h2 = doc.add_heading("2. 주요 내용", level=1)
    set_heading_color(h2, 0x7C, 0x3A, 0xED)

    table = doc.add_table(rows=1, cols=2)
    table.style = "Table Grid"
    hdr_cells = table.rows[0].cells
    hdr_cells[0].text = "항목"
    hdr_cells[1].text = "내용"
    for cell in hdr_cells:
        for run in cell.paragraphs[0].runs:
            run.font.bold = True
    # 예시 행 2개
    for item, content in [("항목 1", "내용을 입력하세요"), ("항목 2", "내용을 입력하세요")]:
        row = table.add_row().cells
        row[0].text = item
        row[1].text = content

    doc.add_paragraph()

    # ── 섹션 3: 결론 ─────────────────────────────────────
    h3 = doc.add_heading("3. 결론", level=1)
    set_heading_color(h3, 0x7C, 0x3A, 0xED)
    doc.add_paragraph("결론 및 권고사항을 작성하세요.")

    add_horizontal_rule(doc)

    # ── 푸터 ─────────────────────────────────────────────
    footer_para = doc.add_paragraph()
    footer_para.alignment = WD_ALIGN_PARAGRAPH.CENTER
    footer_run = footer_para.add_run("Powered by Clari AI")
    footer_run.font.size = Pt(9)
    footer_run.font.color.rgb = RGBColor(0xB0, 0xB0, 0xC8)

    doc.save(output)
    print(f"Word 문서 생성 완료: {output}")


def main():
    parser = argparse.ArgumentParser(
        description="Office Document Specialist Suite"
    )
    subparsers = parser.add_subparsers(dest="command")

    # template-report 서브커맨드
    rp = subparsers.add_parser("template-report", help="표준 보고서 템플릿 생성")
    rp.add_argument("--output", required=True, help="출력 파일 경로 (.docx)")
    rp.add_argument("--title", required=True, help="문서 제목")
    rp.add_argument("--author", default="Clari AI", help="작성자 이름")

    args = parser.parse_args()

    if args.command == "template-report":
        cmd_template_report(args)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
