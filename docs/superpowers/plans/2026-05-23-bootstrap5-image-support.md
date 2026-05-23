# Bootstrap 5 Migration + Image Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Foundation 5 CSS with Bootstrap 5 and add a three-tier cover image pipeline (manual `Image:` field → first `<img>` in content → OG image fetched at RSS import time) for all article cards.

**Architecture:** CSS migration is purely template/CSS work (no Perl changes). Image support adds `image` field to DataLoader, a `copy_static()` step in sitegen.pl, and OG fetch in newsfeed.pl using only core Perl modules (HTTP::Tiny, File::Find, File::Copy). By the time the generator runs, every image is already a local file in `static/images/` — no network calls during build.

**Tech Stack:** Perl 5, Template Toolkit 2, Bootstrap 5.3.3 (CDN), HTTP::Tiny (Perl core), File::Find (Perl core), File::Copy (Perl core)

---

## File Map

| File | Change |
|------|--------|
| `template/header.html` | Swap Foundation CDN → Bootstrap 5 CDN; update branding grid |
| `template/footer.html` | Remove Foundation JS; add Bootstrap bundle JS |
| `template/menu.html` | Rewrite Foundation top-bar → Bootstrap navbar |
| `template/frame.html` | `large-12 columns` → `col-12`; wrap in `container-fluid` |
| `template/frame_noannounce.html` | Same as frame.html |
| `template/announce.html` | Bootstrap grid + image card layout |
| `template/news.html` | Bootstrap grid + image card layout |
| `template/announce_page.html` | Bootstrap grid + hero image block |
| `template/announce_list.html` | Bootstrap grid classes |
| `site/css/main.css` | Full rewrite for Bootstrap 5 (restore deleted file + new content) |
| `lib/Sitegen/DataLoader.pm` | Parse `Image:` header field; extract first `<img>` fallback |
| `t/DataLoader.t` | Add tests for `image` field; update test count |
| `bin/sitegen.pl` | Add `copy_static()` using File::Find+File::Copy; call at build start |
| `bin/newsfeed.pl` | Add `fetch_og_image()` using HTTP::Tiny; write `Image:` field in .txt |
| `TEMPLATE.txt` | Add `[%IMAGE]` placeholder |
| `static/images/.gitkeep` | Create tracked directory |

---

## Task 1: Bootstrap 5 in header, footer, menu

**Files:**
- Modify: `template/header.html`
- Modify: `template/footer.html`
- Modify: `template/menu.html`

- [ ] **Step 1: Rewrite `template/header.html`**

Replace the entire file content with:

```html
<!DOCTYPE html>

<!-- header start -->

<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>[% title | html %]</title>
    [% IF seo %]
    <meta name="description" content="[% seo.description | html %]" />
    <meta property="og:title" content="[% seo.og_title | html %]" />
    <meta property="og:description" content="[% seo.og_description | html %]" />
    <meta property="og:url" content="[% seo.og_url | html %]" />
    <link rel="canonical" href="[% seo.og_url | html %]" />
    [% END %]
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="/css/main.css" />
  </head>
  <body>

  [% INCLUDE menu.html %]

  <div class="container-fluid px-4 py-2">
    <div class="row align-items-center mb-3">
      <div class="col-md-3">
        <a href="/"><img src="/images/logo.png" alt="HKLUG" style="max-height:80px;" /></a>
      </div>
      <div class="col-md-9 text-end">
        <h2 class="mb-0">Hong Kong Linux User Group<br /><small class="text-muted fs-6">香港Linux用家協會 (HKLUG)</small></h2>
      </div>
    </div>
  </div>

<!-- header end -->
```

- [ ] **Step 2: Rewrite `template/menu.html`**

Replace the entire file content with:

