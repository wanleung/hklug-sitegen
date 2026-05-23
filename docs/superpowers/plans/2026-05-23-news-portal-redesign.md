# hklug-sitegen News Portal Front Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the hklug-sitegen front page from a blog layout into a two-section news portal: blue "HK Open Source Community" strip (3 cards from `data/top/`) and green "IT News" grid (8 cards from `data/news/`), with new individual pages at `/announce/<slug>.html` for all announcement files.

**Architecture:** Add `excerpt` and `slug` fields to `DataLoader.pm` so templates can render card previews without TT filter complexity. Add `gen_announcements()` to `sitegen.pl` to generate individual and listing pages for `data/top/` files. Redesign `frame.html` (full-width), `announce.html` (blue card strip), `news.html` (green grid), plus two new templates `announce_page.html` and `announce_list.html`. CSS additions go into the existing `site/css/main.css` static file.

**Tech Stack:** Perl 5, Template Toolkit 2, Foundation CSS 5, `File::Basename` (core), `Text::Markdown::Discount`

---

### Task 1: Add `slug` and `excerpt` to `DataLoader.pm`

**Files:**
- Modify: `lib/Sitegen/DataLoader.pm`
- Modify: `t/DataLoader.t` (tests count: 24 → 30)

- [ ] **Step 1: Write the failing tests** — append to `t/DataLoader.t`, update test count header from `24` to `30`

```perl
# Change the top line:
use Test::More tests => 30;
```

Then append at the end of `t/DataLoader.t` (before the final newline):

```perl
# Test 10: slug is set from filename
my $slugfile = write_txt($tmpdir, '20260101-slug-test.txt', "Date: 2026-01-01\nAuthor: A\nTitle: Slug\nContent:\nBody.\n");
my $slugpost = load_data($slugfile);
is($slugpost->{slug}, '20260101-slug-test', 'slug is basename without .txt');

# Test 11: excerpt strips HTML tags and truncates to 180 chars
my $longfile = write_txt($tmpdir, 'long.txt', "Date: 2026-01-01\nAuthor: A\nTitle: Long\nContent:\n" . ("word " x 60) . "\n");
my $longpost = load_data($longfile);
ok(defined $longpost->{excerpt}, 'excerpt is set');
ok(length($longpost->{excerpt}) <= 183, 'excerpt is max 180 chars plus ...');  # 180 + "..."
like($longpost->{excerpt}, qr/\.\.\.$/, 'long excerpt ends with ...');

# Test 12: short content excerpt has no trailing ellipsis
my $shortfile = write_txt($tmpdir, 'short.txt', "Date: 2026-01-01\nAuthor: A\nTitle: Short\nContent:\nShort content.\n");
my $shortpost = load_data($shortfile);
unlike($shortpost->{excerpt}, qr/\.\.\.$/, 'short excerpt has no ...');
is($shortpost->{excerpt}, 'Short content.', 'short excerpt matches plain text');
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /path/to/hklug-sitegen
perl -Ilib t/DataLoader.t
```

Expected: FAIL — `slug` field undefined, `excerpt` field undefined.

- [ ] **Step 3: Implement `slug` and `excerpt` in `DataLoader.pm`**

Add `use File::Basename qw(basename);` to the `use` block at the top of `lib/Sitegen/DataLoader.pm`.

Replace the final lines of `load_data()` (currently the three lines that set defaults and call markdown):

```perl
    $post{tags}    //= [];
    $post{content}   = markdown($post{content} // '');
    return \%post;
```

With:

```perl
    $post{tags}    //= [];
    $post{content} = markdown($post{content} // '');

    # slug: filename stem without extension
    (my $slug = basename($filename)) =~ s/\.txt$//;
    $post{slug} = $slug;

    # excerpt: strip HTML tags, collapse whitespace, truncate to 180 chars
    (my $plain = $post{content}) =~ s/<[^>]+>//g;
    $plain =~ s/\s+/ /g;
    $plain =~ s/^\s+|\s+$//g;
    $post{excerpt} = length($plain) > 180 ? substr($plain, 0, 180) . '...' : $plain;

    return \%post;
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
perl -Ilib t/DataLoader.t
```

Expected: `ok 1 - use_ok ... ok 30` — all 30 tests pass.

- [ ] **Step 5: Run full test suite to ensure no regressions**

```bash
prove -l t/
```

Expected: All test files pass.

- [ ] **Step 6: Commit**

```bash
git add lib/Sitegen/DataLoader.pm t/DataLoader.t
git commit -m "feat: add slug and excerpt fields to DataLoader load_data()"
```

---

### Task 2: Add portal CSS to `site/css/main.css`

**Files:**
- Modify: `site/css/main.css`

- [ ] **Step 1: Append portal styles to `site/css/main.css`**

