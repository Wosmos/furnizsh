# Site assets

Everything here except the two SVGs is derived from `mascot.png`, which is a
cropped and resized copy of [`brand/mascot-original.png`](../../brand/mascot-original.png).

| File | What |
|---|---|
| `mascot.png` | the mascot, used on the landing page and in the README |
| `og-image.png` | 1200×630 social card, composed from the mascot |
| `favicon.ico` | 16 / 32 / 48. **32 and 48 are the artwork; 16 is `icon-16.svg`** |
| `icon-64.png` | nav logo |
| `icon-192.png`, `icon-512.png`, `apple-touch-icon.png` | the artwork, cropped to the head |
| `icon.svg`, `icon-16.svg` | **build sources, not page assets** |

## Why two SVGs exist

The artwork is gradient-shaded and stops being legible below about 24px — at 16
the face collapses into a smudge. `icon-16.svg` is a deliberately cruder
drawing of the same character (head, two big eyes, one mouth line, the lure)
that still reads at that size, and it occupies only the 16×16 slot inside
`favicon.ico`. Nobody can tell it's a different drawing at 16 pixels.

`icon.svg` is the fuller vector mark. It isn't currently shipped to any page —
it's kept as the origin of `icon-16.svg` and as a starting point if a true
vector logo is ever wanted.

## Regenerating

Needs `cairosvg` and a Homebrew `cairo`:

```bash
brew install cairo
pip3 install cairosvg
export DYLD_FALLBACK_LIBRARY_PATH="/opt/homebrew/lib:$DYLD_FALLBACK_LIBRARY_PATH"
```
