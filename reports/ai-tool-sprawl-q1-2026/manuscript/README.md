# AI Tool Sprawl Manuscript Source

Canonical manuscript source for the AI Tool Sprawl report.

Expected files:

- `report.md` (or `report.tex`)
- `pdf-header.tex` (Pandoc/XeLaTeX styling and font portability)
- `references.bib` (if using BibTeX)
- `figures/` generation notes or scripts
- deterministic build command notes

Build contract:

- Source -> PDF build must be deterministic from pinned inputs.
- Final PDF location: `reports/ai-tool-sprawl-q1-2026/report.pdf`.

Recommended command (Markdown -> PDF):

```bash
pandoc reports/ai-tool-sprawl-q1-2026/manuscript/report.md \
  --pdf-engine=xelatex \
  --include-in-header=reports/ai-tool-sprawl-q1-2026/manuscript/pdf-header.tex \
  -V geometry:margin=1in \
  -o reports/ai-tool-sprawl-q1-2026/report.pdf
```
