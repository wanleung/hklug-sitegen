# hklug-sitegen SEO, Tag Pages & Incremental Generation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add SEO meta tags, tag-based browsing pages, and SHA-256-based incremental generation to hklug-sitegen while refactoring the monolithic `sitegen.pl` into focused Perl modules.

**Architecture:** `bin/sitegen.pl` becomes a thin orchestrator that delegates to four new modules under `lib/Sitegen/`: `DataLoader` (post parsing + tag extraction), `Cache` (SHA-256 incremental skip), `SEO` (og: meta hashref), and `Tags` (tag collection + page generation). Site configuration moves from hardcoded globals into `data/sitegen.yaml`.

**Tech Stack:** Perl 5, Template Toolkit (`Template`), `Digest::SHA` (core), `JSON::PP` (core), `YAML::Tiny` (needs install), `Text::Markdown::Discount` (existing).

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `data/sitegen.yaml` | Site URL, name, description config |
| Create | `.gitignore` | Ignore generated cache + site output |
| Create | `lib/Sitegen/DataLoader.pm` | `load_data()`, `load_announce()`, Tags: parsing |
| Create | `lib/Sitegen/Cache.pm` | SHA-256 cache load/save/check/update |
| Create | `lib/Sitegen/SEO.pm` | `seo_meta()` returns description + og: hashref |
| Create | `lib/Sitegen/Tags.pm` | `collect_tags()`, `tag_slug()`, `gen_tag_pages()` |
| Modify | `bin/sitegen.pl` | Use all modules, add `--force`, incremental archive, gen_tags |
| Modify | `template/header.html` | Dynamic `<title>`, conditional SEO block |
| Modify | `template/post.html` | Display tags as links |
| Modify | `template/archive.html` | Display tags as links |
| Create | `template/tag_list.html` | All-tags index page |
| Create | `template/tag_page.html` | Posts for a single tag |
| Create | `t/DataLoader.t` | Unit tests for DataLoader |
| Create | `t/Cache.t` | Unit tests for Cache |
| Create | `t/SEO.t` | Unit tests for SEO |
| Create | `t/Tags.t` | Unit tests for Tags |

---

## Task 1: Infrastructure — install deps, config file, gitignore, lib dir

**Files:**
- Create: `data/sitegen.yaml`
- Create: `.gitignore`
- Create: `lib/Sitegen/` (directory)

- [ ] **Step 1: Install YAML::Tiny**

```bash
sudo apt-get install -y libyaml-tiny-perl
```

Verify:
```bash
perl -e "use YAML::Tiny; print 'OK\n'"
```
Expected: `OK`

- [ ] **Step 2: Create `data/sitegen.yaml`**

```yaml
site_url: https://hklug.org
site_name: Hong Kong Linux User Group - 香港Linux用家協會(HKLUG)
site_description: Community news and events for Linux users in Hong Kong.
```

- [ ] **Step 3: Create `lib/Sitegen/` directory**

```bash
mkdir -p lib/Sitegen
```

- [ ] **Step 4: Create `.gitignore`**

```
data/.sitegen-cache.json
site/
```

- [ ] **Step 5: Commit**

```bash
git add data/sitegen.yaml .gitignore lib/
git commit -m "chore: add sitegen.yaml config, .gitignore, lib/ directory"
```

---

## Task 2: `lib/Sitegen/DataLoader.pm` — post parsing with Tags: support

**Files:**
- Create: `lib/Sitegen/DataLoader.pm`
- Create: `t/DataLoader.t`

- [ ] **Step 1: Write the failing tests**

Create `t/DataLoader.t`:

