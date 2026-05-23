# Privacy Policy Page — Design Spec

**Project:** hklug-sitegen  
**Date:** 2026-05-23  
**Status:** Approved

---

## Overview

Add a bilingual (English + Traditional Chinese HK) privacy policy page to the HKLUG static site at `https://hklug.org/privacy.html`. The page satisfies Meta's requirement that any Facebook app submission must link to a publicly accessible privacy policy. The app (`ai-it-press`) only posts articles to the HKLUG Facebook Page — it does not collect, store, or process any personal data from users.

---

## Scope

Two deliverables:

1. `data/privacy.txt` — new static page source, picked up automatically by `sitegen.pl`'s `gen_pages()` which renders all `*.txt` in `data/` to `site/*.html`
2. `template/footer.html` — add a "Privacy Policy" link in the footer, consistent with where such links conventionally appear

No changes to `sitegen.pl`, `sitegen.yaml`, or any other templates.

---

## Content Structure (`data/privacy.txt`)

Standard `.txt` frontmatter followed by HTML content body:

```
Date: 2026-05-23
Author: Hong Kong Linux User Group
Title: Privacy Policy - 私隱政策
Content:
<bilingual HTML content>
```

### Policy sections (bilingual, English then Traditional Chinese HK)

| # | English heading | Chinese heading |
|---|----------------|-----------------|
| 1 | Introduction | 簡介 |
| 2 | Data We Collect | 我們收集的資料 |
| 3 | Facebook Platform | Facebook 平台 |
| 4 | How We Use Your Information | 資料使用方式 |
| 5 | Data Sharing | 資料分享 |
| 6 | Contact Us | 聯絡我們 |
| 7 | Effective Date | 生效日期 |

**Key points per section:**

- **Introduction / 簡介**: Identifies the operator as Hong Kong Linux User Group (HKLUG), registered Hong Kong society No. 21299. States the app's sole purpose: automated posting of IT news articles to the HKLUG Facebook Page via the ai-it-press pipeline.
- **Data We Collect / 我們收集的資料**: No personal data is collected, stored, or processed. The app does not require user login, does not read user profiles, and does not use cookies or tracking.
- **Facebook Platform / Facebook 平台**: Users who interact with the HKLUG Facebook Page are subject to Meta's own Privacy Policy (link: https://www.facebook.com/privacy/policy/). HKLUG has no control over Meta's data practices.
- **How We Use Your Information / 資料使用方式**: Not applicable — no information is collected.
- **Data Sharing / 資料分享**: No data is shared with third parties because no data is collected.
- **Contact Us / 聯絡我們**: For any privacy-related questions, contact infohklug@gmail.com.
- **Effective Date / 生效日期**: 2026-05-23.

---

## Footer Link (`template/footer.html`)

Add a "Privacy Policy | 私隱政策" link inside the existing `<footer>` block, after the CC licence paragraph and before the closing `</footer>` tag. Keep it visually subtle — same small text style as the existing copyright line.

```html
<p><a href="/privacy.html">Privacy Policy | 私隱政策</a></p>
```

---

## Generated Output

Running `perl bin/sitegen.pl` after these changes produces:

- `site/privacy.html` — full page with header, sidebar, footer (via `page.html` → `frame.html`)
- All existing pages regenerated with the new footer link

The privacy policy URL to register with the Facebook app: `https://hklug.org/privacy.html`

---

## Out of Scope

- Menu bar link (footer is the conventional location for privacy policies)
- Separate cookie policy (no cookies used by the app)
- GDPR Data Protection Officer designation (not required for no-data app)
- Any backend or API changes

---

## Success Criteria

- [ ] `site/privacy.html` renders correctly after `perl bin/sitegen.pl`
- [ ] Page is bilingual (English + Traditional Chinese HK)
- [ ] All seven sections are present
- [ ] Footer link appears on all generated pages
- [ ] URL `https://hklug.org/privacy.html` is publicly accessible (after site deploy)
- [ ] Facebook app review accepts the URL as a valid privacy policy
