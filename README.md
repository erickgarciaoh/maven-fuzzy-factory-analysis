# Maven Fuzzy Factory — Analysis & Data-Story

End-to-end SQL analytics project: a conversion-funnel, A/B-test, growth-decomposition, and channel-economics analysis of a fictional e-commerce dataset, delivered as a scroll-driven, single-page data-story.

**[View the data-story](https://erickgarciaoh.github.io/maven-fuzzy-factory-analysis/)**

## What's here

- **Pipeline** (`src/`): SQL Server, raw load (`NVARCHAR` staging) → cleaned/cast `core` star schema (fact + dims) → `analysis` views, one per business question.
- **Data-story** (`docs/`): static HTML/JS front end (ECharts via CDN, no build step), reading from JSON exported off the `analysis` views. Self-contained — no external asset dependencies — so it serves directly from GitHub Pages.
- **Design docs** (`PRODUCT.md`, `DESIGN.md`): product brief and visual-system spec (brand tokens, color, accessibility) that drove the Fase 5–6 build.

## Questions answered

1. **Conversion funnel** — 7-step funnel by quarter and device (window functions over pageviews); confirms a mobile drop-off relative to desktop.
2. **A/B tests** — 4 landing/billing-page tests reconstructed from overlapping traffic windows (assignment inferred by date), evaluated with a two-proportion z-test and annualized lift. Includes a losing test, not just the winners.
3. **CVR growth decomposition** — additive (Oaxaca-style) split of the 2012→2015 conversion-rate gain into intra-channel improvement vs. channel mix-shift.
4. **Channel economics** — sessions → orders → revenue → COGS → refunds by channel and product, with gross margin (no CAC/ROAS: not available in the source data).

## Methodology

Built with an agentic SQL loop: run a query against the real database, read the result or error, correct, repeat. Every phase (ingestion → quality audit → transformation → analysis views → design → build) is a separate commit, so the history documents the reasoning, not just the final SQL. Assumptions (e.g. inferred A/B assignment, annualized lift) are declared as hypotheses with stated limits, not presented as fact — see [`docs/02_data_quality.md`](docs/02_data_quality.md) and the data-story's closing section for specifics.

## How to reproduce

1. Create the database and raw tables, then load `data/raw/*.csv` with the importer stored procedure (`src/01`–`03`).
2. Run `src/04`–`07` in numeric order to profile, transform into the `core` star schema, and build the `analysis` views.
3. Export each `analysis` view to `docs/data/*.json` (`FOR JSON PATH`).
4. Open `docs/index.html` (or the deployed Pages URL) — `app.js` fetches the JSON and computes every displayed number at runtime.

## Stack

SQL Server (T-SQL) · HTML/CSS/JS · ECharts · git. No Python/R/Power BI in this build — see `CLAUDE.md` for the full phase plan and decisions (Power BI was scoped and explicitly dropped, Fase 7).