```perl
#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 10;
use File::Temp qw(tempdir);
use lib 'lib';

use_ok('Sitegen::DataLoader', qw(load_data load_announce));

my $tmpdir = tempdir(CLEANUP => 1);

# Helper: write a temp .txt file
sub write_txt {
    my ($dir, $name, $content) = @_;
    open(my $fh, '>', "$dir/$name") or die $!;
    print $fh $content;
    close $fh;
    return "$dir/$name";
}

# Test 1: basic fields parsed
my $f = write_txt($tmpdir, 'test1.txt', <<'END');
Date: 2024-01-15 18:00
Author: Wan Leung Wong
Title: Test Post
Content:
Hello **world**.
END
my $post = load_data($f);
is($post->{date},   '2024-01-15 18:00', 'date parsed');
is($post->{author}, 'Wan Leung Wong',   'author parsed');
is($post->{title},  'Test Post',        'title parsed');
like($post->{content}, qr/<strong>world<\/strong>|<b>world<\/b>/, 'content markdown rendered');

# Test 2: no Tags: line → empty arrayref
is(ref($post->{tags}), 'ARRAY', 'tags is arrayref');
is(scalar @{$post->{tags}}, 0, 'no tags = empty array');

# Test 3: Tags: line parsed and lowercased
my $f2 = write_txt($tmpdir, 'test2.txt', <<'END');
Date: 2024-02-01 10:00
Author: Bot
Title: Tagged Post
Tags: Linux, Open-Source, EVENT
Content:
Body.
END
my $post2 = load_data($f2);
is_deeply($post2->{tags}, ['linux', 'open-source', 'event'], 'tags lowercased and trimmed');

# Test 4: load_announce returns most recent file
my $topdir = "$tmpdir/top";
mkdir $topdir;
write_txt($topdir, '001.txt', "Date: 2024-01-01\nAuthor: A\nTitle: Old\nContent:\nOld.");
write_txt($topdir, '002.txt', "Date: 2024-02-01\nAuthor: B\nTitle: New\nContent:\nNew.");
my $announce = load_announce($topdir);
is($announce->{title}, 'New', 'load_announce returns most recent file');

# Test 5: comment lines skipped
my $f3 = write_txt($tmpdir, 'test3.txt', <<'END');
// this is a comment
Date: 2024-03-01 09:00
Author: Bot
Title: With Comment
Content:
Body.
END
my $post3 = load_data($f3);
is($post3->{date}, '2024-03-01 09:00', 'comment lines skipped');
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /path/to/hklug-sitegen
prove -l t/DataLoader.t
```

Expected: `Can't locate Sitegen/DataLoader.pm`

- [ ] **Step 3: Create `lib/Sitegen/DataLoader.pm`**

```perl
package Sitegen::DataLoader;

use strict;
use warnings;
use Exporter 'import';
use Text::Markdown::Discount qw(markdown);

our @EXPORT_OK = qw(load_data load_announce);

sub load_data {
    my ($filename) = @_;
    my %post;
    my $iscontent = 0;

    open(my $fh, '<', $filename) or die "Cannot open $filename: $!";
    while (my $line = <$fh>) {
        next if $line =~ m|^//|;
        if ($iscontent == 0) {
            chomp $line;
            if    ($line =~ m/^Date:\s*(.+)$/)   { $post{date}   = $1 }
            elsif ($line =~ m/^Author:\s*(.+)$/)  { $post{author} = $1 }
            elsif ($line =~ m/^Title:\s*(.+)$/)   { $post{title}  = $1 }
            elsif ($line =~ m/^Tags:\s*(.*)$/) {
                my $raw = $1;
                $post{tags} = [
                    map  { my $t = $_; $t =~ s/^\s+|\s+$//g; lc $t }
                    grep { /\S/ }
                    split(/,/, $raw)
                ];
            }
            elsif ($line =~ m/^Content:(.*)$/) {
                $post{content} = $1;
                $iscontent = 1;
            }
        } else {
            $post{content} .= $line;
        }
    }
    close $fh;

    $post{tags}    //= [];
    $post{content}   = markdown($post{content} // '');
    return \%post;
}

sub load_announce {
    my ($top_dir) = @_;
    my @filelist;
    opendir(my $dh, $top_dir) or die "Cannot open $top_dir: $!";
    while (my $file = readdir($dh)) {
        push @filelist, $file if $file =~ m/\.txt$/;
    }
    closedir($dh);
    my @sortlist = sort @filelist;
    my $filename = pop @sortlist;
    return load_data("$top_dir/$filename");
}

1;
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
prove -l t/DataLoader.t
```

