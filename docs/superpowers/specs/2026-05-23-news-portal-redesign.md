# hklug-sitegen News Portal Front Page Redesign

**Date:** 2026-05-23  
**Status:** Approved  
**Scope:** Template redesign — front page only (`template/frame.html`, `template/news.html`, `template/announce.html`, `template/footer.html`). No changes to `bin/sitegen.pl` data loading logic, archive pages, or individual post pages.

---

## Goal

Transform the hklug-sitegen front page from a single-column blog-style layout into a two-section news portal. The site serves two distinct audiences/content types that should be visually separated:

1. **HK Open Source Community** — local events and announcements from `data/top/`
2. **IT News** — AI-curated technology articles from `data/news/`

---

## Layout

### Overall structure

Full-width, no right sidebar. Foundation CSS grid retained for responsive behaviour.

```
[ Nav bar ]
[ Header: logo + site name ]
─────────────────────────────────────
[ Blue section header: HK Community ]
[ 3 announcement cards (horizontal) ]
─────────────────────────────────────
[ Green section header: IT News     ]
[ 2×4 IT news card grid             ]
[ "More IT News → Archive" link     ]
─────────────────────────────────────
[ Footer: CC licence + FB links     ]
```

### Section 1 — HK Open Source Community

- **Data source:** `data/top/` (existing `announces` variable from `load_announce()`)
- **Display:** 3 most recent announcements as horizontal cards
- **Card content:** Title, date, author, short content excerpt
- **Card link:** Each card links to its individual page (currently in `data/top/`, path TBD by sitegen)
- **Section colour:** Blue (`#1a6fa8`) header bar, light blue card background

### Section 2 — IT News

- **Data source:** `data/news/` (existing `news` variable)
- **Display:** 8 most recent articles in a 2-column grid
- **Card content:** Title, date, short excerpt (first 150–200 characters of content, stripped of HTML tags)
- **Card link:** `/archive/<slug>.html` (existing archive pages, unchanged)
- **Section colour:** Green (`#1e8a4a`) header bar, light green card background
- **"More" link:** Points to `/archive/`

### Footer

- Creative Commons licence (existing)
- Community links: HKLUG Facebook Group, HKCOTA, OpenSource HK, HKOSCon (moved from sidebar)
- Copyright line (existing)

---

## Template changes

| File | Change |
|------|--------|
| `template/frame.html` | Remove 9-col/3-col grid split. Replace with full-width layout. Remove sidebar `<aside>`. |
| `template/announce.html` | Redesign from `alert-box` list to horizontal 3-card strip with blue accent. |
| `template/news.html` | Redesign from `[% WRAPPER frame.html %]` post list to green 2×4 card grid with excerpt. |
| `template/footer.html` | Add Facebook community links block (moved from sidebar). |
| `template/frame_noannounce.html` | Update to match new full-width frame (used for archive/tag pages). |

### Excerpt generation

`sitegen.pl` currently passes raw HTML content to templates. The excerpt must be generated in the template layer using Template Toolkit's `FILTER` or a simple `substr` + HTML strip. The approach: pass `post.content` through a TT `FILTER html_entity` then truncate, or add an `excerpt` field in `load_data()` in `lib/Sitegen/DataLoader.pm`.

**Decision:** Add `excerpt` field in `DataLoader.pm` — strip HTML tags and truncate to 180 characters. This keeps templates clean and avoids TT filter complexity.

---

## Data flow (unchanged)

```
data/top/*.txt  ──► load_announce() ──► $announces ──► announce.html (Section 1)
data/news/*.txt ──► load_data()     ──► $news       ──► news.html     (Section 2)
```

`sitegen.pl` `gen_home()` already passes both `announces` and `news` to `news.html` via the TT vars. No changes needed to the Perl scripts except adding `excerpt` in `DataLoader.pm`.

---

## What does NOT change

- `bin/sitegen.pl` generation logic
- Individual archive pages (`template/archive.html`, `/archive/*.html`)
- Archive list page (`template/archive_list.html`)
- Tag pages
- About / Contact / Privacy pages
- URL structure — all `/archive/<slug>.html` links remain identical
- `data/top/` and `data/news/` directory names and file formats

---

## Acceptance criteria

1. Front page has two visually distinct sections: blue (community) and green (IT news).
2. Community section shows exactly 3 announcements as horizontal cards.
3. IT news section shows exactly 8 articles as a 2-column grid with excerpt.
4. All cards link correctly to their individual article pages.
5. No right sidebar on any page.
6. Facebook community links appear in the footer.
7. Site passes `perl bin/sitegen.pl --force` without errors.
8. `site/index.html` is valid HTML with both sections present.