```html
<!-- menu start -->

<nav class="navbar navbar-expand-lg navbar-dark bg-dark mb-0">
  <div class="container-fluid">
    <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav" aria-controls="navbarNav" aria-expanded="false" aria-label="Toggle navigation">
      <span class="navbar-toggler-icon"></span>
    </button>
    <div class="collapse navbar-collapse" id="navbarNav">
      <ul class="navbar-nav ms-auto">
        <li class="nav-item"><a class="nav-link" href="https://medium.com/hong-kong-linux-user-group">Technical Articles</a></li>
        <li class="nav-item"><a class="nav-link" href="https://www.facebook.com/groups/hklug/">Discussion Forum</a></li>
        <li class="nav-item"><a class="nav-link" href="/">News</a></li>
        <li class="nav-item"><a class="nav-link" href="/announce/">Announcements</a></li>
        <li class="nav-item"><a class="nav-link" href="/archive/">Archive</a></li>
        <li class="nav-item"><a class="nav-link" href="/about.html">About</a></li>
        <li class="nav-item"><a class="nav-link" href="/contact.html">Contact</a></li>
      </ul>
    </div>
  </div>
</nav>

<!-- menu end -->
```

- [ ] **Step 3: Rewrite `template/footer.html`**

Replace the entire file content with:

```html
<!-- footer start -->

  <footer class="container-fluid px-4 mt-4">
      <div class="row">
      <div class="col-12">
      <hr />
      <p>
      <a rel="license" href="https://creativecommons.org/licenses/by-sa/3.0/hk/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-sa/3.0/hk/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="https://creativecommons.org/licenses/by-sa/3.0/hk/">Creative Commons Attribution-ShareAlike 3.0 Hong Kong License</a>.
      <br />
      Copyright &copy; 1997-2020 Hong Kong Linux User Group.
      </p>
      <p><a href="/privacy.html">Privacy Policy | 私隱政策</a></p>
      <div class="community-links">
        <strong>Hong Kong Open Source Community:</strong><br>
        <a href="https://www.hklug.org/" target="_blank">HKLUG</a>
        <a href="https://www.hkcota.org/" target="_blank">HKCOTA</a>
        <a href="https://opensource.hk/" target="_blank">Open Source HK</a>
        <a href="https://hkoscon.org/" target="_blank">HKOSCon</a>
      </div>
      </div>
      </div>
  </footer>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>

</body>
</html>
<!-- footer end -->
```

- [ ] **Step 4: Commit**

```bash
git add template/header.html template/menu.html template/footer.html
git commit -m "feat: swap Foundation CDN for Bootstrap 5 in header/footer/menu"
```

---

## Task 2: Rewrite site/css/main.css for Bootstrap 5

**Files:**
- Create/restore: `site/css/main.css` (file was deleted; use `git add -f` to restore tracking)

- [ ] **Step 1: Create `site/css/main.css` with Bootstrap-compatible styles**

Write the following content to `site/css/main.css`:

```css
/* HKLUG Portal — Bootstrap 5 theme */

/* ── Section headers ─────────────────────────────────── */
.section-header {
  border-bottom: 3px solid #dee2e6;
  padding-bottom: 0.4rem;
  margin-bottom: 1.5rem;
  font-weight: 700;
}
.community-header { border-color: #0d6efd; color: #0d6efd; }
.it-news-header   { border-color: #198754; color: #198754; }

/* ── Cards ───────────────────────────────────────────── */
.announce-card,
.news-card {
  background: #fff;
  border-radius: 10px;
  box-shadow: 0 2px 8px rgba(0,0,0,.08);
  overflow: hidden;
  height: 100%;
}

/* ── Card cover image / placeholder ─────────────────── */
.card-cover {
  height: 200px;
  object-fit: cover;
  width: 100%;
  display: block;
}
.card-cover-placeholder {
  height: 200px;
  background: linear-gradient(135deg, #e9ecef 0%, #dee2e6 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  color: #adb5bd;
  font-size: 0.85rem;
}

/* ── Card body padding ───────────────────────────────── */
.card-body-inner {
  padding: 1rem;
}

/* ── Meta text ───────────────────────────────────────── */
.meta { font-size: 0.8rem; color: #6c757d; margin-bottom: 0.5rem; }

/* ── Read-more links ─────────────────────────────────── */
.read-more    { font-size: 0.82rem; font-weight: 600; color: #0d6efd; text-decoration: none; }
.it-news-more { font-size: 0.82rem; font-weight: 600; color: #198754; text-decoration: none; }
.read-more:hover    { text-decoration: underline; }
.it-news-more:hover { text-decoration: underline; }

/* ── Hero image on article pages ─────────────────────── */
.article-hero {
  width: 100%;
  max-height: 400px;
  object-fit: cover;
  border-radius: 8px;
  margin-bottom: 1.5rem;
}

/* ── Community links footer ─────────────────────────── */
.community-links { margin-top: 1rem; font-size: 0.9rem; }
.community-links a { margin-right: 1.2rem; }
```