Expected: `All tests successful.`

- [ ] **Step 5: Commit**

```bash
git add lib/Sitegen/DataLoader.pm t/DataLoader.t
git commit -m "feat: add Sitegen::DataLoader with Tags: parsing"
```

---

## Task 3: `lib/Sitegen/Cache.pm` — SHA-256 incremental cache

**Files:**
- Create: `lib/Sitegen/Cache.pm`
- Create: `t/Cache.t`

- [ ] **Step 1: Write the failing tests**

Create `t/Cache.t`:

```perl
#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 9;
use File::Temp qw(tempdir tempfile);
use lib 'lib';

use_ok('Sitegen::Cache', qw(load_cache save_cache is_fresh update_cache));

my $tmpdir = tempdir(CLEANUP => 1);

# Test 1: load_cache on missing file returns empty hashref
my $cache = load_cache("$tmpdir/nonexistent.json");
is(ref($cache), 'HASH', 'missing cache returns hashref');
is(scalar keys %$cache, 0, 'missing cache is empty');

# Test 2: save_cache then load_cache round-trips
my $data = { 'foo.txt' => 'abc123' };
save_cache("$tmpdir/cache.json", $data);
my $loaded = load_cache("$tmpdir/cache.json");
is($loaded->{'foo.txt'}, 'abc123', 'save and load round-trip');

# Test 3: corrupt cache returns empty hashref with warning
open(my $fh, '>', "$tmpdir/bad.json") or die $!;
print $fh "NOT JSON {{{{";
close $fh;
my $bad = load_cache("$tmpdir/bad.json");
is(ref($bad), 'HASH', 'corrupt cache returns hashref');
is(scalar keys %$bad, 0, 'corrupt cache is empty');

# Test 4: update_cache + is_fresh
my $srcfile = "$tmpdir/article.txt";
open($fh, '>', $srcfile) or die $!;
print $fh "Date: 2024-01-01\nContent:\nHello.";
close $fh;

my $outfile = "$tmpdir/article.html";
open($fh, '>', $outfile) or die $!; print $fh "<p>Hello.</p>"; close $fh;

my $c = {};
is(is_fresh($c, $srcfile, $outfile), 0, 'not fresh before update_cache');

update_cache($c, $srcfile);
is(is_fresh($c, $srcfile, $outfile), 1, 'fresh after update_cache');

# Test 5: is_fresh returns 0 when output file missing
unlink $outfile;
is(is_fresh($c, $srcfile, $outfile), 0, 'not fresh when output file missing');
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
prove -l t/Cache.t
```

Expected: `Can't locate Sitegen/Cache.pm`

- [ ] **Step 3: Create `lib/Sitegen/Cache.pm`**

