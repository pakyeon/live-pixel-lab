# 🎮 LivePixel Lab

> **AI-powered pixel art sprite generator & live game sandbox**
>
> Describe your character in text → AI generates a full sprite sheet → Play it instantly on a game field.

---

## ✨ What is LivePixel Lab?

LivePixel Lab is a **real-time pixel game creation sandbox** built with **Godot 4** and **Google Gemini API**. It blurs the line between *playing* and *creating* by letting you:

1. **Describe** a character in natural language (e.g., *"red-caped wizard with a staff"*)
2. **Generate** a complete animated sprite sheet using Gemini's image generation
3. **Play** the character immediately on a game field — move, jump, and test
4. **Modify** the sprite in real-time via chat commands while playing
5. **Export** the result as a reusable PNG sprite sheet

---

## 🏗 Architecture

```
┌──────────────────────────────────────────────────────┐
│                   User Input                         │
│  (Character description, style, perspective)         │
└────────────────────┬─────────────────────────────────┘
                     │
          ┌──────────▼──────────┐
          │  Step 1: Pro LLM    │  gemini-3.1-pro-preview
          │  Prompt Refinement  │  → Expert-level detailed prompt
          └──────────┬──────────┘
                     │
          ┌──────────▼──────────┐
          │  Step 2: Nano       │  gemini-3.1-flash-image-preview
          │  Banana 2 (Image)   │  → Sprite sheet generation
          └──────────┬──────────┘
                     │
          ┌──────────▼──────────┐
          │  Frame Extraction   │  Dynamic grid slicing
          │  & Auto-Scaling     │  → Game-ready AnimatedSprite2D
          └──────────┬──────────┘
                     │
          ┌──────────▼──────────┐
          │  Live Game Field    │  Godot 4 (Side-Scroller / Top-Down)
          │  Play & Modify      │  → Real-time hot-reload
          └─────────────────────┘
```

---

## 🚀 Getting Started

### Prerequisites

- [Godot 4.6+](https://godotengine.org/download) installed
- A **Gemini API key** ([Get one here](https://aistudio.google.com/apikey))

### Setup

```bash
git clone https://github.com/pakyeon/live-pixel-lab.git
cd live-pixel-lab
```

Set your API key using **one** of these methods:

```bash
# Option 1: .env file (recommended)
echo "GEMINI_API_KEY=your_key_here" > .env

# Option 2: Environment variable
export GEMINI_API_KEY=your_key_here
```

### Run

```bash
cd livepixel
./run.sh
```

> `run.sh` automatically clears Godot's script cache before launch to prevent stale code issues.

---

## 🎯 Features

### Sprite Generation
| Feature | Description |
|---------|-------------|
| **2-Step LLM Pipeline** | Pro model refines your short description into a detailed prompt before image generation |
| **3 Perspectives** | Side-Scroller, Top-Down RPG, Isometric |
| **3 Bit Styles** | 8-bit classic, 16-bit retro, 32-bit modern |
| **6 Frame Resolutions** | 16×16 to 128×128 |
| **Reference Images** | Upload a reference image to guide the AI's output |
| **Dynamic Frame Extraction** | Automatically slices any resolution sprite sheet into correct frames |

### Game Field
| Feature | Description |
|---------|-------------|
| **Instant Play** | Generated sprites are immediately playable on a game field |
| **Auto-Scaling** | High-res sprites are proportionally scaled to fit the game world |
| **Side-Scroller** | Platformer physics with gravity, jump, and walk |
| **Top-Down RPG** | 4-directional movement on an open field |

### Real-Time Modification
| Feature | Description |
|---------|-------------|
| **Chat Commands** | Modify sprite attributes via natural language while playing |
| **Hot-Reload** | Sprite updates are applied without restarting the game |
| **Asset Export** | Export finished sprites as PNG sprite sheets |

---

## 📁 Project Structure

```
live-pixel-lab/
├── livepixel/                    # Godot project root
│   ├── project.godot             # Godot project config
│   ├── run.sh                    # Launch script (clears cache)
│   ├── test_runner.gd            # Automated test suite
│   ├── scenes/
│   │   └── ui/main_ui.tscn       # Main UI scene
│   └── scripts/
│       ├── autoload/
│       │   ├── gemini_api.gd     # Gemini API client (2-step pipeline)
│       │   └── game_manager.gd   # Global game state manager
│       ├── game/
│       │   ├── player.gd         # Player controller & sprite loader
│       │   └── game_world.gd     # Game field renderer
│       └── ui/
│           ├── main_ui.gd        # Main UI controller
│           ├── creator_panel.gd  # Sprite creation panel
│           └── chat_panel.gd     # In-game chat interface
├── livepixel-prd-hackathon.md    # Full PRD document
└── .gitignore
```

---

## 🧪 Running Tests

```bash
cd livepixel
godot --headless -s test_runner.gd
```

Expected output:
```
✅ TC-A3/A4/A5: Prompt Builder includes all spec fields
✅ TC-A6/A7: Side-Scroller layout parsed correctly (7 frames, 64px wide)
✅ TC-A6: Top-Down layout parsed correctly (16 frames, 352px wide)
✅ TC-A8/A9: Function declarations compiled successfully
Test Results: 4 Passed, 0 Failed
```

---

## 🔧 Tech Stack

| Component | Technology |
|-----------|-----------|
| **Game Engine** | Godot 4.6 (GDScript) |
| **Prompt Refinement** | Gemini 3.1 Pro Preview |
| **Image Generation** | Gemini 3.1 Flash Image Preview (Nano Banana 2) |
| **Text Commands** | Gemini 3.1 Flash Preview |

---

## 📄 License

This project was built for the **Gemini API Developer Competition (Hackathon)** under the *Gemini in Entertainment* track.
