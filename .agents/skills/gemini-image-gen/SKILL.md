---
name: gemini-image-gen
description: Gemini 3.1 Flash Image Preview (gemini-3.1-flash-image-preview) model for image generation and editing. Provides usage instructions, code examples, and configuration options for the Nano Banana 2 image generation API. Covers text-to-image generation, image editing, multi-turn editing, multiple reference images, Google Search Grounding, and high-resolution output. Use this skill whenever the user wants to create or edit images with the Gemini API, or write AI image generation code. Triggers on keywords like 'image generation', 'text to image', 'generate image', 'edit image', 'Gemini image', 'Nano Banana', etc.
---

# Gemini 3.1 Flash Image Preview — Image Generation Skill

Guide for generating and editing images using the **Nano Banana 2** (`gemini-3.1-flash-image-preview`) model from the Gemini API.

> **Note**: All generated images include a SynthID watermark.

## Model Information

| Item | Value |
|------|-------|
| **Model ID** | `gemini-3.1-flash-image-preview` |
| **Alias** | Nano Banana 2 |
| **Features** | High-efficiency, speed-optimized, ideal for high-volume developer use cases |
| **Resolutions** | 512px, 1K (default), 2K, 4K |
| **Aspect Ratios** | 1:1, 1:4, 1:8, 2:3, 3:2, 3:4, 4:1, 4:3, 4:5, 5:4, 8:1, 9:16, 16:9, 21:9 |
| **Reference Images** | Up to 14 (10 objects + 4 characters) |

## Prerequisites

1. **API Key**: Set the `GEMINI_API_KEY` environment variable
2. **SDK Installation**:
   - Python: `pip install google-genai Pillow`
   - JavaScript: `npm install @google/genai`
   - Go: `go get google.golang.org/genai`

---

## 1. Text-to-Image Generation

Generate a new image from a text prompt.

### Python

```python
from google import genai
from google.genai import types
from PIL import Image

client = genai.Client()

response = client.models.generate_content(
    model="gemini-3.1-flash-image-preview",
    contents=["A futuristic cityscape at sunset with flying cars"],
)

for part in response.parts:
    if part.text is not None:
        print(part.text)
    elif part.inline_data is not None:
        image = part.as_image()
        image.save("generated_image.png")
```

### JavaScript

```javascript
import { GoogleGenAI } from "@google/genai";
import * as fs from "node:fs";

const ai = new GoogleGenAI({});

const response = await ai.models.generateContent({
    model: "gemini-3.1-flash-image-preview",
    contents: "A futuristic cityscape at sunset with flying cars",
});

for (const part of response.candidates[0].content.parts) {
    if (part.text) {
        console.log(part.text);
    } else if (part.inlineData) {
        const buffer = Buffer.from(part.inlineData.data, "base64");
        fs.writeFileSync("generated_image.png", buffer);
    }
}
```

### REST (cURL)

```bash
curl -s -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-image-preview:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "contents": [{"parts": [{"text": "A futuristic cityscape at sunset with flying cars"}]}]
  }'
```

---

## 2. Image Editing (Text + Image → Image)

Edit an existing image by providing a text prompt along with the source image.

### Python

```python
from google import genai
from PIL import Image

client = genai.Client()

image = Image.open("/path/to/source_image.png")

response = client.models.generate_content(
    model="gemini-3.1-flash-image-preview",
    contents=["Change the background to a tropical beach", image],
)

for part in response.parts:
    if part.text is not None:
        print(part.text)
    elif part.inline_data is not None:
        part.as_image().save("edited_image.png")
```

### JavaScript

```javascript
import { GoogleGenAI } from "@google/genai";
import * as fs from "node:fs";

const ai = new GoogleGenAI({});
const base64Image = fs.readFileSync("source_image.png").toString("base64");

const response = await ai.models.generateContent({
    model: "gemini-3.1-flash-image-preview",
    contents: [
        { text: "Change the background to a tropical beach" },
        { inlineData: { mimeType: "image/png", data: base64Image } },
    ],
});

for (const part of response.candidates[0].content.parts) {
    if (part.text) console.log(part.text);
    else if (part.inlineData) {
        fs.writeFileSync("edited_image.png", Buffer.from(part.inlineData.data, "base64"));
    }
}
```

---

## 3. Multi-turn Editing (Chat-based)

Use chat sessions to iteratively generate and refine images. Previous context is preserved, allowing step-by-step improvements.

### Python