```perl
package Sitegen::Cache;

use strict;
use warnings;
use Exporter 'import';
use Digest::SHA qw(sha256_hex);
use JSON::PP;

our @EXPORT_OK = qw(load_cache save_cache is_fresh update_cache);

sub load_cache {
    my ($cache_file) = @_;
    return {} unless -f $cache_file;
    open(my $fh, '<', $cache_file) or do {
        warn "Cannot read cache file $cache_file: $!\n";
        return {};
    };
    my $json = do { local $/; <$fh> };
    close $fh;
    my $data = eval { decode_json($json) };
    if ($@) {
        warn "Corrupt cache file, starting fresh: $@\n";
        return {};
    }
    return $data;
}

sub save_cache {
    my ($cache_file, $cache) = @_;
    open(my $fh, '>', $cache_file) or die "Cannot write cache $cache_file: $!";
    print $fh JSON::PP->new->pretty->encode($cache);
    close $fh;
}

sub _file_sha256 {
    my ($file) = @_;
    open(my $fh, '<', $file) or die "Cannot read $file: $!";
    my $content = do { local $/; <$fh> };
    close $fh;
    return sha256_hex($content);
}

sub _basename { (split m{/}, $_[0])[-1] }

sub is_fresh {
    my ($cache, $src_file, $out_file) = @_;
    return 0 unless -f $out_file;
    my $key = _basename($src_file);
    return 0 unless exists $cache->{$key};
    return $cache->{$key} eq _file_sha256($src_file) ? 1 : 0;
}

sub update_cache {
    my ($cache, $src_file) = @_;
    $cache->{_basename($src_file)} = _file_sha256($src_file);
}

1;
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
prove -l t/Cache.t
```

Expected: `All tests successful.`

- [ ] **Step 5: Commit**

```bash
git add lib/Sitegen/Cache.pm t/Cache.t
git commit -m "feat: add Sitegen::Cache with SHA-256 incremental skip"
```

---

## Task 4: `lib/Sitegen/SEO.pm` — og: meta hashref

**Files:**
- Create: `lib/Sitegen/SEO.pm`
- Create: `t/SEO.t`

- [ ] **Step 1: Write the failing tests**

Create `t/SEO.t`:

```perl
#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 8;
use lib 'lib';

use_ok('Sitegen::SEO', qw(seo_meta));

my $config = {
    site_url         => 'https://hklug.org',
    site_name        => 'HKLUG',
    site_description => 'Linux users in HK.',
};

# Test 1: og_url constructed correctly
my $post = { title => 'My Post', content => '<p>Hello world.</p>' };
my $seo  = seo_meta($post, $config, '/archive/20240101-120000.html');
is($seo->{og_url}, 'https://hklug.org/archive/20240101-120000.html', 'og_url correct');

# Test 2: og_title from post title
is($seo->{og_title}, 'My Post', 'og_title from post title');

# Test 3: HTML stripped from description
is($seo->{description}, 'Hello world.', 'HTML stripped from description');

# Test 4: description same as og_description
is($seo->{description}, $seo->{og_description}, 'description == og_description');

# Test 5: long content truncated to 160 chars
my $long = 'A' x 200;
my $seo2 = seo_meta({ title => 'T', content => $long }, $config, '/');
is(length($seo2->{description}), 160, 'description truncated to 160 chars');

# Test 6: empty content falls back to site_description
my $seo3 = seo_meta({ title => 'T', content => '' }, $config, '/');
is($seo3->{description}, 'Linux users in HK.', 'empty content uses site_description');

# Test 7: trailing slash removed from site_url
my $cfg2 = { %$config, site_url => 'https://hklug.org/' };
my $seo4 = seo_meta($post, $cfg2, '/archive/x.html');
is($seo4->{og_url}, 'https://hklug.org/archive/x.html', 'trailing slash stripped from site_url');
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
prove -l t/SEO.t
```

Expected: `Can't locate Sitegen/SEO.pm`

- [ ] **Step 3: Create `lib/Sitegen/SEO.pm`**

```perl
package Sitegen::SEO;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(seo_meta);

sub seo_meta {
    my ($post, $config, $url_path) = @_;

    my $content = $post->{content} // '';
    (my $plain = $content) =~ s/<[^>]+>//g;
    $plain =~ s/\s+/ /g;
    $plain =~ s/^\s+|\s+$//g;

    my $description = length($plain) > 0
        ? substr($plain, 0, 160)
        : ($config->{site_description} // '');

    (my $base = $config->{site_url} // '') =~ s|/$||;

    return {
        description    => $description,
        og_title       => $post->{title} // $config->{site_name} // '',
        og_description => $description,
        og_url         => "$base$url_path",
    };
}

1;
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
prove -l t/SEO.t
```