```css
/* ===== News Portal Styles ===== */

/* Section header bars */
.section-header {
  padding: 8px 16px;
  font-size: 13px;
  font-weight: bold;
  letter-spacing: 1px;
  text-transform: uppercase;
  color: #fff;
  margin-bottom: 0;
}
.community-header { background: #1a6fa8; }
.it-news-header   { background: #1e8a4a; }

/* Community announcement cards */
.community-section { background: #e8f4fd; padding: 12px 0 4px; }
.announce-card {
  background: #fff;
  border: 1px solid #b8d8f0;
  border-top: 3px solid #1a6fa8;
  border-radius: 3px;
  padding: 10px 12px;
  margin-bottom: 12px;
  height: 100%;
}
.announce-card h4 { font-size: 14px; margin-bottom: 4px; }
.announce-card .meta { font-size: 11px; color: #666; margin-bottom: 6px; }
.announce-card .read-more { font-size: 11px; color: #1a6fa8; }

/* IT news grid */
.it-news-section { background: #f0f8f2; padding: 12px 0 4px; }
.news-card {
  background: #fff;
  border: 1px solid #b8e0c0;
  border-left: 3px solid #1e8a4a;
  border-radius: 3px;
  padding: 10px 12px;
  margin-bottom: 12px;
}
.news-card h4 { font-size: 13px; margin-bottom: 4px; line-height: 1.4; }
.news-card h4 a { color: #1e3a28; }
.news-card h4 a:hover { color: #1e8a4a; }
.news-card .meta { font-size: 11px; color: #666; margin-bottom: 6px; }
.news-card .read-more { font-size: 11px; color: #1e8a4a; }
.it-news-more { text-align: right; padding: 4px 0 8px; font-size: 12px; }
.it-news-more a { color: #1e8a4a; }

/* Community links in footer */
.community-links { margin-top: 8px; font-size: 12px; }
.community-links a { margin-right: 12px; }
```

- [ ] **Step 2: Commit**

```bash
git add site/css/main.css
git commit -m "feat: add news portal CSS classes to main.css"
```

---

### Task 3: Update `template/menu.html` — add Announcements link

**Files:**
- Modify: `template/menu.html`

- [ ] **Step 1: Add Announcements nav link**

In `template/menu.html`, find the line:
```html
            <li><a href="/">News</a></li>
```

Add the Announcements link after `News`:
```html
            <li><a href="/">News</a></li>
            <li><a href="/announce/">Announcements</a></li>
```

- [ ] **Step 2: Commit**

```bash
git add template/menu.html
git commit -m "feat: add Announcements nav link to menu"
```

---

### Task 4: Redesign `template/frame.html` and `template/frame_noannounce.html` — full-width, no sidebar

**Files:**
- Modify: `template/frame.html`
- Modify: `template/frame_noannounce.html`

- [ ] **Step 1: Replace `template/frame.html` with full-width layout**

Replace the entire content of `template/frame.html` with:

```html
[% INCLUDE header.html %]

<div class="row">
<div class="large-12 columns" role="content">

[% INCLUDE announce.html %]

[% content %]

</div>
</div>

[% INCLUDE footer.html %]
```

- [ ] **Step 2: Replace `template/frame_noannounce.html` with full-width layout**

Replace the entire content of `template/frame_noannounce.html` with:

```html
[% INCLUDE header.html %]

<div class="row">
<div class="large-12 columns" role="content">

[% content %]

</div>
</div>

[% INCLUDE footer.html %]
```

- [ ] **Step 3: Commit**

```bash
git add template/frame.html template/frame_noannounce.html
git commit -m "feat: remove sidebar from frame templates, full-width layout"
```

---

### Task 5: Update `template/footer.html` — add community links

**Files:**
- Modify: `template/footer.html`

- [ ] **Step 1: Add community links block to footer**

In `template/footer.html`, find the existing `<p>` tag with the CC licence, and add a community links paragraph after it (before the closing `</div>`):

Find:
```html
      <p><a href="/privacy.html">Privacy Policy | 私隱政策</a></p>
      </div>
```

Replace with:
```html
      <p><a href="/privacy.html">Privacy Policy | 私隱政策</a></p>
      <div class="community-links">
        Community:
        <a href="https://www.facebook.com/groups/hklug/">HKLUG Facebook Group</a>
        <a href="https://www.facebook.com/hkcota">HKCOTA</a>
        <a href="https://www.facebook.com/opensourcehk">OpenSource HK</a>
        <a href="https://www.facebook.com/hkoscon">HKOSCon</a>
      </div>
      </div>
```

- [ ] **Step 2: Commit**

```bash
git add template/footer.html
git commit -m "feat: add community links to footer (moved from sidebar)"
```

---

