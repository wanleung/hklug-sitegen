# Privacy Policy Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a bilingual (English + Traditional Chinese HK) privacy policy page to hklug.org for the HKLUG Facebook app submission, plus a footer link on every generated page.

**Architecture:** Add `data/privacy.txt` (picked up automatically by `sitegen.pl`'s `gen_pages()`) and add one `<p>` link to `template/footer.html`. No code changes to the generator itself — the existing pattern handles everything.

**Tech Stack:** Perl Template::Toolkit static site generator, `prove` for tests, HTML content in `.txt` data files.

---

## File Map

| Action | Path | Responsibility |
|--------|------|---------------|
| Create | `data/privacy.txt` | Privacy policy content (bilingual HTML) |
| Modify | `template/footer.html` | Add privacy policy link to footer |
| Create | `t/Privacy.t` | Verify generated `site/privacy.html` exists and contains required content |

---

## Task 1: Write the failing integration test

**Files:**
- Create: `t/Privacy.t`

- [ ] **Step 1: Create the test file**

```perl
#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use File::Spec;
use lib 'lib';

# Run sitegen to produce site/ output
# We test against the actual generated files in site/

plan tests => 8;

my $privacy_html = 'site/privacy.html';

SKIP: {
    skip 'site/privacy.html not generated yet — run perl bin/sitegen.pl first', 8
        unless -f $privacy_html;

    open(my $fh, '<:encoding(UTF-8)', $privacy_html) or die "Cannot open $privacy_html: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    ok($content =~ /Privacy Policy/, 'privacy.html contains English title');
    ok($content =~ /私隱政策/, 'privacy.html contains Chinese title');
    ok($content =~ /Hong Kong Linux User Group/, 'privacy.html mentions HKLUG');
    ok($content =~ /no personal data/i || $content =~ /不收集.*個人資料|個人資料.*不收集/,
        'privacy.html states no personal data collected');
    ok($content =~ /info\@linux\.org\.hk/, 'privacy.html contains contact email');
    ok($content =~ /facebook\.com\/privacy/, 'privacy.html links to Meta privacy policy');
    ok($content =~ /2026-05-23/, 'privacy.html contains effective date');

    # Check footer link appears on index.html too
    open(my $idx, '<:encoding(UTF-8)', 'site/index.html') or die "Cannot open site/index.html: $!";
    my $index = do { local $/; <$idx> };
    close $idx;
    ok($index =~ /\/privacy\.html/, 'index.html footer contains privacy policy link');
}
```

- [ ] **Step 2: Run the test — confirm it skips (no privacy.html yet)**

```bash
cd /home/wanleung/Projects/hklug-sitegen
prove t/Privacy.t -v
```

Expected output:
```
t/Privacy.t .. # SKIP site/privacy.html not generated yet — run perl bin/sitegen.pl first
ok 1 # skip ...
...
All tests successful.
```

- [ ] **Step 3: Commit the test**

```bash
git add t/Privacy.t
git commit -m "test: add Privacy.t integration test for privacy policy page"
```

---

## Task 2: Create `data/privacy.txt`

**Files:**
- Create: `data/privacy.txt`

- [ ] **Step 1: Create the file with bilingual content**

```
Date: 2026-05-23
Author: Hong Kong Linux User Group
Title: Privacy Policy - 私隱政策
Content:
<h2>Privacy Policy</h2>

<h3>1. Introduction</h3>
<p>
This privacy policy applies to the Facebook application operated by the
<strong>Hong Kong Linux User Group (HKLUG)</strong>, a non-profit organisation
registered in Hong Kong under the Societies Ordinance (Society No. 21299).
The application's sole purpose is to automatically post IT news articles to
the HKLUG Facebook Page via the <em>ai-it-press</em> pipeline.
</p>

<h3>1. 簡介</h3>
<p>
本私隱政策適用於由<strong>香港Linux用家協會（HKLUG）</strong>營運的
Facebook應用程式。本會為香港非牟利組織，依據《社團條例》註冊，
社團編號為21299。該應用程式的唯一用途，是透過 <em>ai-it-press</em>
資訊管道，自動將IT新聞文章發佈至HKLUG Facebook專頁。
</p>

<hr />

<h3>2. Data We Collect</h3>
<p>
We do <strong>not</strong> collect, store, or process any personal data from users.
The application does not require user login, does not read user profiles,
does not use cookies, and does not employ any tracking technologies.
</p>

<h3>2. 我們收集的資料</h3>
<p>
我們<strong>不會</strong>收集、儲存或處理任何用戶的個人資料。
本應用程式無需用戶登入，不讀取用戶資料，不使用Cookie，
亦不採用任何追蹤技術。
</p>

<hr />

<h3>3. Facebook Platform</h3>
<p>
Users who visit or interact with the HKLUG Facebook Page are subject to
Meta's own privacy practices. Please refer to
<a href="https://www.facebook.com/privacy/policy/">Meta's Privacy Policy</a>
for details. HKLUG has no control over Meta's data collection or processing.
</p>

<h3>3. Facebook 平台</h3>
<p>
瀏覽或與HKLUG Facebook專頁互動的用戶，須受Meta本身私隱政策約束。
詳情請參閱<a href="https://www.facebook.com/privacy/policy/">Meta私隱政策</a>。
HKLUG對Meta的資料收集或處理方式概不負責。
</p>

<hr />

<h3>4. How We Use Your Information</h3>
<p>Not applicable — no user information is collected by this application.</p>

<h3>4. 資料使用方式</h3>
<p>不適用——本應用程式不收集任何用戶資訊。</p>

<hr />

<h3>5. Data Sharing</h3>
<p>
We do not share any personal data with third parties because no personal
data is collected.
</p>

<h3>5. 資料分享</h3>
<p>由於我們不收集個人資料，因此不會與任何第三方分享個人資料。</p>

<hr />

<h3>6. Contact Us</h3>
<p>
If you have any questions about this privacy policy, please contact us at:
<br />
<strong>Hong Kong Linux User Group</strong><br />
Email: <a href="mailto:infohklug@gmail.com">infohklug@gmail.com</a>
</p>

<h3>6. 聯絡我們</h3>
<p>
如閣下對本私隱政策有任何疑問，歡迎透過以下方式聯絡我們：<br />
<strong>香港Linux用家協會</strong><br />
電郵：<a href="mailto:infohklug@gmail.com">infohklug@gmail.com</a>
</p>

<hr />

<h3>7. Effective Date</h3>
<p>This policy is effective as of <strong>2026-05-23</strong>.</p>

<h3>7. 生效日期</h3>
<p>本政策自 <strong>2026-05-23</strong> 起生效。</p>
```

- [ ] **Step 2: Commit the data file**

```bash
git add data/privacy.txt
git commit -m "content: add bilingual privacy policy page for Facebook app"
```

---

## Task 3: Add privacy link to footer

**Files:**
- Modify: `template/footer.html`

- [ ] **Step 1: Add the privacy link to the footer**

In `template/footer.html`, find the copyright paragraph and add the privacy link immediately after it, before `</footer>`:

Replace:
```html
      <p>
      <a rel="license" href="https://creativecommons.org/licenses/by-sa/3.0/hk/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-sa/3.0/hk/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="https://creativecommons.org/licenses/by-sa/3.0/hk/">Creative Commons Attribution-ShareAlike 3.0 Hong Kong License</a>.
      <br />
      Copyright © 1997-2020 Hong Kong Linux User Group.
      </p>
      </div>
    
  </footer>
```

With:
```html
      <p>
      <a rel="license" href="https://creativecommons.org/licenses/by-sa/3.0/hk/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-sa/3.0/hk/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="https://creativecommons.org/licenses/by-sa/3.0/hk/">Creative Commons Attribution-ShareAlike 3.0 Hong Kong License</a>.
      <br />
      Copyright © 1997-2020 Hong Kong Linux User Group.
      </p>
      <p><a href="/privacy.html">Privacy Policy | 私隱政策</a></p>
      </div>
    
  </footer>
```

- [ ] **Step 2: Commit the template change**

```bash
git add template/footer.html
git commit -m "feat: add privacy policy link to site footer"
```

---

## Task 4: Generate the site and verify

**Files:**
- Run: `perl bin/sitegen.pl --force`
- Check: `site/privacy.html`

- [ ] **Step 1: Run the generator**

```bash
cd /home/wanleung/Projects/hklug-sitegen
perl bin/sitegen.pl --force
```

Expected: No errors. `site/privacy.html` appears in output.

- [ ] **Step 2: Run the full test suite including the new Privacy.t**

```bash
prove t/ -v
```

Expected:
```
t/Cache.t ....... ok
t/DataLoader.t .. ok
t/SEO.t ......... ok
t/Tags.t ........ ok
t/Privacy.t ..... ok
All tests successful.
Files=5, Tests=64, ...
Result: PASS
```

- [ ] **Step 3: Spot-check the generated page**

```bash
grep -c "Privacy Policy" site/privacy.html
grep -c "私隱政策" site/privacy.html
grep -c "privacy.html" site/index.html
```

Expected: all return `1` or higher.

- [ ] **Step 4: Commit generated site if it is tracked, otherwise done**

```bash
git status site/
```

If `site/` is tracked by git:
```bash
git add site/privacy.html site/index.html site/about.html site/contact.html site/archive/
git commit -m "build: regenerate site with privacy policy page and footer link"
```

If `site/` is in `.gitignore`, skip this step.

---

## Post-Implementation

- Register `https://hklug.org/privacy.html` as the Privacy Policy URL in the Facebook app settings under **Settings → Basic → Privacy Policy URL**.
- Deploy the updated `site/` to the web server (same process as any other site update).