Expected: `All tests successful.`

- [ ] **Step 5: Commit**

```bash
git add lib/Sitegen/SEO.pm t/SEO.t
git commit -m "feat: add Sitegen::SEO for og: meta generation"
```

---

## Task 5: `lib/Sitegen/Tags.pm` — tag collection and page generation

**Files:**
- Create: `lib/Sitegen/Tags.pm`
- Create: `t/Tags.t`

Note: `gen_tag_pages()` uses Template Toolkit, so it is tested by verifying output file existence and content in the integration test (Task 7). Unit tests here cover `collect_tags()` and `tag_slug()` only.

- [ ] **Step 1: Write the failing tests**

Create `t/Tags.t`:

```perl
#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 8;
use lib 'lib';

use_ok('Sitegen::Tags', qw(collect_tags tag_slug));

# Test 1: tag_slug lowercases and replaces spaces
is(tag_slug('Open Source'), 'open-source', 'spaces become hyphens');
is(tag_slug('Linux'),       'linux',       'already lowercase unchanged');
is(tag_slug('AI & ML'),    'ai-&-ml',     'non-space chars preserved');

# Test 2: collect_tags builds tag->posts map
my @posts = (
    { title => 'Post A', tags => ['linux', 'event'] },
    { title => 'Post B', tags => ['linux'] },
    { title => 'Post C', tags => ['event', 'open-source'] },
    { title => 'Post D', tags => [] },
);
my $tags = collect_tags(@posts);
is(ref($tags), 'HASH', 'collect_tags returns hashref');
is(scalar @{$tags->{linux}}, 2, 'linux has 2 posts');
is(scalar @{$tags->{event}}, 2, 'event has 2 posts');
is(scalar @{$tags->{'open-source'}}, 1, 'open-source has 1 post');
ok(!exists $tags->{''}, 'empty tags not included');
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
prove -l t/Tags.t
```

Expected: `Can't locate Sitegen/Tags.pm`

- [ ] **Step 3: Create `lib/Sitegen/Tags.pm`**

```perl
package Sitegen::Tags;

use strict;
use warnings;
use Exporter 'import';
use File::Path qw(make_path);

our @EXPORT_OK = qw(collect_tags tag_slug gen_tag_pages);

sub tag_slug {
    my ($tag) = @_;
    (my $slug = lc $tag) =~ s/\s+/-/g;
    return $slug;
}

sub collect_tags {
    my (@posts) = @_;
    my %tags;
    for my $post (@posts) {
        for my $tag (@{$post->{tags} // []}) {
            next unless defined $tag && length $tag;
            push @{$tags{$tag}}, $post;
        }
    }
    return \%tags;
}

sub gen_tag_pages {
    my ($tt, $tags, $site_folder, $config) = @_;
    my $tags_folder = "$site_folder/tags";
    make_path($tags_folder) unless -d $tags_folder;

    my @tag_list = map {
        { name => $_, slug => tag_slug($_), count => scalar @{$tags->{$_}} }
    } sort keys %$tags;

    $tt->process('tag_list.html',
        { title => $config->{site_name} . ' > Tags', tag_list => \@tag_list },
        "$tags_folder/index.html"
    ) || die $tt->error();

    for my $tag (keys %$tags) {
        my $slug    = tag_slug($tag);
        my $tag_dir = "$tags_folder/$slug";
        make_path($tag_dir) unless -d $tag_dir;
        $tt->process('tag_page.html',
            {
                title => $config->{site_name} . " > Tag: $tag",
                tag   => $tag,
                slug  => $slug,
                posts => $tags->{$tag},
            },
            "$tag_dir/index.html"
        ) || die $tt->error();
    }
}

1;
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
prove -l t/Tags.t
```

Expected: `All tests successful.`

- [ ] **Step 5: Commit**

```bash
git add lib/Sitegen/Tags.pm t/Tags.t
git commit -m "feat: add Sitegen::Tags for tag collection and page generation"
```