### Task 6: Redesign `template/announce.html` — blue 3-card strip

**Files:**
- Modify: `template/announce.html`

- [ ] **Step 1: Replace `template/announce.html` with card strip**

Replace the entire content of `template/announce.html` with:

```html
[% IF announces && announces.size %]
<div class="section-header community-header">&#128226; HK Open Source Community News &amp; Events</div>
<div class="community-section">
  <div class="row">
    [% FOREACH announce IN announces %]
    <div class="large-4 columns">
      <div class="announce-card">
        <h4>[% announce.title | html %]</h4>
        <p class="meta">[% announce.author | html %] &middot; [% announce.date | html %]</p>
        <p>[% announce.excerpt | html %]</p>
        <a class="read-more" href="/announce/[% announce.slug | uri %].html">Read more &#8594;</a>
      </div>
    </div>
    [% END %]
  </div>
</div>
[% END %]
```

- [ ] **Step 2: Commit**

```bash
git add template/announce.html
git commit -m "feat: redesign announce.html as blue 3-card community strip"
```

---

### Task 7: Redesign `template/news.html` — green 2×4 IT news grid

**Files:**
- Modify: `template/news.html`

- [ ] **Step 1: Replace `template/news.html` with card grid**

Replace the entire content of `template/news.html` with:

```html
[% WRAPPER frame.html %]

<div class="section-header it-news-header">&#127760; IT News</div>
<div class="it-news-section">
  <div class="row">
    [% FOREACH post = news %]
    <div class="large-6 columns">
      <div class="news-card">
        <h4><a href="[% post.url | html %]">[% post.title | html %]</a></h4>
        <p class="meta">[% post.date | html %]</p>
        <p>[% post.excerpt | html %]</p>
        <a class="read-more" href="[% post.url | html %]">Read more &#8594;</a>
      </div>
    </div>
    [% END %]
  </div>
  <div class="it-news-more"><a href="/archive/">More IT News &#8594; Archive</a></div>
</div>

[% END %]
```

- [ ] **Step 2: Commit**

```bash
git add template/news.html
git commit -m "feat: redesign news.html as green 2x4 IT news card grid"
```

---

### Task 8: Create `template/announce_page.html` — individual announcement page

**Files:**
- Create: `template/announce_page.html`

- [ ] **Step 1: Create `template/announce_page.html`**

```html
[% WRAPPER frame_noannounce.html %]
  [% PROCESS post_nav.html %]
  <hr />
  [% PROCESS post.html %]
  [% PROCESS post_nav.html %]
[% END %]
```

- [ ] **Step 2: Commit**

```bash
git add template/announce_page.html
git commit -m "feat: add announce_page.html template for individual announcement pages"
```

---

### Task 9: Create `template/announce_list.html` — announcements listing page

**Files:**
- Create: `template/announce_list.html`

- [ ] **Step 1: Create `template/announce_list.html`**

```html
[% WRAPPER frame_noannounce.html %]

  <div class="row">
  <h1>[% pagetitle %]</h1>
  <p>
  [% FOREACH post = posts %]
    [% post.date %] - <a href="[% post.url | html %]">[% post.title | html %]</a><br />
  [% END %]
  </p>
  </div>

[% END %]
```

- [ ] **Step 2: Commit**

```bash
git add template/announce_list.html
git commit -m "feat: add announce_list.html template for /announce/ listing page"
```

---

### Task 10: Update `bin/sitegen.pl` — `gen_announcements()`, `gen_home()` (8 posts + announce URLs)

**Files:**
- Modify: `bin/sitegen.pl`

- [ ] **Step 1: Add `$announce_folder` variable and `make_path` call**

Find the `our` variable declarations near the top of `bin/sitegen.pl`:
```perl
our $site_folder    = "$base_dir/site";
our $archive_folder = "$site_folder/archive";
```

Add after `$archive_folder`:
```perl
our $announce_folder = "$site_folder/announce";
```

Then find `make_path($site_folder, $archive_folder);` and change it to:
```perl
make_path($site_folder, $archive_folder, $announce_folder);
```

- [ ] **Step 2: Update `gen_home()` to load 8 posts and set `url` on announces**

Find in `gen_home()`:
```perl
    for my $i (1..5) {
```
Change to:
```perl
    for my $i (1..8) {
```

Find in `gen_home()`:
```perl
    my $announces = load_announce($top_dir, $config);
    my $seo_post = { title => $config->{site_name} . ' > News', content => '' };
```

Change to:
```perl
    my $announces = load_announce($top_dir, $config);
    for my $a (@$announces) {
        $a->{url} = "/announce/$a->{slug}.html";
    }
    my $seo_post = { title => $config->{site_name} . ' > News', content => '' };
```

- [ ] **Step 3: Add `gen_announcements()` function**