- [ ] **Step 2: Force-add (file is gitignored by `site/` rule but was previously tracked)**

```bash
git add -f site/css/main.css
git commit -m "feat: rewrite site/css/main.css for Bootstrap 5"
```

---

## Task 3: Update frame templates to Bootstrap grid

**Files:**
- Modify: `template/frame.html`
- Modify: `template/frame_noannounce.html`

- [ ] **Step 1: Rewrite `template/frame.html`**

```html
[% INCLUDE header.html %]

<div class="container-fluid px-4">
<div class="row">
<div class="col-12" role="content">

[% INCLUDE announce.html %]

[% content %]

</div>
</div>
</div>

[% INCLUDE footer.html %]
```

- [ ] **Step 2: Rewrite `template/frame_noannounce.html`**

```html
[% INCLUDE header.html %]

<div class="container-fluid px-4">
<div class="row">
<div class="col-12" role="content">

[% content %]

</div>
</div>
</div>

[% INCLUDE footer.html %]
```

- [ ] **Step 3: Commit**

```bash
git add template/frame.html template/frame_noannounce.html
git commit -m "feat: update frame templates to Bootstrap 5 grid"
```

---

## Task 4: Update card templates to Bootstrap grid + image support

**Files:**
- Modify: `template/announce.html`
- Modify: `template/news.html`
- Modify: `template/announce_list.html`
- Modify: `template/announce_page.html`

Note: The `image` field on article objects will be `undef` until Task 6 (DataLoader) is done. Templates safely use `[% IF post.image %]` — no errors if field is missing.

- [ ] **Step 1: Rewrite `template/announce.html`**

```html
[% IF announces.size %]
<div class="row mb-2">
  <div class="col-12">
    <h2 class="section-header community-header">HK Open Source Community</h2>
  </div>
</div>
<div class="row g-3 mb-4" id="community-announcements">
  [% FOREACH post IN announces %]
  <div class="col-md-4">
    <div class="announce-card">
      [% IF post.image %]
      <img class="card-cover" src="[% post.image.match('^https?://') ? post.image : '/' _ post.image %]" alt="">
      [% ELSE %]
      <div class="card-cover-placeholder">No image</div>
      [% END %]
      <div class="card-body-inner">
        <h3><a href="[% post.url %]">[% post.title %]</a></h3>
        <p class="meta">[% post.date %]</p>
        <p>[% post.excerpt %]</p>
        <a href="[% post.url %]" class="read-more">Read more &rarr;</a>
      </div>
    </div>
  </div>
  [% END %]
</div>
[% END %]
```

- [ ] **Step 2: Rewrite `template/news.html`**

```html
[% WRAPPER frame.html %]

[% IF news.size %]
<div class="row mb-2">
  <div class="col-12">
    <h2 class="section-header it-news-header">IT News</h2>
  </div>
</div>
<div class="row g-3 mb-4" id="it-news">
  [% FOREACH post IN news %]
  <div class="col-md-3">
    <div class="news-card">
      [% IF post.image %]
      <img class="card-cover" src="[% post.image.match('^https?://') ? post.image : '/' _ post.image %]" alt="">
      [% ELSE %]
      <div class="card-cover-placeholder">No image</div>
      [% END %]
      <div class="card-body-inner">
        <h3><a href="[% post.url %]">[% post.title %]</a></h3>
        <p class="meta">[% post.date %]</p>
        <p>[% post.excerpt %]</p>
        <a href="[% post.url %]" class="it-news-more">Read more &rarr;</a>
      </div>
    </div>
  </div>
  [% END %]
</div>
[% END %]

[% END %]
```

- [ ] **Step 3: Rewrite `template/announce_list.html`**

