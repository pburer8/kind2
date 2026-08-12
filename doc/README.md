<!-- DO NOT EDIT, edit content/README.md instead -->
# Kind 2 User Documentation — Hugo + Hextra

This is the Kind 2 user documentation, migrated from Sphinx (reStructuredText)
to [Hugo](https://gohugo.io) using the [Hextra](https://github.com/imfing/hextra) theme.

## Structure

```
content/
  _index.md              # Homepage and docs root (from home.rst; cascades `type: docs`)
  techniques/            # "Techniques" toctree section
  inputs-and-outputs/    # "Inputs and Outputs" toctree section
  advanced-features/     # "Advanced Features" toctree section
  lucent-primer.md       # "Lucent Primer" page
  license.md             # "License" toctree section
  header.md              # Badges prepended to the root README.md (not part of the site)
  README.md              # This file (not part of the site)
themes/hextra/            # Hextra theme, Git submodule
hugo.yaml                  # Site configuration
```

Page ordering within each section is controlled by the `weight` field in each
page's front matter, mirroring the original Sphinx `toctree` order.

## Code blocks

Lustre examples go in ` ```lustre ` fences. Hugo's highlighter (Chroma) has no
Lustre lexer and cannot load a custom one, so these are highlighted in the
browser by `assets/js/lustre-highlight.js`; `layouts/_markup/render-codeblock-lustre.html`
emits the markup Chroma would have produced, which keeps the theme's light and
dark styles applying unchanged. The keyword lists in the script come from
`src/lustre/lustreLexer.mll` and should be updated alongside it.

Shell commands, tool output, and JSON/XML samples keep their own fence
languages (` ```bash `, ` ```text `, ` ```json `).

## Running locally

- **Hugo Extended v0.146.0+**
- **Git** (to fetch the Hextra theme, vendored as a submodule — see below)
- **curl or wget** (to fetch KaTeX/FlexSearch assets — see below; both are
  preinstalled on virtually every system already)
- **Python 3** (for PDF export only — `make` sets up a venv automatically)

## Getting the theme

The Hextra theme is **not committed to this repo** — it's a git submodule
pinned to [`v0.12.3`](https://github.com/imfing/hextra/releases), so
contributors always build against a known-good, reviewable version rather
than each pulling whatever the theme's `main` branch currently has.

Clone with the submodule in one step:

```bash
git clone --recurse-submodules <this-repo-url>
```

Or, if you already have a plain clone:

```bash
make html
```

You don't need to remember either of these yourself day-to-day — `make html`
/ `make doc` fetch the submodule automatically if it's missing.

> **Note:** `make html` or `make vendor-assets` fetches FlexSearch (search) and KaTeX (math
> rendering) using `fetch-vendor-assets.sh` the first time it runs, so it needs
> normal internet access. If you're building in a network-restricted
> environment, set `params.search.enable: false`.

## Deploying

Any static host works (GitHub Pages, Netlify, Vercel, Cloudflare Pages).
`hugo.yaml` sets no `baseURL`, so Hugo defaults to `/`, which is what
`hugo server` and the PDF build want. Hugo bakes the baseURL into every asset
and cross-page link, so set `HUGO_BASEURL` to the URL the site will actually be
served from when building for deployment:

```bash
HUGO_BASEURL=https://example.org/kind2/docs/main/user/ make html
```

The website is published from the `kind2-mc/kind2-mc.github.io` repository,
which does this for you: it publishes this documentation to
<https://kind2-mc.github.io/docs/main/user> on every push to `main`, and a copy
of each release's to `docs/<version>/user` alongside it.
