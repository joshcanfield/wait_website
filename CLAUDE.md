# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Static recovery of the Washington State Aggression Replacement Training (WSART) site, built with Eleventy 3.0 and deployed to GitHub Pages. The site preserves a legacy Drupal directory structure — all pages are self-contained HTML files with no layout inheritance or template reuse.

## Build & Development Commands

```bash
npm run build          # Build site to _site/
npm run dev            # Local dev server at http://localhost:8080 (with live reload)
npm install            # Install dependencies (only @11ty/eleventy)
```

### Link Auditing & Repair (PowerShell)

```bash
pwsh scripts/find-missing.ps1    # Audit links → writes missing_report.csv
pwsh scripts/repair-links.ps1    # Normalize paths + fetch archived assets from Wayback
```

After changes, run `find-missing.ps1` and verify "Missing locally: 0".

## Architecture

**Eleventy config** (`.eleventy.js`): Passthrough-copies `modules/`, `misc/`, `sites/` verbatim. Custom permalink computation preserves `.html` extensions (no directory indexes). Template formats: html, njk, md. Output to `_site/`.

**Content structure:**
- Root HTML entry points: `index.html`, `home.html`, `calendars.html`
- Article pages: `content/*.html` (8 self-contained XHTML Strict pages)
- CSS: `modules/` (Drupal core), `sites/all/themes/` (mikes + zen themes), `sites/all/modules/` (contrib)
- JS: `misc/` (jquery, drupal), `sites/all/modules/thickbox/`
- Media: `sites/default/files/` (PDFs, images, favicons)

**Deployment:** Push to `main` triggers GitHub Actions (`.github/workflows/pages.yml`) — Node 20, `npm run build`, deploy `_site/` to GitHub Pages.

## Conventions

- **Indentation:** 2 spaces, no tabs
- **Filenames:** lowercase, hyphen-separated (e.g., `training-brochure.html`)
- **Links:** prefer root-relative paths starting with `/`
- **Preserve legacy structure** — do not move files without updating all references
- **Commit messages:** imperative mood with scoped prefix: `content:`, `scripts:`, `fix:`, `build:`, `chore:`, `site:`