```html
[% WRAPPER frame_noannounce.html
   title = 'Community Announcements'
   page_url = site_url _ '/announce/'
%]

<div class="row mb-3">
  <div class="col-12">
    <h1>Community Announcements</h1>

    [% IF posts.size %]
    <div class="announcements-list">
      [% FOREACH post IN posts %]
      <div class="announce-item mb-4 pb-3 border-bottom">
        <h3><a href="/announce/[% post.slug %].html">[% post.title %]</a></h3>
        <p class="meta">[% post.date %]</p>
        [% IF post.excerpt %]
        <p>[% post.excerpt %]</p>
        [% END %]
        <a href="/announce/[% post.slug %].html" class="read-more">Read more &rarr;</a>
      </div>
      [% END %]
    </div>
    [% ELSE %]
    <p>No announcements at this time.</p>
    [% END %]
  </div>
</div>

[% END %]
```

- [ ] **Step 4: Rewrite `template/announce_page.html`**

```html
[% WRAPPER frame_noannounce.html
   title = post.title
   page_url = site_url _ '/announce/' _ post.slug _ '.html'
%]
  <div class="row mb-2">
    <div class="col-12">
      <p><a href="/announce/">&larr; All Announcements</a></p>
    </div>
  </div>

  <article>
    <div class="row">
      <div class="col-12">
        <h1>[% post.title %]</h1>
        <p class="meta">[% post.date %][% IF post.author %] | [% post.author %][% END %]</p>

        [% IF post.image %]
        <img class="article-hero" src="[% post.image.match('^https?://') ? post.image : '/' _ post.image %]" alt="">
        [% END %]

        <div class="content">
          [% post.content %]
        </div>

        [% IF post.tags.size %]
        <p class="post-tags">Tags:
          [% FOREACH tag = post.tags %]<a href="/tags/[% tag.replace('\s+', '-') | uri %]/">[% tag | html %]</a>[% UNLESS loop.last %], [% END %][% END %]
        </p>
        [% END %]
      </div>
    </div>
  </article>

  <div class="row mt-3">
    <div class="col-12">
      <p><a href="/announce/">&larr; All Announcements</a></p>
    </div>
  </div>
[% END %]
```

- [ ] **Step 5: Commit**

```bash
git add template/announce.html template/news.html template/announce_list.html template/announce_page.html
git commit -m "feat: Bootstrap 5 grid and image card layout in card templates"
```

---

## Task 5: DataLoader.pm — parse Image: field and extract \<img\> fallback

**Files:**
- Modify: `lib/Sitegen/DataLoader.pm`
- Modify: `t/DataLoader.t`

- [ ] **Step 1: Write failing tests for `image` field in `t/DataLoader.t`**

Update the test count at the top of the file from `tests => 31` to `tests => 36`.

Add these tests after the existing test block (after the `load_announce` tests), before `1;` or the end of the file:

```perl
# Test 5: Image: field parsed
my $f5 = write_txt($tmpdir, 'test5.txt', <<'END');
Date: 2025-01-01
Author: Bot
Title: Image Test
Image: images/test5.jpg
Content:
Body text.
END
my $post5 = load_data($f5);
is($post5->{image}, 'images/test5.jpg', 'Image: field parsed correctly');

# Test 6: no Image: field → extract first <img src> from content
my $f6 = write_txt($tmpdir, 'test6.txt', <<'END');
Date: 2025-01-02
Author: Bot
Title: Img Extraction Test
Content:
Some text. <img src="https://example.com/photo.jpg" alt=""> More text.
END
my $post6 = load_data($f6);
is($post6->{image}, 'https://example.com/photo.jpg', '<img src> extracted as fallback image');

# Test 7: Image: field takes priority over <img> in content
my $f7 = write_txt($tmpdir, 'test7.txt', <<'END');
Date: 2025-01-03
Author: Bot
Title: Priority Test
Image: images/manual.jpg
Content:
Text. <img src="https://example.com/other.jpg" alt="">
END
my $post7 = load_data($f7);
is($post7->{image}, 'images/manual.jpg', 'Manual Image: field takes priority over <img> in content');

# Test 8: no Image: and no <img> → image is undef
my $f8 = write_txt($tmpdir, 'test8.txt', <<'END');
Date: 2025-01-04
Author: Bot
Title: No Image Test
Content:
No images here.
END
my $post8 = load_data($f8);
is($post8->{image}, undef, 'no image source → image field is undef');

# Test 9: slug derived from filename
is($post5->{slug}, 'test5', 'slug derived from filename for image test file');
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd /path/to/hklug-sitegen
perl -Ilib t/DataLoader.t 2>&1 | tail -10
```

