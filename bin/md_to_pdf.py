"""Convert a markdown file to PDF using fpdf2."""
import pathlib, re, sys
from fpdf import FPDF

def strip_md(text):
    text = re.sub(r'\*\*(.*?)\*\*', r'\1', text)
    text = re.sub(r'`(.*?)`', r'\1', text)
    return text.strip()

def parse_row(line):
    return [c.strip() for c in line.strip().strip('|').split('|')]

def safe_cell(pdf, w, h, txt, border=0, fill=False):
    txt = str(txt)
    while txt and pdf.get_string_width(txt) > w - 1:
        txt = txt[:-1]
    pdf.cell(w, h, txt, border=border, fill=fill)

def convert(md_file, pdf_file=None):
    md_path = pathlib.Path(md_file)
    pdf_path = pathlib.Path(pdf_file) if pdf_file else md_path.with_suffix(".pdf")
    lines = md_path.read_text(encoding="utf-8").splitlines()

    LEFT = RIGHT = 10
    pdf = FPDF(orientation="L", unit="mm", format="A4")
    pdf.set_auto_page_break(auto=True, margin=10)
    pdf.add_page()
    pdf.set_margins(LEFT, 10, RIGHT)
    page_w = pdf.w - LEFT - RIGHT   # usable width

    in_table = False
    col_widths = []

    for line in lines:
        # Skip separator rows
        if re.match(r'^\s*\|[\s\-:|]+\|\s*$', line):
            continue

        # Table row
        if '|' in line and line.strip().startswith('|'):
            cells = parse_row(line)
            n = len(cells)
            if not in_table:
                in_table = True
                if n == 4:
                    col_widths = [
                        page_w * 0.16,
                        page_w * 0.18,
                        page_w * 0.20,
                        page_w * 0.46,
                    ]
                else:
                    col_widths = [page_w / n] * n
                pdf.set_x(LEFT)
                pdf.set_font("Helvetica", "B", 7)
                pdf.set_fill_color(210, 210, 210)
                for i, cell in enumerate(cells[:len(col_widths)]):
                    safe_cell(pdf, col_widths[i], 5, strip_md(cell), border=1, fill=True)
                pdf.ln()
            else:
                pdf.set_x(LEFT)
                pdf.set_font("Helvetica", "", 6.5)
                row_y = int(pdf.get_y())
                if (row_y // 5) % 2 == 0:
                    pdf.set_fill_color(248, 248, 248)
                else:
                    pdf.set_fill_color(255, 255, 255)
                for i, cell in enumerate(cells[:len(col_widths)]):
                    safe_cell(pdf, col_widths[i], 4.5, strip_md(cell), border=1, fill=True)
                pdf.ln()
            continue

        # End of table
        if in_table:
            in_table = False
            col_widths = []
            pdf.set_x(LEFT)
            pdf.ln(3)

        stripped = line.strip()
        pdf.set_x(LEFT)

        if not stripped:
            pdf.ln(2)
            continue

        if stripped.startswith('# '):
            pdf.set_font("Helvetica", "B", 13)
            pdf.multi_cell(page_w, 7, strip_md(stripped[2:]))
        elif stripped.startswith('## '):
            pdf.set_font("Helvetica", "B", 10)
            pdf.multi_cell(page_w, 6, strip_md(stripped[3:]))
        elif stripped.startswith('### '):
            pdf.set_font("Helvetica", "B", 9)
            pdf.multi_cell(page_w, 5, strip_md(stripped[4:]))
        elif stripped.startswith('#### '):
            pdf.set_font("Helvetica", "B", 8)
            pdf.multi_cell(page_w, 5, strip_md(stripped[5:]))
        else:
            pdf.set_font("Helvetica", "", 8)
            pdf.multi_cell(page_w, 4.5, strip_md(stripped))

    pdf.output(str(pdf_path))
    print(f"Written: {pdf_path}  ({pdf.page} pages)")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python md_to_pdf.py <file.md> [output.pdf]")
        sys.exit(1)
    convert(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
