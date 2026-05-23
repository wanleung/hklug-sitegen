# Bootstrap 5 Migration + Image Support Design

**Date:** 2026-05-23  
**Status:** Approved  
**Scope:** hklug-sitegen static site generator

---

## Overview

Two related improvements to the hklug-sitegen news portal:

1. **CSS migration** — Replace Foundation CSS 5.2.3 with Bootstrap 5 for cleaner typography, better defaults, and a more professional look.
2. **Image support** — Add cover image support for all article cards, with a three-tier resolution pipeline (manual → extracted → fetched at import).

---

## Section 1: CSS Migration (Foundation 5 → Bootstrap 5)

### Motivation

Foundation 5.2.3 is unmaintained, has dated defaults, and the current portal looks visually rough. Bootstrap 5 is actively maintained, has better typography defaults, and the grid/component model is simpler to work with in templates.

### Changes

**`template/frame.html` and `template/frame_noannounce.html`:**
- Remove Foundation CDN `<link>` and `<script>` tags
- Add Bootstrap 5 CDN: `bootstrap.min.css` and `bootstrap.bundle.min.js`
- Keep custom `<link rel="stylesheet" href="/css/main.css">`

**`template/menu.html`:**
- Replace Foundation `top-bar` markup with Bootstrap `navbar navbar-expand-lg`
- Use `navbar-dark bg-dark` for the nav colour scheme

**All card templates (`announce.html`, `news.html`, `announce_page.html`, `announce_list.html`, archive templates):**
- Replace Foundation grid classes: `large-X columns` → `col-md-X`
- Replace `row` containers: keep `row`, add `g-3` for gutters
- Replace Foundation button classes: `button` → `btn btn-sm btn-outline-*`

**`site/css/main.css`:**
- Rewrite entirely to be Bootstrap-compatible
- Keep same colour scheme: blue (`#0d6efd`) for community, green (`#198754`) for IT news
- Section headers, card shadows, badge styles, read-more links — all rewritten without Foundation dependencies
- Remove all Foundation-specific overrides

### No Perl logic changes

CSS migration is purely template and CSS work.

---

## Section 2: Image Pipeline

### Storage

- `static/images/` — tracked by git, source of truth for downloaded and manually added images
- `sitegen.pl` copies `static/images/` → `site/images/` at the start of every build (`copy_static()` function using `File::Copy::Recursive`)
- `static/` directory is committed to git; `site/` remains fully gitignored

### Image Resolution Order (per article)

| Priority | Source | How it gets there |
|----------|--------|-------------------|
| 1 (highest) | `Image:` field in `.txt` file | Manual author entry, or written by `newsfeed.pl` at import time |
| 2 | First `<img src="...">` in rendered article HTML | Extracted by `DataLoader.pm` when no `Image:` field present |
| 3 | OG image from article source URL | Fetched by `newsfeed.pl` at RSS import time; written as `Image:` field in generated `.txt` |
| 4 (fallback) | None / grey placeholder | Template renders a styled placeholder div |

### Where Fetching Happens

**`bin/newsfeed.pl` (at RSS import time):**
- After writing an article `.txt` file, attempt to fetch the OG image from the source URL (`og:image` meta tag)
- On success: download the image to `static/images/<slug>.jpg`, write `Image: images/<slug>.jpg` into the `.txt` file
- On failure (no OG tag, network error, non-image content-type): skip silently — DataLoader will fall back to `<img>` extraction
- Uses `LWP::UserAgent` for HTTP and `HTML::TreeBuilder` (or regex) for OG tag extraction

**`lib/Sitegen/DataLoader.pm`:**
- Parse `Image:` header like any other field (`Title:`, `Date:`, etc.)
- If no `Image:` field: scan rendered HTML for first `<img src="...">` using a simple regex
- Expose as `image` key in the article hash (value: relative path like `images/slug.jpg` or absolute URL)

**`bin/sitegen.pl` (at build start):**
- New `copy_static()` function: copies `static/images/` → `site/images/` before any page generation
- Uses `File::Copy::Recursive::dircopy`

### Key Invariant

By the time `sitegen.pl` runs, the `Image:` field in each `.txt` file is already a plain resolved value (relative path or URL). No HTTP requests happen during the build. The generator remains fast and fully offline-capable.

---

## Section 3: Template Changes (Card Image Display)

### Card layout (announce.html, news.html)

Each card follows this structure:
```
┌─────────────────────────┐
│  [cover image 200px]    │  ← <img> if image present, grey placeholder div if not
│  or [grey placeholder]  │
├─────────────────────────┤
│  [Badge]                │
│  Title                  │
│  Excerpt...             │
│  Date · Author          │
│  [Read more →]          │
└─────────────────────────┘
```

- Image height: `200px`, `object-fit: cover` — consistent regardless of source image dimensions
- Placeholder: styled `<div>` with grey background, "No image" text
- Badge: `Community` (blue) for announcements, `IT News` (green) for news

### Individual article pages (announce_page.html, archive pages)

- Show full-width hero image at top of article if `article.image` is set
- No placeholder on article pages — just skip the image block if absent

### Image path handling in templates

Templates use: `[% IF article.image %]<img src="/[% article.image %]">[% END %]`

For absolute URLs (extracted from content): the template checks `article.image` starts with `http` and uses it as-is.

---

## Files Changed

| File | Change type |
|------|-------------|
| `template/frame.html` | CSS swap, Bootstrap CDN |
| `template/frame_noannounce.html` | CSS swap, Bootstrap CDN |
| `template/menu.html` | Rewrite nav to Bootstrap navbar |
| `template/announce.html` | Grid classes + image card |
| `template/news.html` | Grid classes + image card |
| `template/announce_page.html` | Hero image + Bootstrap classes |
| `template/announce_list.html` | Bootstrap classes |
| `template/archive.html` / `archive_page.html` | Bootstrap classes |
| `site/css/main.css` | Full rewrite (Bootstrap-compatible) |
| `lib/Sitegen/DataLoader.pm` | Parse `Image:` field, extract `<img>` fallback |
| `bin/sitegen.pl` | Add `copy_static()`, call at build start |
| `bin/newsfeed.pl` | OG image fetch + write `Image:` field |
| `static/images/` | New directory (tracked by git) |

---

## Testing

- Existing 71 tests must continue to pass (no regressions)
- Add DataLoader tests for `image` field: manual `Image:` header, `<img>` extraction fallback, missing image → `undef`
- Add `sitegen.pl` test: `copy_static()` copies files correctly
- Visual check: generate site, confirm cards render with images/placeholders

---

## Out of Scope

- Responsive image `srcset` / multiple resolutions
- Image optimisation / compression pipeline
- Lazy loading
- Image captions
