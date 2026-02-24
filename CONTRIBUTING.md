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
- Data submissions must be anonymized and schema-valid.
- Include source citations for regulatory/control mappings.

## Pull request checklist

- Update or add schema docs in `schemas/` if contract changes are introduced.
- Add or update claim-ledger entries in `claims/` when metrics change.
- Add reproduction commands in report methodology docs.
- Run relevant validation scripts in `pipelines/*/validate.sh`.
