# PlanktonSprite

Pixel-Sprite-Animator — zeichne Sprites auf einem variablen Canvas (16x16 bis 64x64), animiere Frame für Frame und exportiere als GIF oder Spritesheet mit Engine-Presets.

PlanktonSprite is a native SwiftUI sprite animation tool built for indie game developers.  
Draw pixel-perfect frames, animate with onion skin, and export directly into your game engine — no desktop required.

- **Variable Canvas-Groessen** — 16x16, 32x32, 64x64 (oder Custom bis 128x128)
- **5 Zeichenwerkzeuge** — Stift, Radierer, Fuellwerkzeug, Linie (Bresenham), Rechteck (Outline)
- **Multi-Frame Animation** — bis zu 24 Frames, einstellbare FPS (1-24), per-Frame Duration (ms)
- **Onion Skin** — vorheriges/naechstes Frame als Overlay mit konfigurierbarer Transparenz
- **Zoom** — 0.5x bis 4x fuer praezises Arbeiten
- **GIF-Export** — animiertes GIF mit Loop-Toggle, per-Frame Timing, transparentem Hintergrund
- **PNG-Spritesheet-Export** — Horizontal, Vertikal oder Grid-Layout mit konfigurierbarem Padding
- **Engine-Presets** — JSON-Meta fuer Unity (pivot/border/pixelsPerUnit), Godot (region/AtlasTexture), SpriteKit (textureRect), Generic
- **Saved Palettes** — eigene Farbpaletten speichern, laden, loeschen
- **Autosave** — automatisch alle 60s + bei Frame-Operationen + bei App-Background, 2-Slot Rotation in Application Support
- **Universal App** (iPad + macOS) — adaptives Layout, ein Codebase
- **Undo/Redo** — Stack-basiert mit bis zu 50 Schritten
- **Projektdateien** — eigenes .plankton-Format (JSON-basiert, versioniert)
- **Drag & Drop** — Frames per Drag umsortieren

## ✨ Why PlanktonSprite?

Swift, SwiftUI, CoreGraphics, ImageIO, UniformTypeIdentifiers

## Architektur

MVVM mit EnvironmentObject-Injection:

- **CanvasViewModel** — Zeichentools, Undo/Redo, Zoom, Onion Skin
- **FrameViewModel** — Projekt-/Frame-Verwaltung, Save/Load, Autosave
- **ExportViewModel** — GIF/Spritesheet/JSON-Export mit Progress-Feedback
- **PaletteManager** — Saved Palettes mit UserDefaults-Persistenz

## Export-Formate

| Format | Beschreibung |
|--------|-------------|
| `.gif` | Animiertes GIF (Loop/No-Loop, per-Frame Duration, transparent BG) |
| `.png` | Spritesheet (Horizontal/Vertikal/Grid, konfigurierbares Padding) |
| `.json` | Meta-Daten mit Engine-spezifischen Feldern (formatVersion: 1) |
| `.plankton` | Projektdatei (JSON, alle Frames + Settings + Canvas-Daten) |
Most pixel apps are drawing tools.

PlanktonSprite is a **production tool**.

It focuses on:
- Animation workflow
- Precise frame control
- Engine-ready export
- Clean, fast mobile UX

No subscriptions. No accounts. Just pixels.

---

## 🎨 Canvas & Drawing

- Canvas sizes: **16×16, 32×32, 64×64**
- Pixel-perfect Pencil Tool
- Bresenham Line Tool
- Rectangle Tool (outline)
- Zoom: **0.5× – 4×**
- Grid toggle
- Saved custom palettes
- Undo / Redo (configurable limit)

---

## 🎬 Animation System

- Up to **24 frames**
- Drag & reorder timeline
- Per-frame duration (milliseconds)
- Loop toggle (once / infinite)
- Onion Skin (previous & next frame)
- Adjustable onion opacity
- Haptic feedback (iOS)

---

## 📦 Export

### GIF Export
- Transparent background support
- Per-frame duration respected
- Loop control applied

### Spritesheet Export
- Layouts:
  - Horizontal
  - Vertical
  - Grid
- Padding & pivot support
- PNG + JSON metadata

### Engine Presets
- Unity (pixelsPerUnit, filterMode)
- Godot (AtlasTexture, region)
- SpriteKit (normalized textureRect)
- Generic JSON format

Exports are designed for direct integration into game pipelines.

---

## 💾 Project System

- `.plankton` JSON-based project format
- `formatVersion` for future migrations
- Autosave support
- Atomic file writing
- Cross-platform (iPhone, iPad, macOS)

---

## 🧪 Testing

~80 unit tests covering:

- Variable canvas sizes
- Bresenham line algorithm
- Rectangle drawing
- Zoom scaling
- Onion skin logic
- Per-frame duration handling
- Spritesheet layouts
- Engine preset JSON output
- Palette persistence

---

## 🛠 Tech Stack

- Swift
- SwiftUI
- CoreGraphics
- ImageIO (GIF encoding)
- Codable-based project model
- MainActor UI state management

---

## 🎯 Target Audience

- Indie game developers
- Game jam creators
- Pixel artists building animated sprites
- Developers who want a mobile-first sprite workflow

---

## 🚀 Roadmap

- Performance optimizations (pixel storage backend)
- Additional engine presets
- Extended export formats
- Advanced animation features

---

## 📄 License

(Choose your license here — MIT recommended for open source.)

---

## 👤 Author

Built by Andreas Pelczer  
Focused on clean architecture and developer-first tools.

---

> Build sprites. Export to engine. Ship your game.
