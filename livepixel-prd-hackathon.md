# Project Specification & PRD: Text-Based Live Pixel Sprite Playground
## Hackathon Specific Version v3.0

---

## 1. Project Overview

### 1.1 Project Name (Tentative)
- **Project Name (Working Title)**: LivePixel Lab
- **Korean Name (Working Title)**: Live Pixel Lab

### 1.2 One-Line Description
A **live-editable pixel game creation and testing sandbox** where you can define and modify characters and sprites with text, play them immediately within the game, and tweak them in real-time.

### 1.3 Background and Problem Definition
- Pixel art game developers typically:
  - Draw character sprites,
  - Import them into an engine (Unity/Unreal/RPG Maker, etc.),
  - Modify code/build,
  - And verify balance and presentation through actual gameplay.
- This process involves high iteration costs due to tool switching, build/loading times, and data re-importing.
- While some recent engines (like Godot's live editing) allow scene modifications during runtime in the editor, **the experience of sending modification requests naturally via text from a player's perspective and having the results reflected in the game in real-time** is still rare.

This project aims to "blur the boundary between playing and creating, and provide a real-time iteration (Play–Edit–Replay Loop) centered around natural language."

---

## 2. Goals and Vision

### 2.1 Core Goals
1. **Text-Based Asset Definition**
   - Allow users to define bit styles (8/16/32-bit, etc.), character behavior sets, frame counts/speeds, etc., using natural language.
2. **Automated Sprite Generation/Modification**
   - Automatically generate character sprites (including animations) or modify existing images based on the text definitions.
3. **Live Play & Real-Time Modification**
   - Allow users to immediately place generated sprites onto a field (map) and play.
   - When a user requests to modify a sprite/behavior/bit style via chat during gameplay, **regenerate in the background and seamlessly update the session**.
4. **Universal Asset Export**
   - Finally, allow exporting the generated assets in a reusable format (PNG sprite sheet + metadata) for engines like Unity, Unreal, RPG Maker, etc.

### 2.2 Hackathon Success Metrics
- **Demo Completeness**: Showcase the 3 core features working seamlessly to the judges.
- **Idea Impact**: Instantly convey the concept of "modifiable during gameplay".
- **Technical Execution**: Implement a working demo within 24~72 hours using the combination of Godot + Gemini API.

---

## 3. Key User Scenarios

### 3.1 Scenario A: Initial Generation of Nano Banana Character
1. The user creates a new default character or uploads an arbitrary reference image.
2. The user types the following into the right chat panel (or prompt input window):
   - "Create a 32-bit high-bit style yellow banana character. Include 4-frame walk and 6-frame jump animations."
3. The system interprets the text and automatically generates a character sprite set.
4. The user checks the generated sprite preview, and if satisfied, clicks the "Test Play" button.

### 3.2 Scenario B: Modifying Behavior/Bit Style During Play (Core Demo Scenario)
1. The user selects a 16-bit field ground, places the Nano Banana character, and tests it out playing with a keyboard/gamepad.
2. Feeling the jump is too low and the movement is too slow, the user types into the right chat without stopping the game:
   - "Double the jump height. Make walking speed 30% faster. Exaggerate the animation frames a bit more."
3. The system regenerates/adjusts the relevant parameters and sprite animations in the background.
4. Once the modification is complete, an "Apply New Version" button appears. When clicked, the game reloads seamlessly without interruption, allowing the user to experience the changes immediately.

### 3.3 Scenario C: Switching Bit Styles and Exporting
1. The user alternates playing the same character in 8-bit, 16-bit, and 32-bit fields, comparing which style suits their game concept best.
2. After deciding on a pleasing combination (e.g., 32-bit character + 16-bit field), the user clicks the "Export Assets for Unity" button.
3. The system provides a compressed file containing the PNG sprite sheet and JSON/YY format metadata (frame position/speed/behavior mapping).
4. The user imports this file into Unity/Unreal/RPG Maker to proceed with full-scale development.

---

## 4. Feature Specifications

### 4.1 Text-Based Character/Sprite Definition
- **Input Format**
  - Natural language text (Korean/English prioritized).
  - Example: "Gameboy style 8-bit, 3-frame walk, 4-frame jump, play at 12 FPS."
- **Parameter Extraction**
  - Bit Style: 8-bit / 16-bit / 32-bit / 64-bit / Custom palette.
  - Behaviors (States): Idle, Walk, Run, Jump, Attack, etc.
  - Frame Count: Number of frames per behavior.
  - Playback Speed: FPS or ms units.
  - Others: Tone (bright/dark), Silhouette (slim/bulky), Vibe (cute/threatening, etc.).
- **Output**
  - Sprite spec for internal representation (JSON, etc.).
  - Actual visual sprite sheet (or array of frames).

### 4.2 Image Upload and Initial Characterization
- Upload external images like PNG/JPEG to use as a **base silhouette** or color palette.
- Based on the uploaded image:
  - Resample palette/resolution to fit the target bit style.
  - Extract the silhouette and expand it into the specified behavior animations.

### 4.3 Automated Sprite Generation/Modification Engine
- **Generation**
  - Create draft sprites based on text/image inputs.
- **Modification**
  - Interpret delta change requests for existing sprites to regenerate only the necessary parts.
  - Example: "Make the eyes bigger", "Add a spinning motion to the jump", etc.

### 4.4 Bit-Specific Field Ground System
- Provide pre-defined fields/maps in various styles:
  - 8-bit: Limited palette, simple tiles, low resolution.
  - 16-bit: Richer colors/details, retro console style.
  - 32-bit/64-bit: High-bit style, lighting/particle effects.
- Provide automatic scaling / pixel-perfect rendering options according to the character specs.

### 4.5 Real-Time Play & Modification (Core Gimmick)
- **Runtime Session**
  - Combine character + field + behavior set to spawn a playable session.
- **Chat Panel**
  - Always visible on the right side of the game screen.
  - Modification requests can be entered via text during play.
- **Background Operations**
  - Upon receiving a request, in the background:
    - Regenerate sprites/animations/parameters.
    - Verify compatibility (e.g., check if the animation loop breaks upon changing the frame count).
- **Hot Reload**
  - When a new version is ready, reload it while preserving the current session state (position, score, etc.) as much as possible.
  - Designed to reflect new assets with minimal interruption (using fade transitions, etc., if needed).

### 4.6 Asset Export Feature
- **Output Format**
  - PNG sprite sheet (including transparency, 32-bit+).
  - Frame metadata (JSON, YAML, etc.):
    - `rect` (x, y, w, h) for each frame.
    - Frame sequences per behavior.
    - Playback speed, loop status.
  - Engine-specific templates:
    - Unity: Guides or utility scripts for generating Animator/AnimationClip.
    - Unreal: Setup guides for Paper2D Sprites/Flipbooks.
    - RPG Maker: Conversion options tailored to character sheet specifications.

---

## 5. Non-Functional Requirements

### 5.1 Performance (Hackathon Target)
- On a basic PC environment:
  - Feedback time for sprite regeneration/modification requests: 3~5 seconds (target).
  - Screen blackout/fade time upon session reload: 0.5~1 second.

### 5.2 Scalability
- Loosely couple the asset generation logic and the runtime engine to allow future integration with 3D dot (voxel) styles or other rendering pipelines.

### 5.3 Compatibility
- Design the asset format prioritizing standard formats (PNG + JSON) to minimize the difficulty of integrating with other toolchains.

### 5.4 Stability
- Apply safe default values for invalid text inputs or contradictory requests (e.g., "Create a walking animation with 0 frames") and provide error messages / modification suggestions to the user.

---

## 6. Technical Architecture Overview

### 6.1 Main Components (Godot-Native Architecture)
All components run inside a single Godot 4.x application — no separate web frontend or backend server required.

1. **Godot 4.x Application (All-in-One)**
   - 3-panel layout: Creator Panel (left 20%) | Game SubViewport (center 60%) | Chat Panel (right 20%)
   - Built-in 2D rendering with pixel-perfect settings (nearest texture filter, canvas_items stretch mode)
   - `CharacterBody2D` for platformer physics (`move_and_slide()`)
   - `AnimatedSprite2D` for frame-by-frame animation from AI-generated sprite sheets
   - `SubViewport` isolates game rendering from the UI panels
2. **Gemini API Integration (GDScript HTTPRequest)**
   - GDScript calls the Gemini REST API directly via `HTTPRequest` nodes (no middleware needed)
   - API key loaded from environment variable `GEMINI_API_KEY` or `user://api_key.txt`
3. **Prompt Interpreter (Text → Spec) — Autoload: GeminiAPI**
   - Routes to `gemini-3-flash-preview` for simple parameter changes
   - Routes to `gemini-3-pro-preview` for complex character concepts
   - Returns structured JSON with multipliers (speed, jump, gravity, scale, fps)
4. **Sprite Generation/Modification Module — Autoload: GeminiAPI**
   - Uses `gemini-3.1-flash-image-preview` (Nano Banana) for sprite sheet generation and modification
   - Sends text + optional reference image → receives base64 PNG sprite sheet
   - Sprite sheet parsed into `SpriteFrames` resource with idle/walk/jump animations
5. **Game State Manager — Autoload: GameManager**
   - Manages states: MENU → CREATING → PLAYING → MODIFYING → PLAYING
   - Orchestrates hot-reload: fade overlay → swap SpriteFrames → fade in (position preserved)

### 6.2 Data Model (Simplified)
- `CharacterSpec`
  - id, name, bitStyle, palette, behaviors[], spriteSheetRef, metaDataRef
- `Behavior`
  - name, frames[], fps, loop
- `FieldSpec`
  - id, name, bitStyle, tilesetRef, collisionMapRef
- `Session`
  - id, characterSpecId, fieldSpecId, version, runtimeState

---

## 7. LLM and Nano Banana Model Configuration

### 7.1 LLM Separation of Roles
- **Lightweight Task LLM: `gemini-3-flash-preview`**
  - Usage: Parsing short prompts, converting simple parameter modification requests (e.g., "double jump height", "set to 6 frames", etc.) into structured specs.
  - Characteristics: Processes small, iterative modification requests during gameplay quickly with low latency and cost.
- **Complex Task LLM: `gemini-3-pro-preview`**
  - Usage: Generating new character concepts, designing behavior sets with complex rules, interpreting long system messages/settings, and handling difficult text interpretations.
  - Characteristics: Maintains consistent project-wide rules and style guides based on higher reasoning performance.

### 7.2 Nano Banana Image Model
- **Nano Banana: `gemini-3.1-flash-image-preview`**
  - Role: Generates or modifies pixel art-style characters/sprites by taking text and reference images (uploaded images) as input.
  - Example Usage:
    - Initial character generation: "32-bit high-bit style yellow banana character, 4-frame walk, 6-frame jump" → Sprite sheet PNG.
    - Applying modification requests: "Make eyes bigger", "Add spinning motion on jump" → Modifications based on existing sprites.
  - Output: Visually mimics 8/16/32-bit styles, but the actual file format is unified to 32-bit PNG to ensure universal engine compatibility.

### 7.3 Model Routing Strategy
- Automatically routes to the appropriate model based on request type from frontend/backend:
  - **Minor modifications during real-time play** → `gemini-3-flash-preview`
  - **Designing new character/field concepts, defining complex rules/behaviors** → `gemini-3-pro-preview`
  - **Generating and modifying sprites/tilesets** → `gemini-3.1-flash-image-preview`
- Both requests and responses are converted into internal specs (JSON) to be used consistently across the game runtime (Godot) and asset pipelines.

---

## 8. PRD (Product Requirements Document)

### 8.1 Product Vision
"Provides a live pixel sandbox where anyone can create pixel characters and actions with just a few lines of text, and continuously refine them on the fly while playing like a game."

### 8.2 Target Audience
- Indie game developers, solo developers.
- Designers/artists interested in pixel art.
- Creators lacking extensive programming knowledge but eager to experiment with game direction/motion.

### 8.3 Demo Scenes (Hackathon Core)

#### 8.3.1 [Mandatory] Demo Tier 1: Core 3 Features
The critical demo to be showcased on the day of the hackathon **without fail**. Product value is conveyed if only these three are complete.

1. **Character Sprite Generation and Preview via Text**
   - User inputs: "Yellow banana, 32-bit, 4-frame walk, 6-frame jump"
   - Sprite sheet is generated and displayed on screen within 5 seconds.
   - Preview plays the animation for each behavior.

2. **Immediate Play on Field**
   - Place the generated sprite onto the field.
   - Character is controllable via keyboard (Arrows + Space).
   - Jump/walk animations play naturally.

3. **Chat Modification During Play → Hot Reload → Replay**
   - While playing, user types "double the jump height" in the right chat.
   - Regenerates in the background ("Generating..." displayed on screen).
   - Click "Apply" button → Fade transition → Immediately replay on the new version.

#### 8.3.2 [Additional] Demo Tier 2: Plus Factors (If Time Permits)
Supplementary features that improve overall completeness. Lower priority than the first 3.

4. **Real-Time Bit Style Switching**
   - Place the same character into 8-bit/16-bit/32-bit fields.
   - Demonstrate the distinct visual style differences per bit rate.
   - Pitch during presentation: "Our technology supports all pixel game styles."

5. **PNG + JSON Export**
   - Export the current version into a downloadable format.
   - Showcase files actually being created in the download folder.
   - Allow judges to download and inspect post-presentation.

#### 8.3.3 [Out of Scope] Not in Hackathon Scope: Mention Only
These items shouldn't be in the demo, but it's good to mention "these will also be possible in the future" on the presentation slides.

6. **Engine-Specific Export Integration (Unity/Unreal/RPG Maker)**
   - This feature goes into the post-hackathon development schedule.
   - For the presentation: "Plans to add one-click import features for each engine."

7. **History/Rollback Feature**
   - Let users track modification history and revert to prior versions.
   - Excluded from the hackathon scope.

8. **Managing Multiple Characters/Enemy Units**
   - Feature to manage multiple characters at once.
   - Out of the hackathon scope.

---

### 8.4 MVP Scope (Moved from original 8.3)
List of features to actually implement during the hackathon:

1. ✅ Text-Based Character/Sprite Spec Definition (Flash LLM)
2. ✅ Basic Bit Styles (Focus on 32-bit, 8/16-bit via shader options)
3. ✅ Automated Sprite Generation and Preview (Nano Banana Model)
4. ✅ Playable on 1~2 basic fields (Godot default scene)
5. ✅ Simple parameter modification via chat during play (Flash LLM)
6. ✅ Session hot reload post-modification (Godot ResourceLoader)
7. ⚠️ Basic Export in PNG + JSON formats (If time permits)

---

### 8.5 Future Expansion Features (For Mentions)
- Support for multiple characters/enemy units.
- Multiplayer spectator/shared sessions.
- Community asset market/library.
- Script-based behavior definitions (simple node graphs, etc.).
- One-click Engine Export (Unity AnimationClip, Unreal Paper2D, RPG Maker compatible).

### 8.6 UX Requirements
- Main screen is broadly divided into three areas:
  1) Center (60%): Gameplay screen
  2) Left/Top (20%): Character/Field selection and preview area
  3) Right (20%): Chat/Prompt input panel
