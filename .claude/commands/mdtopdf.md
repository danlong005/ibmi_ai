Convert a markdown file to PDF.

The user will provide a markdown file path. The converter uses Python with fpdf2 to produce a PDF in the same directory as the source file.

## Script reference

The converter script is at `bin/md_to_pdf.py`. It accepts:

```
python bin/md_to_pdf.py <file.md> [output.pdf]

  file.md     Path to the input markdown file (required)
  output.pdf  Output PDF path (optional; defaults to same name/location as input with .pdf extension)
```

## Steps

1. Parse the user's request to extract the markdown file path and optional output path.
2. Run from the project root:

   ```
   python bin/md_to_pdf.py <file.md> [output.pdf]
   ```

3. Show the output to the user, including the path and page count.
4. If conversion fails, summarise the error. Common issues:
   - `fpdf2` not installed — run `python -m pip install fpdf2`
   - File not found — check the path is relative to the project root
