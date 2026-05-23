# HKLUG Site Generator

This is a static html generator of the Hong Kong Linux User Group Main Site.

<http://www.linux.org.hk/>

## Concept

No DB, No Dynamic Code, No BackEnd.

Storing the Data in Text Files, using Markdown Format.
The members of the Community can add post using Github pull request, and re-generate the main site, to prevent the robot hacking of the CMS platforms.

## Structure

* `TEMPLATE.txt` — Master text file template for data entries. Copy to `data/` and edit, or use the scripts in `bin/` to generate one.

* `bin/create_announce.pl` — Creates a data file in `data/top/` for announcement posts.

* `bin/create_post.pl` — Creates a data file in `data/news/` for normal news posts.

* `bin/newsfeed.pl` — RSS news feeder; fetches posts from configured RSS feeds and auto-creates data files in `data/news/`. Also downloads OG images to `static/images/`.

* `bin/sitegen.pl` — Main site generator. Reads data from `data/`, renders HTML via templates in `template/`, and outputs to `site/`. Also generates `site/sitemap.xml` automatically on every build.

* `data/` — Source data files (news articles, announcements, static pages, config)

* `data/sitegen.yaml` — Site-level configuration: `site_url`, `site_name`, `site_description`, announcement sources.

* `lib/Sitegen/` — Perl module library:
  - `Sitegen::DataLoader` — article file parser with Tags support
  - `Sitegen::Cache` — SHA-256 incremental build cache
  - `Sitegen::SEO` — SEO meta hashref builder
  - `Sitegen::Tags` — tag collection and tag page generation

* `site/` — Generated webroot (gitignored except `site/css/main.css`)

* `static/` — Static assets tracked by git and copied to `site/` at build time:
  - `static/images/` — OG images downloaded by `newsfeed.pl`
  - `static/robots.txt` — Robots exclusion file (points to sitemap)

* `template/` — HTML templates in Template Toolkit format

## Building the Site

```bash
# Full rebuild (ignores cache)
perl -Ilib bin/sitegen.pl --force

# Incremental rebuild (skips unchanged archive pages)
perl -Ilib bin/sitegen.pl
```

Output goes to `site/`. The sitemap is written to `site/sitemap.xml` on every build.

## Running Tests

```bash
prove -Ilib t/
```

76 tests across `t/Cache.t`, `t/DataLoader.t`, `t/SEO.t`, `t/Tags.t`, `t/Sitegen.t`.

## License

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

The Data Files in `data/` are licensed under a Creative Commons Attribution-ShareAlike 3.0 Hong Kong License (CC BY-SA 3.0).
