# Repository Guidelines

## Project Structure & Module Organization
- Root HTML: `index.html`, `home.html`, `calendars.html` (entry points).
- Content pages: `content/` (article HTML).
- Assets: `modules/` (CSS), `misc/` (JS/vendor), `sites/` (Drupal-era structure).
- Utility scripts: `scripts/` (PowerShell), reports: `missing_report.csv`.
- IDE settings: `.idea/` (do not commit changes unless necessary).

## Build, Test, and Development Commands
- Open locally: double-click `index.html` or serve:
  - `python -m http.server 8080` (then visit `http://localhost:8080`).
- Link audit (reads the repo, writes CSV):
  - `pwsh scripts/find-missing.ps1` → writes `missing_report.csv` with unresolved internal links and Wayback hints.
- Auto-repair internal paths and fetch archived assets:
  - `pwsh scripts/repair-links.ps1` → normalizes root-relative links and downloads available Wayback files.
- Publish (GitHub Pages): push the repository to a `gh-pages` branch.

## Coding Style & Naming Conventions
- HTML/CSS/JS indentation: 2 spaces; no tabs.
- Filenames: lowercase, words separated by hyphens (e.g., `training-brochure.html`).
- Links: prefer root-relative paths starting with `/` (e.g., `/content/...`).
- Keep legacy structure; avoid moving files unless also updating all references.

## Testing Guidelines
- Run `pwsh scripts/find-missing.ps1` and ensure “Missing locally: 0”.
- Manually spot-check key pages (`/index.html`, `/home.html`, select `content/*.html`).
- Verify console free of 404s when serving locally.
- If assets are missing, run `repair-links.ps1` and re-check the report.

## Commit & Pull Request Guidelines
- Commits: imperative mood and scoped prefixes:
  - `content: add session adherence article`
  - `scripts: normalize root-relative links`
  - `fix: correct broken image references`
- PRs: include summary, before/after screenshots for visual changes, list of checked pages, and whether you ran the scripts above. Link related issues.

## Security & Configuration Tips
- Do not add secrets; this is a public static site.
- Keep external links `https` where possible.
- Large binaries should not be committed; prefer archived references noted in `missing_report.csv`.