- Chat panel must always be visible even during gameplay, and requests should be sent **upon a single Enter key press**.
- Once asset regeneration/modification is complete, an "Apply New Version" toast/button should temporarily appear at the top or bottom of the screen, to be clicked by the user when desired.

### 8.7 Risks and Hypotheses
- **Hypothesis 1:** Natural language-based modification requests will offer a faster and more intuitive workflow than GUI sliders/checkboxes.
- **Hypothesis 2:** A real-time mod-play loop will significantly boost prototyping speed compared to traditional tools.
- **Risks & Solutions:**
  - **Inaccurate text interpretation** → Leads to unwanted changes → Hackathon: Add parameter validation logic; Future: Add History/Rollback feature.
  - **Prolonged sprite regeneration time** → Breaks the "real-time" experience → Hackathon: Pre-load basic templates; Future: Establish caching strategies.
  - **Unstable Godot Hot Reload** → Session interruption → Hackathon: Simple fade transition + restart; Future: Advance state preservation logic.

---

## 9. Hackathon Milestones (Single-Day Format)

### Phase 1 (9:00–11:00 AM): Setup & Core Infrastructure
- Project scaffold complete (Godot 4.x, autoloads, scene structure)
- 3-panel UI layout working (Creator | Game | Chat)
- Basic CharacterBody2D platformer with keyboard controls
- GeminiAPI autoload with HTTPRequest integration