---

## Task 6: Template updates — SEO block, tag display, new tag templates

**Files:**
- Modify: `template/header.html` (lines 9, 12-13)
- Modify: `template/post.html` (after line 13)
- Modify: `template/archive.html` (uses post.html via PROCESS — no change needed; post.html handles it)
- Create: `template/tag_list.html`
- Create: `template/tag_page.html`

- [ ] **Step 1: Update `template/header.html`**

Replace lines 9–13 (static title + closing `</head>` area):

**Before (line 9):**
```html
    <title>Hong Kong Linux User Group (HKLUG)</title>
    <link rel="stylesheet" href="/css/foundation.css" />
    <link rel="stylesheet" href="/css/main.css" />
    <script src="/js/vendor/modernizr.js"></script>
  </head>
```

**After:**
```html
    <title>[% title %]</title>
    [% IF seo %]
    <meta name="description" content="[% seo.description | html %]" />
    <meta property="og:title" content="[% seo.og_title | html %]" />
    <meta property="og:description" content="[% seo.og_description | html %]" />
    <meta property="og:url" content="[% seo.og_url %]" />
    <link rel="canonical" href="[% seo.og_url %]" />
    [% END %]
    <link rel="stylesheet" href="/css/foundation.css" />
    <link rel="stylesheet" href="/css/main.css" />
    <script src="/js/vendor/modernizr.js"></script>
  </head>
```

- [ ] **Step 2: Update `template/post.html`** — add tag links after the `<hr />`

**Before (line 13):**
```html
      </article>
      <hr />

  <!-- post end -->
```

**After:**
```html
      [% IF post.tags.size %]
      <p class="post-tags">Tags:
        [% FOREACH tag = post.tags %]<a href="/tags/[% tag | uri %]/">[% tag | html %]</a>[% UNLESS loop.last %], [% END %][% END %]
      </p>
      [% END %]
      </article>
      <hr />

  <!-- post end -->
```

- [ ] **Step 3: Create `template/tag_list.html`**

```html
[% WRAPPER frame.html %]
  <h2>All Tags</h2>
  [% IF tag_list.size %]
  <ul class="tag-list">
    [% FOREACH t = tag_list %]
    <li><a href="/tags/[% t.slug | uri %]/">[% t.name | html %]</a> ([% t.count %])</li>
    [% END %]
  </ul>
  [% ELSE %]
  <p>No tags yet.</p>
  [% END %]
[% END %]
```

- [ ] **Step 4: Create `template/tag_page.html`**

```html
[% WRAPPER frame.html %]
  <h2>Posts tagged: [% tag | html %]</h2>
  [% FOREACH post = posts %]
    [% PROCESS post.html %]
  [% END %]
  <p><a href="/tags/">← All Tags</a></p>
[% END %]
```

- [ ] **Step 5: Commit**

```bash
git add template/header.html template/post.html template/tag_list.html template/tag_page.html
git commit -m "feat: update templates for SEO meta block and tag display"
```

---

## Task 7: Refactor `bin/sitegen.pl` — use all modules, --force, incremental, tags

**Files:**
- Modify: `bin/sitegen.pl` (full rewrite)

- [ ] **Step 1: Replace the full content of `bin/sitegen.pl`**

