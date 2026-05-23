# Changelog

All notable changes to hklug-sitegen are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

## [1.2.0] - 2026-05-23

### Added
- **Sitemap generation** — `bin/sitegen.pl` now writes `site/sitemap.xml` on every build,
  covering the homepage, archive posts, announcements, and static pages with `lastmod`,
  `changefreq`, and `priority` values (456 URLs on initial generation)
- **`static/robots.txt`** — `User-agent: * / Allow: /` with `Sitemap:` pointer to
  `https://www.linux.org.hk/sitemap.xml`; copied to `site/` at build time
- **Root-level static file copying** — `copy_static()` now copies all files directly
  under `static/` (not just `static/images/`) to `site/` at build time
- **Modern dark footer** — three-column dark navy footer (`#1a1a2e`) with HKLUG branding,
  Community links column, and Site links column; replaces old single-paragraph footer
- **CSS cache-busting** — `?v=` version string on `/css/main.css` link in `header.html`
  to force browser cache invalidation on updates

### Changed
- **Bootstrap 5 migration** — all templates migrated from Foundation CSS to Bootstrap 5.3.3
  (CDN with SRI hashes); grid, navbar, pagination, and utility classes updated throughout
- **Visual redesign** — full CSS rewrite (`site/css/main.css`): clean tech-blog style with
  constrained article pages (max-width 780px), card hover effects, section headers, and
  improved typography (code blocks, blockquotes, tables)
- **Navigation** — `template/menu.html` uses `container` (not `container-fluid`) so nav
  aligns with content width
- **Footer width** — `template/footer.html` uses `container` (not `container-fluid`)
- **`template/frame.html`** and **`template/frame_noannounce.html`** — switched from
  `container-fluid px-4` to `container py-4`
- **`template/post.html`** — removed invalid `<p>` wrapper around `[% post.content %]`;
  added `.article-title`, `.article-meta`, `.article-body` CSS classes; `<h1>` title
- **`template/page.html`** — uses `frame_noannounce.html` (no announce sidebar on static
  pages)
- **`template/post_nav.html`** — replaced old Foundation `<center><ul>` pagination with
  Bootstrap 5 `<nav><ul class="pagination">`
- **`template/archive.html`** — content wrapped in `.article-page` div for max-width
  constraint
- **`template/announce.html`** and **`template/news.html`** — card images use
  `.card-cover-wrap` / `.card-cover` classes for constrained `object-fit: cover` display
- **`data/sitegen.yaml`** — corrected `site_url` from `https://hklug.org` to
  `https://www.linux.org.hk`

## [1.1.0] - 2026-05-19

### Added
- **SEO meta tags** — `<meta name="description">`, Open Graph (`og:title`, `og:description`,
  `og:url`), and `<link rel="canonical">` on all archive and tag pages, driven by
  `data/sitegen.yaml` site configuration
- **Tag pages** — articles support a `Tags:` header line (comma-separated); the generator
  now produces `/tags/index.html` (all-tags list) and `/tags/<slug>/index.html` (per-tag
  post list)
- **Incremental generation** — SHA-256 cache (`data/.sitegen-cache.json`) skips unchanged
  archive pages on re-run; `--force` flag bypasses the cache to regenerate everything
- **`lib/Sitegen/` module library** — generator logic extracted into four modules:
  - `Sitegen::DataLoader` — article file parser with `Tags:` support
  - `Sitegen::Cache` — SHA-256 incremental cache with atomic writes
  - `Sitegen::SEO` — SEO meta hashref builder
  - `Sitegen::Tags` — tag collection and tag page generation
- **`data/sitegen.yaml`** — site-level configuration (`site_url`, `site_name`,
  `site_description`)
- **47 unit tests** across `t/Cache.t`, `t/DataLoader.t`, `t/SEO.t`, `t/Tags.t`
- **`template/tag_list.html`** and **`template/tag_page.html`** — new templates for tag
  browsing pages

### Changed
- `bin/sitegen.pl` rewritten as a thin orchestrator delegating to `Sitegen::` modules
- `template/header.html` — `<title>` is now dynamic (`[% title | html %]`); conditional
  SEO block added
- `template/post.html` — tag links rendered below article content

### Fixed
- Tag href attributes use `| uri` encoding (not `| html`) to keep URL paths valid
- Unsafe tag values containing `/`, `\`, or `..` are warned-and-skipped to prevent
  path traversal during generation

## [1.0.0] - 2012-07-17

### Added
- Initial static site generator for HKLUG built with Perl and Template Toolkit
- Archive page generation for news articles in `data/news/`
- Home page, about page, and archive index generation
- Foundation CSS framework integration
- Announce/welcome box rendered from most-recent news file

[Unreleased]: https://github.com/wanleung/hklug-sitegen/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/wanleung/hklug-sitegen/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/wanleung/hklug-sitegen/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/wanleung/hklug-sitegen/releases/tag/v1.0.0
