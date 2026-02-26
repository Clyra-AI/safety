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

Recommended command (Markdown -> PDF):

```bash
pandoc reports/openclaw-2026/manuscript/report.md \
  --pdf-engine=xelatex \
  --include-in-header=reports/openclaw-2026/manuscript/pdf-header.tex \
  -V geometry:margin=1in \
  -o reports/openclaw-2026/report.pdf
```
