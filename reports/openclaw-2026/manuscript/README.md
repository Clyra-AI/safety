# OpenClaw Manuscript Source

Canonical manuscript source for the OpenClaw report.

Expected files:

- `report.md` (or `report.tex`)
- `pdf-header.tex` (Pandoc/XeLaTeX styling and font portability)
- `references.bib` (if using BibTeX)
- `figures/` generation notes or scripts
- deterministic build command notes

Build contract:

- Source -> PDF build must be deterministic from pinned inputs.
- Final PDF location: `reports/openclaw-2026/report.pdf`.

Canonical command (recommended, deterministic Markdown -> LaTeX -> PDF):

```bash
pipelines/common/build_report_pdf.sh --report-dir reports/openclaw-2026
```

Optional direct command (LaTeX source -> PDF with `latexmk`):

```bash
latexmk -pdfxe -interaction=nonstopmode -halt-on-error \
  -outdir=reports/openclaw-2026/manuscript \
  reports/openclaw-2026/manuscript/report.tex
cp reports/openclaw-2026/manuscript/report.pdf reports/openclaw-2026/report.pdf
```

Manual source generation command (Markdown -> LaTeX):

```bash
pandoc reports/openclaw-2026/manuscript/report.md \
  --standalone \
  --from gfm \
  --to latex \
  --include-in-header=reports/openclaw-2026/manuscript/pdf-header.tex \
  -V geometry:margin=1in \
  -V colorlinks=true \
  -V linkcolor=blue \
  -V urlcolor=blue \
  -V citecolor=blue \
  -V filecolor=blue \
  -o reports/openclaw-2026/manuscript/report.tex
```

Fallback command (Markdown -> PDF directly):

```bash
pandoc reports/openclaw-2026/manuscript/report.md \
  --pdf-engine=xelatex \
  --include-in-header=reports/openclaw-2026/manuscript/pdf-header.tex \
  -V geometry:margin=1in \
  -V colorlinks=true \
  -V linkcolor=blue \
  -V urlcolor=blue \
  -V citecolor=blue \
  -V filecolor=blue \
  -o reports/openclaw-2026/report.pdf
```