### Phase 2 (11:00 AM–2:00 PM): Core Demo Features
- Sprite generation pipeline via Nano Banana model
- Sprite sheet → SpriteFrames parsing and AnimatedSprite2D
- Chat panel with text parsing and parameter modification
- Hot-reload with fade transition

### Phase 3 (2:00–4:30 PM): Polish & Demo Prep
- UI refinements and visual polish
- Bit style switching (8/16/32-bit field palettes)
- End-to-end demo rehearsal
- Record backup demo video
- Prepare 1-min submission video

---

## 10. Solo Vibe-Coding Setup

This project is designed for **solo development** with AI-assisted vibe coding. All components are unified in a single Godot 4.x project:

| Area | Key Files | Core Technology |
|---|---|---|
| **API Layer** | `scripts/autoload/gemini_api.gd` | GDScript + HTTPRequest → Gemini REST API |
| **Game Logic** | `scripts/game/player.gd`, `game_world.gd` | CharacterBody2D, AnimatedSprite2D |
| **UI** | `scripts/ui/main_ui.gd`, `chat_panel.gd`, `creator_panel.gd` | Godot Control nodes |
| **State** | `scripts/autoload/game_manager.gd` | Autoload singleton |

---

## 11. Conclusion

This project is a live pixel game creation/testing environment built around the core value of "ability to modify seamlessly while playing."

