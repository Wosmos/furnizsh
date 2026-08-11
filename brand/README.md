# Brand source files

Kept out of `site/` so it isn't served by GitHub Pages.

| File | What |
|---|---|
| `mascot-original.png` | the mascot as generated — 1536×1024, transparent, ungraded |

Everything in `site/assets/` is derived from this file.

## What gets generated

| Output | From |
|---|---|
| `site/assets/img/mascot.png` | the whole fish, 800px, optimised — the page hero |
| `site/assets/img/og-image.png` | 1200×630 social card, composed with the wordmark |
| `site/assets/icons/icon-{64,192,512}.png`, `apple-touch-icon.png` | the whole fish, squared with 8% padding |
| `site/assets/icons/favicon.ico` | 16 / 32 / 48 — **32 and 48 are the artwork, 16 is `icon-16.svg`** |

## Two rules worth keeping

**Never crop the fish for an icon.** Head crops were tried and every one runs
off an edge — a cropped mascot reads as a mistake rather than a decision. The
complete fish, squared and padded, always looks intentional.

**The 16px slot needs its own drawing.** The artwork is gradient-shaded and
stops being legible below about 24px; at 16 the face collapses into a smudge.
`icon-16.svg` is a deliberately cruder drawing of the same character — head,
two big eyes, one mouth line, the lure — and occupies only the 16×16 entry
inside `favicon.ico`. Nobody can tell at that size. `icon.svg` is the fuller
vector mark, kept as its origin.

## Regenerating

```bash
brew install cairo
pip3 install cairosvg
export DYLD_FALLBACK_LIBRARY_PATH="/opt/homebrew/lib:$DYLD_FALLBACK_LIBRARY_PATH"
```

The mascot is a deep-sea anglerfish in glasses. It is **not** a reference to the
Friendly Interactive Shell — furnizsh targets zsh and PowerShell. There's an FAQ
entry about it on the install page, because someone was always going to ask.