```perl
#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Template;
use YAML::Tiny;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Sitegen::DataLoader qw(load_data load_announce);
use Sitegen::Cache      qw(load_cache save_cache is_fresh update_cache);
use Sitegen::SEO        qw(seo_meta);
use Sitegen::Tags       qw(collect_tags tag_slug gen_tag_pages);

my $force = 0;
GetOptions('force' => \$force);

our $base_dir       = "$Bin/..";
our $data_dir       = "$base_dir/data";
our $top_dir        = "$data_dir/top";
our $news_dir       = "$data_dir/news";
our $site_folder    = "$base_dir/site";
our $archive_folder = "$site_folder/archive";
our $cache_file     = "$data_dir/.sitegen-cache.json";
our $config_file    = "$data_dir/sitegen.yaml";

sub load_config {
    die "Missing config file: $config_file\n" unless -f $config_file;
    my $yaml = YAML::Tiny->read($config_file)
        or die "Cannot parse $config_file: " . YAML::Tiny->errstr . "\n";
    return $yaml->[0];
}

sub main {
    my $config = load_config();
    my $cache  = $force ? {} : load_cache($cache_file);

    my $tt = Template->new({
        INCLUDE_PATH => "$base_dir/template",
        INTERPOLATE  => 0,
    }) || die "$Template::ERROR\n";

    gen_home($tt, $config);
    gen_pages($tt, $config);
    my $all_posts = gen_archive($tt, $config, $cache);
    gen_tags($tt, $config, $all_posts);

    save_cache($cache_file, $cache);
}

sub gen_home {
    my ($tt, $config) = @_;
    my @filelist;
    opendir(my $dh, $news_dir) or die $!;
    while (my $file = readdir($dh)) { push @filelist, $file if $file =~ m/\.txt$/ }
    closedir($dh);
    my @sortlist = sort @filelist;
    my $total    = scalar @sortlist;

    my @news_posts;
    for my $i (1..5) {
        last if ($total - $i < 0);
        push @news_posts, load_data("$news_dir/$sortlist[$total - $i]");
    }

    my $announce = load_announce($top_dir);
    my $seo_post = { title => $config->{site_name} . ' > News', content => '' };
    $tt->process('news.html', {
        title    => $config->{site_name} . ' > News',
        news     => \@news_posts,
        announce => $announce,
        seo      => seo_meta($seo_post, $config, '/'),
    }, "$site_folder/index.html") || die $tt->error();
}

sub gen_pages {
    my ($tt, $config) = @_;
    my @filelist;
    opendir(my $dh, $data_dir) or die $!;
    while (my $file = readdir($dh)) { push @filelist, $file if $file =~ m/\.txt$/ }
    closedir($dh);

    for my $file (@filelist) {
        my $post     = load_data("$data_dir/$file");
        my $announce = load_announce($top_dir);
        (my $newfile = $file) =~ s/\.txt$/.html/;
        $tt->process('page.html', {
            title    => $config->{site_name} . ' > ' . $post->{title},
            post     => $post,
            announce => $announce,
            seo      => seo_meta($post, $config, "/$newfile"),
        }, "$site_folder/$newfile") || die $tt->error();
    }
}

# Returns arrayref of all posts (newest-first) for use by gen_tags
sub gen_archive {
    my ($tt, $config, $cache) = @_;
    my @filelist;
    opendir(my $dh, $news_dir) or die $!;
    while (my $file = readdir($dh)) { push @filelist, $file if $file =~ m/\.txt$/ }
    closedir($dh);

    my @sortlist = sort @filelist;
    my $total    = scalar @sortlist;
    my (@allnews, $count);
    $count = 0;

    for my $file (@sortlist) {
        (my $newfile = $file) =~ s/\.txt$/.html/;
        my $srcfile = "$news_dir/$file";
        my $outfile = "$archive_folder/$newfile";

        my $post = load_data($srcfile);
        $post->{url} = "/archive/$newfile";
        push @allnews, $post;

        if (!$force && is_fresh($cache, $srcfile, $outfile)) {
            print "SKIP $file\n";
            $count++;
            next;
        }

        my $preindex  = ($count + 1 >= $total) ? $count     : $count + 1;
        my $nextindex = ($count - 1 < 0)       ? 0          : $count - 1;

        (my $prevfile  = $sortlist[$preindex])  =~ s/\.txt$/.html/;
        (my $nextfile2 = $sortlist[$nextindex]) =~ s/\.txt$/.html/;
        (my $startfile = $sortlist[$total - 1]) =~ s/\.txt$/.html/;
        (my $endfile   = $sortlist[0])          =~ s/\.txt$/.html/;

        $tt->process('archive.html', {
            title => $config->{site_name} . ' > Archive > ' . $post->{title},
            post  => $post,
            url   => {
                front     => "/archive/$startfile",
                end       => "/archive/$endfile",
                prev      => "/archive/$prevfile",
                next      => "/archive/$nextfile2",
                home      => "/archive/",
                hometitle => "Archive",
            },
            seo => seo_meta($post, $config, "/archive/$newfile"),
        }, $outfile) || die $tt->error();

        update_cache($cache, $srcfile);
        $count++;
    }

    # Archive list — always regenerate
    my @reversed  = reverse @allnews;
    my $announce  = load_announce($top_dir);
    my $seo_post  = { title => $config->{site_name} . ' > Archive', content => '' };
    $tt->process('archive_list.html', {
        title     => $config->{site_name} . ' > Archive',
        pagetitle => 'Archives',
        news      => \@reversed,
        announce  => $announce,
        seo       => seo_meta($seo_post, $config, '/archive/'),
    }, "$archive_folder/index.html") || die $tt->error();

    return [reverse @allnews];  # newest-first for tags
}

sub gen_tags {
    my ($tt, $config, $all_posts) = @_;
    my $tags = collect_tags(@$all_posts);
    gen_tag_pages($tt, $tags, $site_folder, $config);
}

main();
```

