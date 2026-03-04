# VoxelSprite

iPad-first (+ macOS) SwiftUI-App zum Erstellen von Minecraft-Texturen und Resourcepacks.
7 Editor-Modi: Block, Item, Skin, Painting, Entity, Armor, Recipe.

## Features

### Block-Editor
- **6-Face-System:** Jede Seite des Blocks (Top, Bottom, North, South, East, West) hat ein eigenes 16×16 Canvas
- **Face-Selector:** Aufgeklappter Würfel als Kreuzform-Layout zum schnellen Wechsel zwischen Faces
- **Block-Templates:** Vollblock, Gras-Style, Säule, Slab, Custom — verknüpfte Faces werden automatisch synchronisiert
- **Animation:** Multi-Frame Texturen mit .mcmeta-Export und konfigurierbarer Frametime
- **CTM:** Connected Textures für OptiFine/Continuity (Random + Repeat)

### Item-Editor
- **Multi-Layer:** Mehrere Textur-Layer (wie Minecraft `layer0`, `layer1`, etc.)
- **Display-Typen:** Generated (Inventar) oder Handheld (Schwert/Werkzeug)
- **Layer-Overlay:** Andere Layer halbtransparent einblenden
- **3D-Vorschau:** Live Item-Preview

### Skin-Editor (Steve/Alex)
- **UV-Mapping:** Korrekte Minecraft Skin-UV-Zuordnung (64×64)
- **Body Parts:** Kopf, Körper, Arme, Beine — einzeln bearbeitbar
- **Base + Overlay Layer:** Zweischichtiges System wie in Minecraft
- **3D Steve-Preview:** Live SceneKit-Vorschau

### Painting-Editor
- **7 Größen:** 1×1, 2×1, 1×2, 2×2, 4×2, 4×3, 4×4 (in Minecraft-Blöcken)
- **Painting Variant:** Exportiert Datapack mit `painting_variant` Registry (1.19+)

### Entity-Editor (Mobs)
- **7 Mob-Typen:** Creeper, Pig, Cow, Chicken, Spider, Enderman, Skeleton
- **Body Parts:** UV-gemappte Körperteile pro Mob (Kopf, Körper, Beine, etc.)
- **Textur-Atlas:** 64×64 oder 64×32 je nach Entity-Typ

### Armor-Editor (Rüstungen)
- **9 Rüstungsteile:** Helm, Brustplatte, Arme, Beinschutz, Stiefel
- **2 Layer:** Layer 1 (Helm/Brust/Arme/Stiefel) + Layer 2 (Beinschutz)
- **6 Materialien:** Leder, Kette, Eisen, Gold, Diamant, Netherit

### Crafting-Recipe-Editor
- **Rezept-Typen:** Shaped, Shapeless, Smelting, Blasting, Smoking
- **Visueller Grid-Editor:** 3×3 Crafting-Grid mit Item-Platzierung
- **JSON-Export:** Minecraft-kompatible Recipe JSON + Loot Tables
- **Datapack-Export:** Komplette Datapack-Struktur

### Zeichenwerkzeuge
- **Stift, Radierer, Füllen (Flood Fill), Linie (Bresenham), Rechteck**
- **Pipette (Eyedropper):** Farbe direkt vom Canvas aufnehmen
- **Spiegel horizontal/vertikal:** Canvas-Transformationen
- **Rotation 90°:** Im Uhrzeigersinn drehen (quadratische Canvases)
- **PNG Import:** Bestehende Texturen laden und auf Canvas-Größe skalieren
- Undo/Redo (bis zu 50 Schritte)
- Zoom (0.5×–4×), Rasterlinien, Face Overlay

### Vorschau
- **Isometrische 3D-Vorschau:** Alle Faces live auf dem Würfel (SceneKit)
- **4 Ansichten:** Isometrisch, Front, Back, Top-Down
- **Tile-Vorschau:** Block 3×3 gekachelt für nahtlose Texturen
- **Item-Preview:** 3D-Ebene mit Generated/Handheld-Modus
- **Steve-Preview:** 3D Steve-Modell mit Live-Textur

### Minecraft-Farbpalette
- Vordefinierte Farben: Stein, Holz, Erde, Gras, Erze, Nether, End
- Custom Color Picker
- Paletten speichern und laden

### Export (alles als ZIP)
- **Face PNGs:** Einzelne Texturen pro Face/Layer
- **Block-Resourcepack:** `textures/block/`, Model JSON, Blockstate JSON, CTM, Animation
- **Item-Resourcepack:** `textures/item/`, Item Model JSON
- **Entity-Resourcepack:** `textures/entity/`
- **Armor-Resourcepack:** `textures/models/armor/` (Layer 1 + Layer 2)
- **Painting-Datapack:** `painting_variant` Registry
- **Recipe-Datapack:** Recipe JSON + Loot Tables
- **Multi-Asset Resourcepack:** Bündelt alle Assets (Blöcke, Items, Paintings, Entities, Armors)
- **Zielversionen:** Java Edition 1.20+, Bedrock Edition
- Template-optimierter Export (Vollblock = 1 Textur, Gras-Style = 3, Custom = 6)

