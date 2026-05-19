# hklug-sitegen: SEO, Tag Pages, and Incremental Generation

**Date:** 2026-05-19  
**Status:** Approved

---

## Problem

The hklug-sitegen generator (Perl + Template Toolkit) has three gaps:

1. **No SEO** — `<head>` has no `<meta name="description">`, no Open Graph tags, no canonical URL.
2. **No tag pages** — posts have no tag taxonomy; there is no way to browse posts by topic.
3. **Full regeneration every run** — with 358+ news files, every run rebuilds every page. As the archive grows this becomes slow.

---

## Approach

Enhance the generator in Perl, extracting concerns into modules under `lib/Sitegen/`. `bin/sitegen.pl` becomes a thin orchestrator. Four modules are introduced.

---

## Module Structure

```
bin/sitegen.pl               # thin orchestrator
lib/Sitegen/
  DataLoader.pm              # load_data(), load_announce(), Tags: parsing
  Cache.pm                   # SHA-256 hash cache
  SEO.pm                     # seo_meta() — description + og: hashref
  Tags.pm                    # collect_tags(), gen_tag_pages()
data/sitegen.yaml            # site configuration (new)
data/.sitegen-cache.json     # generated cache (gitignored)
template/
  header.html                # updated: conditional [% IF seo %] block
  tag_list.html              # new: all-tags index
  tag_page.html              # new: posts for a single tag
site/tags/                   # new: generated tag pages
```

### `lib/Sitegen/DataLoader.pm`

Moves existing `load_data()` and `load_announce()` from `sitegen.pl` into this module. Adds `Tags:` line parsing.

**`Tags:` format** — optional line before `Content:`, comma-separated:
```
Tags: linux, open-source, event
```
Files without a `Tags:` line get `$post->{tags} = []` (backward compatible). Tags are trimmed and lowercased for consistency.

### `lib/Sitegen/Cache.pm`

```perl
load_cache($cache_file)        # returns hashref {filename => sha256hex}
save_cache($cache_file, $cache)
is_fresh($cache, $src_file, $out_file)
  # true if: hash matches AND $out_file exists on disk
update_cache($cache, $src_file)  # compute and store hash
```

Cache file: `data/.sitegen-cache.json` (JSON, human-readable).

### `lib/Sitegen/SEO.pm`

```perl
seo_meta($post, $config, $url_path)
```

`$url_path` is the site-relative path for the page (e.g. `/archive/20230101-120000.html`). For index pages pass `/` or `/archive/`.

Returns a hashref:
```perl
{
  description    => "First 160 chars of plain text, HTML stripped",
  og_title       => $post->{title},
  og_description => "same as description",
  og_url         => "$config->{site_url}$url_path",
}
```

For index/home pages, `$post->{title}` is the generic page title and `$config->{site_description}` is used as fallback when content is empty.

HTML stripping: remove all `<...>` tags with a regex before truncating to 160 chars.

### `lib/Sitegen/Tags.pm`

```perl
collect_tags(@posts)
  # returns { 'linux' => [$post1, $post2, ...], ... }
  # posts sorted newest-first within each tag

gen_tag_pages($tt, $tags_hashref, $site_folder, $config)
  # generates:
  #   site/tags/index.html          (tag_list.html template)
  #   site/tags/<tag>/index.html    (tag_page.html template per tag)
```

Tag names in URLs are lowercased and spaces replaced with hyphens (e.g. `open source` → `open-source`).

---

## Configuration File

`data/sitegen.yaml`:
```yaml
site_url: https://hklug.org
site_name: Hong Kong Linux User Group - 香港Linux用家協會(HKLUG)
site_description: Community news and events for Linux users in Hong Kong.
```

Parsed at startup using `YAML::Tiny` (pure Perl, no XS dependency). Values passed through to all generators as `$config` hashref.

---

## Data Format — `Tags:` Field

The `.txt` format gains one optional header field:

