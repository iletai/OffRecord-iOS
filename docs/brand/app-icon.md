# App icon brief — OffRecord

Source file: `app-icon.svg` (1024×1024, two layers, no text, no gradient, no shadow).

## Layers for Icon Composer

| Layer | Content | Notes |
|---|---|---|
| Background | `#0B0F14` full bleed | Near-black, not pure OLED black — a 1024 icon on a black home screen must still read as a surface. Flat fill only. |
| Foreground | Two shapes only: recording ring `#FFFFFF` 72pt stroke, r=188, and one `#A91D22` bar 78pt at 45° cutting clean through the ring and 12pt past it | Ring = the record control; the bar = off. The crimson bar is the only colour in the icon and it is the same crimson as the Recording screen. Two shapes is the maximum that still reads at 40pt — an earlier version added an inner arc and turned to mush at 40pt (verified with `rsvg-convert -w 40`, 2026-11-23). |
| Optional mono | Same glyph as foreground only, white | For tinted home-screen modes; no background layer. |

## Rules

- No text, no letters, no wordmark, no photograph, no gradient, no glow, no drop shadow, no rounded-square mask baked in (iOS masks it).
- The glyph must survive at 40×40pt: the ring is 0.37 of the canvas with a 0.07 stroke, so at 40pt the ring is 14.7pt across with a 2.8pt stroke — rendered at 40 and 240pt and checked before shipping.
- Light and dark home screens both use the dark background; do not produce a white variant (a white icon next to a white icon set loses the "sealed" read).
- Export: 1024×1024 PNG without alpha for App Store Connect, plus the `.icon` bundle from Icon Composer for iOS 26 layered rendering.

## Accent colour sets to create with the icon

| colorset | Any appearance | Dark |
|---|---|---|
| `AccentColor` | `#2C3E50` | `#8E9AA8` |
| `RecordingCrimson` | `#A91D22` | `#CF4549` |
