# VoxelSprite

iPad-first (+ macOS) SwiftUI-App zum Erstellen von Minecraft-Block-Texturen und Resourcepacks.

## Features

### Block-Editor
- **6-Face-System:** Jede Seite des Blocks (Top, Bottom, North, South, East, West) hat ein eigenes 16x16 Canvas
- **Face-Selector:** Aufgeklappter Würfel als Kreuzform-Layout zum schnellen Wechsel zwischen Faces
- **Block-Templates:** Vollblock, Gras-Style, Säule, Slab, Custom — verknüpfte Faces werden automatisch synchronisiert

### Zeichenwerkzeuge
- Stift, Radierer, Füllen (Flood Fill), Linie (Bresenham), Rechteck
- Undo/Redo (bis zu 50 Schritte)
- Zoom (0.5x–4x)
- Rasterlinien-Overlay
- Face Overlay: andere Block-Seite halbtransparent einblenden

### Vorschau
- **Isometrische 3D-Vorschau:** Alle Faces live auf dem Würfel sichtbar
- **4 Ansichten:** Isometrisch, Front, Back, Top-Down
- **Tile-Vorschau:** Block 3x3 gekachelt für nahtlose Texturen

### Minecraft-Farbpalette
- Vordefinierte Farben: Stein, Holz, Erde, Gras, Erze, Nether, End
- Custom Color Picker
- Paletten speichern und laden

### Export
- **Face PNGs:** Einzelne 16x16 PNGs pro Face
- **Minecraft Resourcepack:** Komplette Ordnerstruktur mit:
  - `assets/<namespace>/textures/block/` — Texturen
  - `assets/<namespace>/models/block/` — Block Model JSON
  - `assets/<namespace>/blockstates/` — Blockstate JSON
  - `pack.mcmeta`
- **Zielversionen:** Java Edition 1.20+, Bedrock Edition
- Template-optimierter Export (Vollblock = 1 Textur, Gras-Style = 3 Texturen, etc.)

### Projektformat
- `.voxel` Dateiformat (JSON-basiert)
- Autosave mit 2-Slot-Rotation
- Speichern/Öffnen auf iPad und macOS

## Architektur

```
VoxelSprite/
├── Models/
│   ├── BlockFace.swift          # FaceType Enum + BlockFace Struct
│   ├── BlockProject.swift       # Block-Projekt mit 6 Faces + Templates
│   └── VoxelProjectFile.swift   # .voxel Serialisierung + FileDocument
├── ViewModels/
│   ├── BlockViewModel.swift     # Projekt-Management, Face-Navigation
│   ├── CanvasViewModel.swift    # Zeichentools, Undo/Redo, Face Overlay
│   ├── ExportViewModel.swift    # Resourcepack-Export, Face PNGs
│   └── PaletteManager.swift     # Gespeicherte Farbpaletten
├── Views/Canvas/
│   ├── ContentView.swift        # Root View mit Layout
│   ├── FaceSelectorView.swift   # Kreuzform Face-Selector
│   ├── IsometricPreviewView.swift # 3D Würfel-Vorschau + Tile-Preview
│   ├── PixelCanvas.swift        # Pixel-Grid Datenstruktur
│   ├── PixelCanvasView.swift    # Interaktives Zeichenfeld
│   ├── ToolBarView.swift        # Werkzeugleiste
│   └── ColorPaletteView.swift   # Minecraft-Farbpalette
└── VoxelSpriteApp.swift         # App Entry Point + Menüleiste
```

**Pattern:** MVVM mit `@EnvironmentObject`
- `BlockViewModel` besitzt das Projekt
- `CanvasViewModel` und `ExportViewModel` halten schwache Referenzen

## Technische Details

- **SwiftUI**, kein UIKit (außer Share Sheet + Haptics)
- iPad-first, macOS via Catalyst/native
- Keine externen Dependencies
- Minimum iOS 17 / macOS 14
- Dark Theme: `Color(red: 0.1, green: 0.1, blue: 0.14)`
- Akzentfarbe: Electric Teal `Color(red: 0.0, green: 0.85, blue: 0.85)`

## Verwandtes Projekt

VoxelSprite ist die Schwester-App von **PlanktonSprite** (Pixel-Animation-Tool).
Die Engine (PixelCanvas, Farbsystem, Export-Pipeline, Dark Theme) wurde übernommen,
der Workflow komplett auf Minecraft-Block-Texturen umgebaut.