- [ ] **Step 2: Run all unit tests to verify nothing broken**

```bash
prove -l t/
```

Expected: `All tests successful.` (DataLoader, Cache, SEO, Tags)

- [ ] **Step 3: Commit**

```bash
git add bin/sitegen.pl
git commit -m "refactor: rewrite sitegen.pl using Sitegen:: modules with --force and incremental cache"
```

---

## Task 8: End-to-end smoke test

No new files — this task verifies the full system works.

- [ ] **Step 1: Run sitegen for the first time (full build)**

```bash
cd /path/to/hklug-sitegen
perl bin/sitegen.pl
```

Expected: No `SKIP` lines. `site/index.html`, `site/archive/*.html`, `site/tags/index.html` all created. `data/.sitegen-cache.json` written.

- [ ] **Step 2: Run sitegen again (incremental — all unchanged)**

```bash
perl bin/sitegen.pl 2>&1 | grep -c "^SKIP"
```

Expected: output is `358` (or however many `.txt` files exist) — all archive pages skipped.

- [ ] **Step 3: Verify SEO tags in a generated archive page**

```bash
grep -m1 "og:title" site/archive/*.html
```

Expected: `<meta property="og:title" content="..." />`

- [ ] **Step 4: Add a tag to a news file and verify tag page**

```bash
# Edit the most recent news file to add a Tags: line
RECENT=$(ls data/news/*.txt | sort | tail -1)
# Insert "Tags: linux, test-tag" before "Content:" line
sed -i '/^Content:/i Tags: linux, test-tag' "$RECENT"
perl bin/sitegen.pl
```

Expected: `site/tags/linux/index.html` and `site/tags/test-tag/index.html` both exist. `site/tags/index.html` lists both tags.

- [ ] **Step 5: Verify `--force` regenerates everything**

```bash
perl bin/sitegen.pl --force 2>&1 | grep -c "^SKIP"
```

Expected: `0` — no pages skipped.

- [ ] **Step 6: Run all unit tests**

```bash
prove -l t/
```

Expected: `All tests successful.`

- [ ] **Step 7: Push to origin**

```bash
git push origin master
```

---

## Post-implementation checklist

- [ ] `data/.sitegen-cache.json` is in `.gitignore` and not committed
- [ ] `site/` output is gitignored (or already was)
- [ ] All 4 unit test files pass with `prove -l t/`
- [ ] `site/tags/index.html` lists all tags
- [ ] A generated archive page contains `<meta property="og:title">`
- [ ] Second run with no changes skips all archive pages