```python
from google import genai
from google.genai import types

client = genai.Client()

chat = client.chats.create(
    model="gemini-3.1-flash-image-preview",
    config=types.GenerateContentConfig(
        response_modalities=['TEXT', 'IMAGE'],
        tools=[{"google_search": {}}]
    )
)

# Step 1: Initial generation
response = chat.send_message("Create a vibrant infographic about photosynthesis")
for part in response.parts:
    if part.text is not None:
        print(part.text)
    elif image := part.as_image():
        image.save("step1.png")

# Step 2: Refinement
response = chat.send_message("Update this infographic to be in Spanish")
for part in response.parts:
    if part.text is not None:
        print(part.text)
    elif image := part.as_image():
        image.save("step2.png")
```

### JavaScript

```javascript
import { GoogleGenAI } from "@google/genai";

const ai = new GoogleGenAI({});

const chat = ai.chats.create({
    model: "gemini-3.1-flash-image-preview",
    config: {
        responseModalities: ['TEXT', 'IMAGE'],
        tools: [{ googleSearch: {} }],
    },
});

// Step 1: Initial generation
let response = await chat.sendMessage({ message: "Create a vibrant infographic about photosynthesis" });
// Step 2: Refinement
response = await chat.sendMessage({ message: "Update this infographic to be in Spanish" });
```

---

## 4. Resolution and Aspect Ratio Configuration

Use `image_config` to control output image resolution and aspect ratio.

> **Important**: Resolution must use uppercase 'K' (e.g., `2K`, `4K`). Lowercase parameters (e.g., `1k`) will be rejected.

### Python

```python
from google import genai
from google.genai import types

client = genai.Client()

response = client.models.generate_content(
    model="gemini-3.1-flash-image-preview",
    contents=["A panoramic mountain landscape at golden hour"],
    config=types.GenerateContentConfig(
        response_modalities=['TEXT', 'IMAGE'],
        image_config=types.ImageConfig(
            aspect_ratio="16:9",   # Aspect ratio
            image_size="2K"        # Resolution: "512px", "1K", "2K", "4K"
        ),
    )
)
```

### JavaScript

```javascript
const response = await ai.models.generateContent({
    model: "gemini-3.1-flash-image-preview",
    contents: "A panoramic mountain landscape at golden hour",
    config: {
        responseModalities: ['TEXT', 'IMAGE'],
        imageConfig: {
            aspectRatio: "16:9",
            imageSize: "2K",
        },
    },
});
```

---

## 5. Multiple Reference Images (Up to 14)

Mix multiple reference images to generate a new composite image.

- **Object images**: Up to 10 (high-fidelity objects)
- **Character images**: Up to 4 (character consistency)

### Python

```python
from google import genai
from google.genai import types
from PIL import Image

client = genai.Client()

response = client.models.generate_content(
    model="gemini-3.1-flash-image-preview",
    contents=[
        "An office group photo of these people, they are making funny faces.",
        Image.open('person1.png'),
        Image.open('person2.png'),
        Image.open('person3.png'),
    ],
    config=types.GenerateContentConfig(
        response_modalities=['TEXT', 'IMAGE'],
        image_config=types.ImageConfig(
            aspect_ratio="5:4",
            image_size="2K"
        ),
    )
)
```

---

## 6. Google Search Grounding

Generate images based on real-time information (weather, stocks, recent events).

### Python

```python
from google import genai
from google.genai import types

client = genai.Client()

response = client.models.generate_content(
    model="gemini-3.1-flash-image-preview",
    contents="Visualize the current weather forecast for Seoul as a modern chart",
    config=types.GenerateContentConfig(
        response_modalities=['Text', 'Image'],
        image_config=types.ImageConfig(aspect_ratio="16:9"),
        tools=[{"google_search": {}}]
    )
)
```

### Google Image Search Grounding

Leverage visual context through image search.

```python
response = client.models.generate_content(
    model="gemini-3.1-flash-image-preview",
    contents="A detailed painting of a Timareta butterfly resting on a flower",
    config=types.GenerateContentConfig(
        response_modalities=["IMAGE"],
        tools=[
            types.Tool(google_search=types.GoogleSearch(
                search_types=types.SearchTypes(
                    web_search=types.WebSearch(),
                    image_search=types.ImageSearch()
                )
            ))
        ]
    )
)
```

---

## 7. Prompt Writing Best Practices

Tips for effective image generation:

1. **Be specific**: "fantasy armor" → "intricate elven plate armor with silver leaf engravings"
2. **Provide context**: "a high-end minimalist skincare brand logo"
3. **Iterate incrementally**: "make the lighting warmer", "make the expression more serious"
4. **Describe in layers**: background → foreground → main elements
5. **Positive negatives**: "a quiet street with no traffic signs"
6. **Camera control**: specify "wide angle", "macro shot", "low angle", etc.

For more detailed code examples (Go, Java, etc.) and example prompts, see the `references/` directory:
- `references/code_examples.md` — Full Go, Java, REST code examples
- `references/example_prompts.md` — Collection of 8 example prompts
