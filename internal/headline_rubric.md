# Headline Selection Rubric

Use this rubric before freezing any public headline number.

## Goal

Choose headlines that are:

- human-impact oriented
- governance-relevant
- reproducible from repository artifacts

## Required Headline Formula

Every selected headline must pair:

1. Human-impact metric  
2. Governance delta metric  
3. Reproducibility anchor

Template:

`<impact number> in <window>, reduced to <governed result> with <artifact/run-id proof>`

## Candidate Scoring (0-2 each, max 10)

1. Human consequence clarity  
- 0: abstract technical metric
- 1: indirect operational impact
- 2: direct user/business risk implication

2. Governance relevance  
- 0: no clear control implication
- 1: partial control implication
- 2: clear control gap and control response

3. Denominator clarity  
- 0: no denominator
- 1: denominator implied
- 2: denominator explicit and stable

4. Reproducibility strength  
- 0: cannot map to artifact/query
- 1: partial mapping
- 2: full mapping (run ID, artifact path, deterministic query)

5. Press memorability  
- 0: weak/forgettable framing
- 1: moderate
- 2: specific, surprising, and credible

## Minimum Bar

- publish candidate headline only if score >= 8
- any score < 8 must be reframed or replaced

## Guardrails

- Do not use context/news anecdotes as evidence for headline numbers.
- Context references can motivate why the study matters, but claim values must come from your run artifacts only.
- Avoid product CTA language in headline/lead paragraphs.

## Required Headline Packet

For each headline included in manuscript:

- claim ID
- headline text
- numerator and denominator
- run ID
- artifact path
- deterministic query
- one-line caveat/limitation
