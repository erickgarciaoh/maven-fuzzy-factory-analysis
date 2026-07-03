# Product

## Register

brand

## Users

Two audiences read the same single-page data-story, in this priority order:

1. **International recruiters / hiring managers (non-technical).** Skim on desktop or mobile, 30–90 seconds, deciding "is this person a rigorous analyst worth a call?" They need the headline result, a sense of craft, and proof the work is real — without reading SQL.
2. **Data analysts / analytics leads (technical).** Read deeper, look for method honesty: how the A/B tests were reconstructed, whether significance was tested, whether limits are declared. They judge the *reasoning*, not just the charts.

Context: the page is a portfolio piece (`maven-fuzzy-factory-analysis`), hosted statically on GitHub Pages, reachable by URL from a résumé or LinkedIn. It is the public face of an otherwise SQL-centric pipeline (raw load → star schema → `analysis` views → JSON).

## Product Purpose

Turn four analyses of a fictional e-commerce dataset (Maven Fuzzy Factory, a plush-toy store, 2012–2015) into one scroll-driven narrative that demonstrates end-to-end analytical capability: window-function funnels, reconstructed A/B experiments with proportion z-tests, an Oaxaca-style growth decomposition, and channel-level unit economics with margin and refunds.

Success = a recruiter grasps the headline (conversion rate more than doubled, and *why*) in under a minute, and an analyst comes away convinced the method is sound and honestly bounded. The page is the deliverable; the impression it makes is the product.

## Brand Personality

Sober. Rigorous. Quietly confident. The voice states results plainly and declares its own limits without hedging or hype — analyst-to-analyst candor, not marketing. Three words: **precise, authored, honest.** Emotional goal: the reader trusts the numbers *and* the person behind them, because nothing is oversold and the uncomfortable findings (a losing A/B test, a refund spike) are shown, not buried.

## Anti-references

- **Generic BI dashboard** (Power BI/Tableau default): cool gray-white, dense KPI-card grids, chart-junk, no narrative. This story *serves a thesis*; it is not a control panel.
- **The SaaS hero-metric template**: giant gradient number + three supporting stats + "trusted by." Cliché and empty.
- **Scrollytelling for spectacle** (parallax, pinned 3D, motion that fights the data). Motion here communicates narrative state, never personality.
- **Data-journalism maximalism** (NYT-style full-bleed illustration everywhere). This is analytical, not editorial-illustrated.
- **Fake certainty**: extrapolated forecasts stated as predictions, inferred A/B assignment stated as labeled fact, synthetic-data patterns stated as real business findings.

## Design Principles

1. **Rigor is the aesthetic.** Nothing decorative. Every element is structural or informational; the polish comes from proportion, weight, and restraint, not ornament.
2. **Show the work, not a claim about it.** Real charts computed from the fact tables, real z-scores, real SQL provenance — never an illustration standing in for evidence.
3. **Declare the limits in the frame, not the footnotes.** Synthetic data, inferred A/B assignment, session-scoped attribution, gross-margin-only (no CAC) are stated where the claim is made. Honesty is a feature the technical reader is grading.
4. **One focal point per view.** The amber accent — in UI and in charts — marks the single thing that matters in each act. If everything is emphasized, nothing is.
5. **Legible before clever.** A recruiter on a phone must get the spine without touching a control. Interactivity and motion are enhancements over an already-complete, already-visible default.

## Accessibility & Inclusion

- WCAG AA: body text ≥4.5:1, large/bold ≥3:1, against both light (canvas) and dark (ink) themes. Verify the amber accent and semantic colors against their actual backgrounds.
- Never encode a distinction by color alone: device series, significance, and positive/negative deltas also carry shape, label, or symbol (chart series are colorblind-distinguishable; significance shows the z-value / a marker, not just red vs green).
- `prefers-reduced-motion: reduce`: scroll-driven reveals collapse to the final rendered state instantly; no content is gated behind a transition that could fail to fire.
- Keyboard-operable controls (device toggle, quarter control, theme toggle); visible focus rings (accent). Charts expose an accessible text/table fallback of their underlying numbers.
- Responsive to a 360px phone: charts reflow or scroll within their own container; numeric cells never wrap.
