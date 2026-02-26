# Contributing

Thanks for contributing to the Clyra AI Safety Initiative research repository.

## What you can contribute

- Regulatory mapping improvements (YAML/JSON updates with sources)
- Detection and classification signatures
- Methodology clarifications and reproducibility fixes
- Anonymized findings that fit existing schema contracts

## Ground rules

- Reproducibility is required for all claims.
- Every headline number must map to an artifact and query in `claims/`.
- Use neutral research tone in report text; avoid promotional language and product CTA copy.
- Data submissions must be anonymized and schema-valid.
- Include source citations for regulatory/control mappings.

## Pull request checklist

- Update or add schema docs in `schemas/` if contract changes are introduced.
- Add or update claim-ledger entries in `claims/` when metrics change.
- Add reproduction commands in report methodology docs.
- Update preregistration and citation logs when claim scope or legal references change.
- Ensure report templates/manuscripts include:
  - headline integrity block (headline, denominator, run ID, artifact, query)
  - fixed disclosure headings: `Limitations`, `Threats to Validity`, `Residual Risk`, `Reproducibility Notes`
- Run relevant validation scripts in `pipelines/*/validate.sh`.
