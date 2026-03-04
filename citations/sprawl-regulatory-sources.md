# Sprawl Regulatory Sources Log

Use this file to pin legal/regulatory references used in Section 6.

## Citation Standard

- prefer primary legal/regulatory sources
- include effective/enforcement dates in ISO format
- include exact article/control identifiers cited in manuscript

## Source Table

| Regulation | Article/Control | Source URL | Effective date | Enforcement date | Notes |
|---|---|---|---|---|---|
| EU AI Act | Consolidated regulation text (Regulation (EU) 2024/1689) | https://eur-lex.europa.eu/eli/reg/2024/1689/oj/eng | 2024-08-01 | 2026-08-02 (general staged application applies) | Primary legal text reference |
| EU AI Act | Article 113 (Entry into force and application) | https://ai-act-service-desk.ec.europa.eu/en/ai-act/article-113 | 2024-08-01 | 2026-08-02 | Canonical source for staged application timeline |
| EU AI Act | Article 50 (Transparency Obligations) | https://ai-act-service-desk.ec.europa.eu/en/ai-act/article-50 | 2024-08-01 | 2026-08-02 | Canonical transparency citation for this report |
| EU AI Act | Article 15 (Accuracy, Robustness, Cybersecurity) | https://ai-act-service-desk.ec.europa.eu/en/ai-act/article-15 | 2024-08-01 | 2026-08-02 | Use only for robustness/cybersecurity claims |
| SOC 2 | Trust Services Criteria (CC series, including CC6.1 / CC7.1 / CC8.1) | https://www.aicpa-cima.com/resources/download/2017-trust-services-criteria-with-revised-points-of-focus-2022 | 2017-04-01 (rev. points of focus 2022) | N/A | Canonical TSC control-ID source used for deterministic proxy mapping |
| SOC 2 | AICPA SOC 2 overview and TSC context | https://www.aicpa-cima.com/topic/audit-assurance/audit-and-assurance-greater-than-soc-2 | 2017-04-01 | N/A | Context source for SOC 2 framing language |
| PCI DSS 4.0.1 | PCI DSS standard (requirements and testing procedures) | https://www.pcisecuritystandards.org/document_library/?category=pcidss&document=pci_dss | 2024-06-11 (v4.0.1 publication) | In force per PCI SSC lifecycle | Canonical source for requirement IDs used in mapping (`6.3`, `6.5`, `7.2`, `12.8`) |
| PCI DSS 4.0.1 | Requirement 6.4.3 intent clarification (payment page script inventory/authorization) | https://www.pcisecuritystandards.org/faq/articles/Frequently_Asked_Question/how-does-pci-dss-v4-0-requirement-6-4-3-protect-against-e-commerce-skimming-attacks/ | 2024-06-11 | In force per PCI SSC lifecycle | Context-only reference; not scored unless payment-page telemetry is in scope |