### Projektformat
- `.voxel` Dateiformat für einzelne Block-Projekte (JSON-basiert)
- `.voxelwork` Workspace-Format für alle Editor-Zustände (Block + Item + Skin + Painting + Entity + Armor + Recipe)
- **Autosave:** 60-Sekunden-Timer + Stroke-Debounce für alle Editor-Modi
- 2-Slot-Rotation (latest + previous) für Backup
- Auto-Restore beim App-Start
- Speichern/Öffnen auf iPad und macOS

## Architektur

```
VoxelSprite/
├── Models/
│   ├── BlockProject.swift         # Block mit 6 Faces + Templates + CTM + Animation
│   ├── BlockFace.swift            # FaceType Enum + BlockFace Struct
│   ├── ItemProject.swift          # Item mit Multi-Layer
│   ├── SkinProject.swift          # Skin mit UV-Mapping (Steve/Alex)
│   ├── PaintingProject.swift      # Painting mit variabler Größe
│   ├── EntityProject.swift        # Entity-Texturen (7 Mob-Typen)
│   ├── ArmorProject.swift         # Rüstungstexturen (2 Layer, 9 Teile)
│   ├── CraftingRecipe.swift       # Rezepte (Shaped, Smelting, etc.)
│   ├── ResourcepackProject.swift  # Multi-Asset Bündel
│   ├── VoxelProjectFile.swift     # .voxel Serialisierung
│   ├── VoxelWorkspaceFile.swift   # .voxelwork Workspace-Serialisierung
│   ├── ZIPHelper.swift            # Pure-Swift ZIP-Archiv-Erstellung
│   └── ColorExtensions.swift      # Hex-Konvertierung, RGBA-Extraktion
├── ViewModels/
│   ├── BlockViewModel.swift       # Block-Management, Face-Navigation
│   ├── ItemViewModel.swift        # Item-Management, Layer-Navigation
│   ├── SkinViewModel.swift        # Skin-Management, Body Part/Face/Layer
│   ├── PaintingViewModel.swift    # Painting-Management, Größenänderung
│   ├── EntityViewModel.swift      # Entity-Management, Mob-Typ-Wechsel
│   ├── ArmorViewModel.swift       # Armor-Management, Piece/Layer
│   ├── RecipeViewModel.swift      # Rezept-Management, Grid-Bearbeitung
│   ├── ResourcepackViewModel.swift # Multi-Asset Resourcepack
│   ├── CanvasViewModel.swift      # Zeichentools, Undo/Redo, Import, Transforms
│   ├── ExportViewModel.swift      # Export-Orchestrator
│   ├── PNGRenderer.swift          # Canvas → CGImage → PNG (extrahiert)
│   ├── MinecraftPackWriter.swift  # Pack-Struktur + JSON (extrahiert)
│   ├── WorkspaceManager.swift     # Workspace Autosave + Save/Load
│   └── PaletteManager.swift       # Gespeicherte Farbpaletten
├── Views/Canvas/
│   ├── ContentView.swift          # Root View mit 7 Editor-Modi
│   ├── PixelCanvas.swift          # Pixel-Grid + PNG Import + Transforms
│   ├── PixelCanvasView.swift      # Interaktives Zeichenfeld
│   ├── ToolBarView.swift          # Werkzeugleiste + Import + Transforms
│   ├── FaceSelectorView.swift     # Kreuzform Face-Selector
│   ├── ColorPaletteView.swift     # Minecraft-Farbpalette
│   ├── SceneKitPreviewView.swift  # 3D Block-Vorschau (SceneKit)
│   ├── IsometricPreviewView.swift # Isometrische Vorschau + Tile-Preview
│   ├── ItemPreviewView.swift      # 3D Item-Vorschau
│   └── AnimationTimelineView.swift # Frame-Timeline für Animationen
├── Views/Skin/
│   └── StevePreviewView.swift     # 3D Steve-Vorschau (SceneKit)
└── VoxelSpriteApp.swift           # App Entry Point + Menüleiste + Workspace
```

**Pattern:** MVVM mit `@EnvironmentObject`
- Jeder Editor-Typ hat sein eigenes ViewModel
- `CanvasViewModel` vermittelt zwischen allen Editoren und den Drawing-Tools
- `WorkspaceManager` koordiniert Autosave über alle Modi hinweg
- `ExportViewModel` orchestriert den Export, delegiert an `PNGRenderer` und `MinecraftPackWriter`

## Technische Details

- **SwiftUI**, kein UIKit (außer Share Sheet + Haptics)
- iPad-first, macOS via Catalyst/native
- Keine externen Dependencies
- Minimum iOS 17 / macOS 14
- Dark Theme: `Color(red: 0.1, green: 0.1, blue: 0.14)`
- Akzentfarbe: Electric Teal `Color(red: 0.0, green: 0.85, blue: 0.85)`
- Pure-Swift ZIP-Archiv-Erstellung (kein libz/zlib, Store-only)
- SceneKit für 3D-Vorschau (Block, Item, Steve)

## Verwandtes Projekt

VoxelSprite ist die Schwester-App von **PlanktonSprite** (Pixel-Animation-Tool).
Die Engine (PixelCanvas, Farbsystem, Export-Pipeline, Dark Theme) wurde übernommen,
der Workflow komplett auf Minecraft-Texturen umgebaut.