Expected: `not ok 32 - Image: field parsed correctly` (and similar failures for 33–36).

- [ ] **Step 3: Add `Image:` parsing to `load_data()` in `lib/Sitegen/DataLoader.pm`**

In the header-parsing `if/elsif` chain (after the `Title:` line), add:

```perl
elsif ($line =~ m/^Image:\s*(.+)$/)  { $post{image}  = $1 }
```

Then, after the line `$post{excerpt} = ...`, add the `<img>` extraction fallback:

```perl
# image fallback: extract first <img src> from rendered HTML if no manual Image: field
unless ($post{image}) {
    if ($post{content} =~ /<img[^>]+src="([^"]+)"/i) {
        $post{image} = $1;
    }
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
perl -Ilib t/DataLoader.t 2>&1 | tail -5
```

Expected: `ok 32..36` and `All tests successful`.

- [ ] **Step 5: Run the full test suite to check for regressions**

```bash
perl -Ilib t/*.t 2>&1 | tail -5
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/Sitegen/DataLoader.pm t/DataLoader.t
git commit -m "feat: add Image: field parsing and <img> extraction fallback to DataLoader"
```

---

## Task 6: sitegen.pl — copy_static() for static/images/

**Files:**
- Modify: `bin/sitegen.pl`
- Create: `static/images/.gitkeep`

- [ ] **Step 1: Create the `static/images/` directory**

```bash
mkdir -p static/images
touch static/images/.gitkeep
git add static/images/.gitkeep
```

- [ ] **Step 2: Add `copy_static()` to `bin/sitegen.pl`**

Add `use File::Find qw(find);` and `use File::Copy qw(copy);` to the `use` block at the top of `bin/sitegen.pl` (after the existing `use File::Path` line):

```perl
use File::Find  qw(find);
use File::Copy  qw(copy);
```