```
Date: 2024-01-15 18:00
Author: Wan Leung Wong
Title: Monthly Open Source Workshop
Tags: linux, event, open-source
Content:
<body HTML>
```

`Tags:` must appear in the header section (before `Content:`). Parsing: split on `,`, trim whitespace, lowercase. Tags may contain letters, digits, hyphens, spaces.

---

## SEO — Template Changes

`template/header.html` updated — `<title>` is now dynamic and a conditional SEO block is added:

```html
<title>[% title %]</title>
[% IF seo %]
<meta name="description" content="[% seo.description %]" />
<meta property="og:title" content="[% seo.og_title %]" />
<meta property="og:description" content="[% seo.og_description %]" />
<meta property="og:url" content="[% seo.og_url %]" />
<link rel="canonical" href="[% seo.og_url %]" />
[% END %]
```

All page-generating calls in `sitegen.pl` pass a `seo` key in `$vars`.

---

## Tag Display — Post Templates

`template/post.html` updated to show tags as links (only when `$post->{tags}` is non-empty):

```html
[% IF post.tags.size %]
<p class="tags">
  Tags:
  [% FOREACH tag = post.tags %]
    <a href="/tags/[% tag %]/">[% tag %]</a>[% UNLESS loop.last %],[% END %]
  [% END %]
</p>
[% END %]
```

Same change applied to `template/archive.html`.

---

## Incremental Generation

### Cache Logic

```
startup:
  load cache from data/.sitegen-cache.json (empty hash if missing)

for each archive page (individual article .html):
  if --force OR NOT is_fresh(cache, src.txt, site/archive/post.html):
    generate page
    update cache entry
  else:
    skip (print "SKIP <filename>")

index pages (site/index.html, site/archive/index.html, site/tags/**):
  ALWAYS regenerate — they are fast and depend on all articles

shutdown:
  save updated cache to data/.sitegen-cache.json
```

### `--force` Flag

```bash
perl bin/sitegen.pl [--force]
```

`--force` clears the in-memory cache before processing, ensuring every page is regenerated. Cache is then fully written out at the end.

### Cache File Format

```json
{
  "20120717-182938.txt": "e3b0c44298fc1c149afb...",
  "20240115-180000.txt": "a9f8d2c4b1e7..."
}
```

`data/.sitegen-cache.json` is added to `.gitignore`.

---

## File Generation Summary

| Output | Template | Incremental? |
|--------|----------|-------------|
| `site/index.html` | `news.html` | No (always) |
| `site/about.html` etc. | `page.html` | No (always) |
| `site/archive/<post>.html` | `archive.html` | **Yes** |
| `site/archive/index.html` | `archive_list.html` | No (always) |
| `site/tags/index.html` | `tag_list.html` | No (always) |
| `site/tags/<tag>/index.html` | `tag_page.html` | No (always) |

---

## Error Handling

- Missing `data/sitegen.yaml` → die with clear message.
- Malformed `Tags:` line (e.g. invalid chars) → warn and skip the bad entry; don't crash.
- Cache file unreadable or corrupt JSON → warn and proceed with empty cache (full rebuild).
- `site/tags/` directory created automatically if absent.

---

## Testing

Manual smoke test:
1. `perl bin/sitegen.pl` — first run generates all pages; cache written.
2. `perl bin/sitegen.pl` — second run skips all unchanged archive pages (verify "SKIP" log lines).
3. Touch one `.txt` file (or change its content); re-run — only that page regenerates.
4. `perl bin/sitegen.pl --force` — all pages regenerate.
5. Add `Tags: linux, event` to a `.txt`; verify `/tags/linux/index.html` lists it.
6. Verify `<meta property="og:title">` present in generated archive page.

Unit tests (optional Perl `Test::More`): `Cache.pm` hash logic, `SEO.pm` HTML stripping + truncation, `DataLoader.pm` tag parsing.
