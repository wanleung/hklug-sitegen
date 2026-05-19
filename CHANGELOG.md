# Changelog

All notable changes to hklug-sitegen are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

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

[Unreleased]: https://github.com/wanleung/hklug-sitegen/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/wanleung/hklug-sitegen/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/wanleung/hklug-sitegen/releases/tag/v1.0.0
