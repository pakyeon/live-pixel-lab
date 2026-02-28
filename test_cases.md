# LivePixel Lab — Test Case Execution Template

To use this template for a testing cycle, copy this document, fill out the "Test Execution Context" section, and check off the items as you proceed through the tests.

## 📋 Test Execution Context
- **Date:** [YYYY-MM-DD]
- **Tester:** [Name/Role]
- **Version/Branch:** [Version or Branch Name]
- **Environment:** [OS, Godot Version]
- **Overall Status:** [ ] PASS / [ ] FAIL / [ ] PENDING

---

## 🤖 Part 1: Automated Tests

**Instructions:** Run the headless test suite from the terminal: 
```bash
godot --headless -s test_runner.gd
```

### 1. Script Compilation & Syntax
- [ ] **TC-A1**: All GDScript files compile without errors.
- [ ] **TC-A2**: Scene files (`.tscn`) instantiate without missing dependencies.

### 2. Prompt Builder Validation
- [ ] **TC-A3**: Standard layout formatting correctly includes expected elements (e.g., layout description, requirements).
- [ ] **TC-A4**: Reference image instructions are injected when an image is attached.
- [ ] **TC-A5**: Style, frame resolution, and perspective are correctly captured in the generated prompt text.

### 3. Metadata Parsing
- [ ] **TC-A6**: Frame layout logic handles variations correctly (`Side-Scroller` = 7 frames, `Top-Down (RPG)` = 16 frames).
- [ ] **TC-A7**: Animations properly assign the correct start and end frames for idle, walk, and jump sequences.

### 4. Function Calling API Structure
- [ ] **TC-A8**: JSON `tools` array perfectly matches the Gemini API spec for Function Declarations.
- [ ] **TC-A9**: All required tools (`adjust_parameters`, `modify_sprite`, `regenerate_sprite`, `expand_sprite`) declare their expected parameters correctly.

**Automated Test Result Notes:** 
> *Write any stack traces, errors, or observations here.*

---

## 🧑 Part 2: Manual End-to-End Tests

**Instructions:** Launch the project in the Godot Engine editor or run a built executable. Progress through the UI step-by-step.

### 1. UI Rendering and Creator Panel
- [ ] **TC-M1**: The three main panels (Creator, Game, Chat) render correctly without overlapping or missing elements.
- [ ] **TC-M2**: Clicking "Upload Reference Image" properly opens the OS file dialog.
- [ ] **TC-M3**: A selected valid image (PNG/JPG/WEBP) updates the thumbnail preview box.
- [ ] **TC-M4**: OptionButtons for Style, Resolution, and Perspective allow selection and update appropriately.

### 2. Sprite Generation Flow
- [ ] **TC-M5**: Clicking "Generate Sprite" triggers UI loading state (text changes to "Generating...", buttons disable).
- [ ] **TC-M6**: Reference image data and prompt configurations are successfully bundled and sent to the Gemini API.
- [ ] **TC-M7**: The returned sprite sheet is visibly sliced into the correct frame grid based on metadata.
- [ ] **TC-M8**: The newly generated character appears in the center Game View panel.

### 3. Gameplay Mechanics
- [ ] **TC-M9**: Left/Right arrow keys trigger character movement and transition to the `walk` animation.
- [ ] **TC-M10**: Spacebar triggers character jump and transitions to the `jump` animation.
- [ ] **TC-M11**: Stopping all input transitions the character to the `idle` animation.

### 4. Live Chat Modification
- [ ] **TC-M12 (adjust_parameters)**: Submitting "Make jump height 2x higher" immediately alters jump physics without reloading graphics.
- [ ] **TC-M13 (modify_sprite)**: Submitting "Give the character red eyes" generates a new image and prompts to "Apply New Version". Applying maintains position.
- [ ] **TC-M14 (regenerate_sprite)**: Submitting "Change style to 16-bit retro" triggers a full visual regeneration while interpreting base character details.
- [ ] **TC-M15 (expand_sprite)**: Submitting "Add a sword attack animation" integrates a new animation sequence, updates `SpriteFrames`, and explicitly shows the auto-bound hotkey (e.g., "[1]") in the chat pane.

**Manual Test Result Notes:** 
> *Write any unexpected behavior, UI glitches, or user experience issues here.*