Add the following function after the closing brace of `gen_archive()` and before the `=head2 gen_tags` pod block:

```perl
=head2 gen_announcements($tt, $config)

Renders individual announcement pages (C</announce/E<lt>slugE<gt>.html>) for
every C<.txt> file in C<data/top/> and a listing page at C</announce/index.html>.

=cut

sub gen_announcements {
    my ($tt, $config) = @_;
    my @filelist;
    opendir(my $dh, $top_dir) or die "Cannot open $top_dir: $!";
    while (my $f = readdir($dh)) { push @filelist, $f if $f =~ m/\.txt$/ }
    closedir($dh);

    my @sortlist = sort @filelist;
    my $total    = scalar @sortlist;
    my (@allposts, $count);
    $count = 0;

    for my $file (@sortlist) {
        (my $newfile = $file) =~ s/\.txt$/.html/;
        my $srcfile = "$top_dir/$file";
        my $outfile = "$announce_folder/$newfile";

        my $post = load_data($srcfile);
        $post->{url} = "/announce/$newfile";
        push @allposts, $post;

        my $previndex = ($count - 1 < 0)       ? 0          : $count - 1;
        my $nextindex = ($count + 1 >= $total)  ? $total - 1 : $count + 1;

        (my $prevfile  = $sortlist[$previndex]) =~ s/\.txt$/.html/;
        (my $nextfile  = $sortlist[$nextindex]) =~ s/\.txt$/.html/;
        (my $startfile = $sortlist[$total - 1]) =~ s/\.txt$/.html/;
        (my $endfile   = $sortlist[0])          =~ s/\.txt$/.html/;

        tt_process($tt, 'announce_page.html', {
            title => $config->{site_name} . ' > Announcements > ' . $post->{title},
            post  => $post,
            url   => {
                front     => "/announce/$startfile",
                end       => "/announce/$endfile",
                prev      => "/announce/$prevfile",
                next      => "/announce/$nextfile",
                home      => "/announce/",
                hometitle => "Announcements",
            },
            seo => seo_meta($post, $config, "/announce/$newfile"),
        }, $outfile);
        print "GEN announce $file\n";
        $count++;
    }

    # Announcement listing — always regenerate, newest-first
    my @newest_first = reverse @allposts;
    my $seo_post = { title => $config->{site_name} . ' > Announcements', content => '' };
    tt_process($tt, 'announce_list.html', {
        title     => $config->{site_name} . ' > Announcements',
        pagetitle => 'Community Announcements',
        posts     => \@newest_first,
        seo       => seo_meta($seo_post, $config, '/announce/'),
    }, "$announce_folder/index.html");
}
```

- [ ] **Step 4: Call `gen_announcements()` from `main()`**

Find in `main()`:
```perl
    gen_home($tt, $config);
    gen_pages($tt, $config);
```

Change to:
```perl
    gen_home($tt, $config);
    gen_announcements($tt, $config);
    gen_pages($tt, $config);
```

- [ ] **Step 5: Commit**

```bash
git add bin/sitegen.pl
git commit -m "feat: add gen_announcements(), update gen_home() for 8 posts and announce URLs"
```

---

### Task 11: Integration test — run sitegen and verify output

- [ ] **Step 1: Install Perl dependencies (if not already installed)**

```bash
sudo apt-get install -y libtemplate-perl libyaml-tiny-perl libtext-markdown-discount-perl
```

- [ ] **Step 2: Run full test suite**

```bash
cd /path/to/hklug-sitegen
prove -l t/
```

Expected: All test files (`Cache.t`, `DataLoader.t`, `Privacy.t`, `SEO.t`, `Tags.t`) pass.

- [ ] **Step 3: Run sitegen**

```bash
perl bin/sitegen.pl --force 2>&1
```

Expected: Lines like `GEN 20260521-xxx.txt` and `GEN announce 20230807-102614.txt`, ending with `Done.` — no errors.

- [ ] **Step 4: Verify front page has both sections**

```bash
grep -c "community-header\|it-news-header" site/index.html
```

Expected: `2` (both section headers present).

- [ ] **Step 5: Verify announce individual pages exist**

```bash
ls site/announce/*.html | head -5
```

Expected: Several `.html` files listed (one per `data/top/*.txt` file).

- [ ] **Step 6: Verify announce listing exists**

```bash
grep -c "Community Announcements" site/announce/index.html
```

Expected: `1`

- [ ] **Step 7: Verify announce cards on front page link to /announce/**

```bash
grep "href=\"/announce/" site/index.html | head -3
```

Expected: Three `href="/announce/..."` links (one per community card).

- [ ] **Step 8: Final commit (if any fix-ups were needed)**

```bash
git add -A
git commit -m "fix: integration test corrections" # only if needed
```