Add the `copy_static()` sub before the `main()` sub (or anywhere before it's called):

```perl
=head2 copy_static()

Copies C<static/images/> to C<site/images/> before page generation.
Images in C<static/images/> are tracked by git; C<site/images/> is gitignored.

=cut

sub copy_static {
    my $src = "$base_dir/static/images";
    my $dst = "$base_dir/site/images";
    return unless -d $src;
    make_path($dst);
    find(sub {
        return if -d $_;
        (my $rel = $File::Find::name) =~ s{^\Q$src/}{};
        my $target = "$dst/$rel";
        my $target_dir = $target;
        $target_dir =~ s{/[^/]+$}{};
        make_path($target_dir);
        copy($File::Find::name, $target) or warn "copy_static: cannot copy $File::Find::name: $!";
    }, $src);
}
```

- [ ] **Step 3: Call `copy_static()` at the start of `main()` in `bin/sitegen.pl`**

In the `main()` sub, add `copy_static();` as the first line after `my $config = load_config();`:

```perl
sub main {
    my $config = load_config();
    copy_static();   # copy static/images/ → site/images/
    my $cache  = $force ? {} : load_cache($cache_file);
    ...
```

- [ ] **Step 4: Run the full test suite**

```bash
perl -Ilib t/*.t 2>&1 | tail -5
```

Expected: all tests pass (no changes to DataLoader behaviour).

- [ ] **Step 5: Commit**

```bash
git add bin/sitegen.pl static/images/.gitkeep
git commit -m "feat: add copy_static() to sync static/images/ into site/images/ at build time"
```

---

## Task 7: newsfeed.pl — fetch OG image at RSS import time

**Files:**
- Modify: `bin/newsfeed.pl`
- Modify: `TEMPLATE.txt`

- [ ] **Step 1: Update `TEMPLATE.txt` to include `[%IMAGE]` placeholder**

Replace the content of `TEMPLATE.txt` with:

```
Date: [%DATE]
Author: [%AUTHOR]
Title: [%TITLE]
[%IMAGE]
Content:
[%CONTENT]
```

Note: When `[%IMAGE]` is replaced with an empty string, an empty line will appear before `Content:` — this is harmless as `load_data()` skips blank lines in the header section. (Verify this is the case — the parser skips lines with `next if $line =~ m|^//|` but blank lines are also naturally `elsif`-skipped since they match no pattern. Confirm the blank line is safe.)

- [ ] **Step 2: Add `use HTTP::Tiny;` to `bin/newsfeed.pl`**

Add after the existing `use` block:

```perl
use HTTP::Tiny;
use File::Path qw(make_path);
```

- [ ] **Step 3: Add `fetch_og_image()` sub to `bin/newsfeed.pl`**

Add this sub after the existing `use` declarations, before `our $data_path = ...`:

```perl
# Fetch the og:image from a URL and save it to static/images/<slug>.<ext>.
# Returns the relative path "images/<slug>.<ext>" on success, or undef on failure.
sub fetch_og_image {
    my ($url, $slug) = @_;
    my $ua = HTTP::Tiny->new(timeout => 10);

    # Fetch the article page
    my $resp = $ua->get($url);
    return unless $resp->{success};

    my $html = $resp->{content};

    # Extract og:image — handle both attribute orderings
    my ($og_url) = ($html =~ /<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i);
    unless ($og_url) {
        ($og_url) = ($html =~ /<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']/i);
    }
    return unless $og_url;

    # Download the image
    my $img_resp = $ua->get($og_url);
    return unless $img_resp->{success};

    my $ct = $img_resp->{headers}{'content-type'} // '';
    return unless $ct =~ m{^image/};

    my $ext = $ct =~ /jpeg|jpg/i ? 'jpg'
            : $ct =~ /png/i      ? 'png'
            : $ct =~ /gif/i      ? 'gif'
            : $ct =~ /webp/i     ? 'webp'
            :                      'jpg';

    my $img_dir = "$Bin/../static/images";
    make_path($img_dir);

    my $img_file = "$img_dir/$slug.$ext";
    open(my $fh, '>:raw', $img_file) or return;
    print $fh $img_resp->{content};
    close $fh;

    return "images/$slug.$ext";
}
```

- [ ] **Step 4: Update `create_post()` to fetch OG image and substitute `[%IMAGE]`**

In `create_post()`, find the section where `$datefile` is computed, then add OG fetch logic.
In the template substitution loop, add the `[%IMAGE]` replacement.

The updated `create_post()` should look like:

```perl
sub create_post {
    my ($feed_name, $entry) = @_;

    print Dumper($entry);

    my $parser = DateTime::Format::Strptime->new(
        pattern => '%a, %d %b %Y %H:%M:%S %z',
        on_error => 'croak',
    );

    my $title = $entry->{'title'};
    my $author = $entry->{'dc'}->{'creator'} . " ($feed_name)";

    my $content = 'News Feed - Source :  ' . "\n" . '[' . $feed_name . ' - ' . $title .'](' . $entry->{'link'} . ')' . "\n\n";
    $content .= $entry->{'description'};

    my $url = $new_feed_home_hash->{$feed_name};
    $content =~ s/\<img src=\"\//\<img src=\"$url\//g;
    $content =~ s/href=\"\//href=\"$url\//g;

    my $dt = $parser->parse_datetime($entry->{'pubDate'});

    my $year   = $dt->year;
    my $month  = $dt->month;
    my $day    = $dt->day;
    my $hour   = $dt->hour;
    my $minute = $dt->minute;
    my $second = $dt->second;

    my $ymd1    = $dt->ymd;
    my $ymd2    = $dt->ymd('');

    my $hms1    = $dt->hms;
    my $hms2    = $dt->hms('');

    my $datefile = "$ymd2-$hms2";
    my $date = "$ymd1 $hms1";

    # Try to fetch OG image from the article source URL
    my $image_line = '';
    if (my $img_rel = fetch_og_image($entry->{'link'}, $datefile)) {
        $image_line = "Image: $img_rel";
        print "  Fetched OG image: $img_rel\n";
    }

    open FILEIN,  "<:utf8", $template;
    open FILEOUT, ">:utf8", "$data_path/$datefile.txt";
    while (<FILEIN>) {
        my $line = $_;
        $line =~ s/\[%DATE\]/$date/;
        $line =~ s/\[%AUTHOR\]/$author/;
        $line =~ s/\[%TITLE\]/$title/;
        $line =~ s/\[%IMAGE\]/$image_line/;
        $line =~ s/\[%CONTENT\]/$content/;
        print $line;
        print FILEOUT $line;
    }
    close FILEIN;
    close FILEOUT;
}
```

- [ ] **Step 5: Run the full test suite (newsfeed.pl has no unit tests, just confirm no syntax errors)**

```bash
perl -c bin/newsfeed.pl 2>&1
perl -Ilib t/*.t 2>&1 | tail -5
```

Expected: `bin/newsfeed.pl syntax OK`, all tests pass.

- [ ] **Step 6: Commit**

```bash
git add bin/newsfeed.pl TEMPLATE.txt
git commit -m "feat: fetch OG image at RSS import time and write Image: field to article .txt"
```

---

## Task 8: Integration test and visual verification

**Files:**
- No code changes — verification only.

- [ ] **Step 1: Run the full test suite one final time**

```bash
cd /path/to/hklug-sitegen
perl -Ilib t/*.t 2>&1
```

Expected: all 36 tests pass (31 existing + 5 new image tests). If any test fails, fix before proceeding.

- [ ] **Step 2: Generate the site locally**

```bash
perl -Ilib bin/sitegen.pl --force 2>&1 | tail -5
```

Expected: `Done.` with no errors or warnings.

- [ ] **Step 3: Spot-check generated output**

```bash
# Confirm Bootstrap CSS is referenced (not Foundation)
grep -c "bootstrap" site/index.html

# Confirm no Foundation references remain
grep -c "foundation" site/index.html

# Confirm card-cover-placeholder is present (articles without images show placeholder)
grep -c "card-cover-placeholder" site/index.html

# Confirm announce section rendered
grep -c "community-announcements" site/index.html

# Confirm it-news section rendered
grep -c "it-news" site/index.html
```

Expected output:
- `bootstrap` count > 0
- `foundation` count = 0
- `card-cover-placeholder` count > 0 (until real images are fetched by newsfeed.pl)
- `community-announcements` count = 1
- `it-news` count = 1

- [ ] **Step 4: Check an individual announce page**

```bash
ls site/announce/ | head -5
grep -l "article-hero\|card-cover" site/announce/*.html | head -3
```

- [ ] **Step 5: Commit (if any last-minute fixes were made)**

If no fixes needed, just confirm:

```bash
git log --oneline -6
```

Expected to see the 6 commits from Tasks 1–7.

- [ ] **Step 6: Push to remote**

```bash
git push origin master
```

---

## Self-Review Notes

**Spec coverage check:**
- ✅ Bootstrap 5 CDN swap → Tasks 1, 2
- ✅ Bootstrap navbar → Task 1
- ✅ Grid class migration → Tasks 3, 4
- ✅ CSS rewrite (Bootstrap-compatible) → Task 2
- ✅ `Image:` field parsing in DataLoader → Task 5
- ✅ `<img>` extraction fallback → Task 5
- ✅ OG image fetch in newsfeed.pl → Task 7
- ✅ `static/images/` tracked by git → Task 6
- ✅ `copy_static()` in sitegen.pl → Task 6
- ✅ Card templates show image/placeholder → Task 4
- ✅ Article pages show hero image → Task 4
- ✅ New DataLoader tests → Task 5
- ✅ Integration verification → Task 8

**Blank line in TEMPLATE.txt:** When `[%IMAGE]` is an empty string, the line becomes blank. Verify `load_data()` is safe: it processes `if/elsif` checks on each header line — a blank line matches no pattern and is silently skipped. ✅ Safe.

**`site/css/main.css` gitignore workaround:** The file was previously tracked before `site/` was added to `.gitignore`. Use `git add -f site/css/main.css` to force-add it. This is intentional and documented in Task 2.