**Hackathon Perspective:**
- Completing just the 3 core demos is sufficient to convey the value of the idea and technical execution capability.
- The combination of Godot 4.x + Gemini API is a free, open-source stack that allows for a working prototype within 24~72 hours without licensing issues.
- It possesses clear distinguishing gimmicks that judges can instantly understand during the presentation.

**Technical Direction:**
- By combining Godot 4.x's 2D runtime with Gemini-based LLMs/image models, we establish a modern pixel art pipeline ranging from 8 to 32-bit (visual style-wise, actual files being 32-bit PNGs), designed flexibly enough for future 64-bit/HDR support and additional engine integrations.

---

## [Appendix] Demo Cut Checklist (Final Check Before Day 3 Pitch)

```
[ ] Demo 1: Input "Yellow banana, 4-frame walk, 6-frame jump" → Sprite generated under 5 seconds ✓
[ ] Demo 2: Place character on field, move with Arrows + Space, animations play ✓
[ ] Demo 3: Without pausing the game, type "double jump height" in chat, click apply, instantly replay ✓
[ ] Presentation Slides: Main gimmick stated clearly on the first slide ✓
[ ] Rehearsal of live demo sequence and timing (within 3 mins total) completed ✓
[ ] Offline Contingency: Prepared screenshots/recorded videos ✓
[ ] Team roles delegated and individual tests completed ✓
```
