# AI Tool Sprawl V2 2026 Manuscript Source

Canonical manuscript source for the v2 AI tool and agent sprawl report.

Expected files:

- `report.md`
- `pdf-header.tex`
- `figures/` generation notes or scripts
- deterministic build command notes

Build contract:

- source to PDF build must be deterministic from pinned inputs
- final PDF location: `reports/ai-tool-sprawl-v2-2026/report.pdf`

Recommended command:

```bash
pipelines/common/build_report_pdf.sh --report-dir reports/ai-tool-sprawl-v2-2026
```
