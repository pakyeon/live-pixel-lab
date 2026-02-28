# Gemini 3.1 Flash Image Preview — Additional Code Examples

Extended Go, Java, and REST code examples not included in the main SKILL.md.

## Table of Contents

1. [Text-to-Image](#1-text-to-image)
2. [Image Editing (Text + Image)](#2-image-editing)
3. [Multi-turn Editing](#3-multi-turn-editing)
4. [Multiple Reference Images](#4-multiple-reference-images)
5. [Google Search Grounding](#5-google-search-grounding)

---

## 1. Text-to-Image

### Go

```go
package main

import (
    "context"
    "fmt"
    "log"
    "os"
    "google.golang.org/genai"
)

func main() {
    ctx := context.Background()
    client, err := genai.NewClient(ctx, nil)
    if err != nil {
        log.Fatal(err)
    }

    result, _ := client.Models.GenerateContent(
        ctx,
        "gemini-3.1-flash-image-preview",
        genai.Text("Create a picture of a nano banana dish in a fancy restaurant with a Gemini theme"),
    )

    for _, part := range result.Candidates[0].Content.Parts {
        if part.Text != "" {
            fmt.Println(part.Text)
        } else if part.InlineData != nil {
            _ = os.WriteFile("generated_image.png", part.InlineData.Data, 0644)
        }
    }
}
```

### Java

```java
import com.google.genai.Client;
import com.google.genai.types.GenerateContentConfig;
import com.google.genai.types.GenerateContentResponse;
import com.google.genai.types.Part;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;

public class TextToImage {
    public static void main(String[] args) throws IOException {
        try (Client client = new Client()) {
            GenerateContentConfig config = GenerateContentConfig.builder()
                .responseModalities("TEXT", "IMAGE")
                .build();

            GenerateContentResponse response = client.models.generateContent(
                "gemini-3.1-flash-image-preview",
                "Create a picture of a nano banana dish in a fancy restaurant",
                config);

            for (Part part : response.parts()) {
                if (part.text().isPresent()) {
                    System.out.println(part.text().get());
                } else if (part.inlineData().isPresent()) {
                    var blob = part.inlineData().get();
                    if (blob.data().isPresent()) {
                        Files.write(Paths.get("generated_image.png"), blob.data().get());
                    }
                }
            }
        }
    }
}
```

---

## 2. Image Editing

### Go

```go
package main

import (
    "context"
    "fmt"
    "log"
    "os"
    "google.golang.org/genai"
)

func main() {
    ctx := context.Background()
    client, err := genai.NewClient(ctx, nil)
    if err != nil {
        log.Fatal(err)
    }

    imgData, _ := os.ReadFile("/path/to/source_image.png")

    parts := []*genai.Part{
        genai.NewPartFromText("Change the background to a tropical beach"),
        &genai.Part{
            InlineData: &genai.Blob{
                MIMEType: "image/png",
                Data:     imgData,
            },
        },
    }

    contents := []*genai.Content{
        genai.NewContentFromParts(parts, genai.RoleUser),
    }

    result, _ := client.Models.GenerateContent(
        ctx,
        "gemini-3.1-flash-image-preview",
        contents,
    )

    for _, part := range result.Candidates[0].Content.Parts {
        if part.Text != "" {
            fmt.Println(part.Text)
        } else if part.InlineData != nil {
            _ = os.WriteFile("edited_image.png", part.InlineData.Data, 0644)
        }
    }
}
```

### Java

```java
import com.google.genai.Client;
import com.google.genai.types.*;
import java.io.IOException;
import java.nio.file.*;

public class TextAndImageToImage {
    public static void main(String[] args) throws IOException {
        try (Client client = new Client()) {
            GenerateContentConfig config = GenerateContentConfig.builder()
                .responseModalities("TEXT", "IMAGE")
                .build();

            GenerateContentResponse response = client.models.generateContent(
                "gemini-3.1-flash-image-preview",
                Content.fromParts(
                    Part.fromText("Change the background to a tropical beach"),
                    Part.fromBytes(
                        Files.readAllBytes(Path.of("source_image.png")),
                        "image/png")),
                config);

            for (Part part : response.parts()) {
                if (part.text().isPresent()) {
                    System.out.println(part.text().get());
                } else if (part.inlineData().isPresent()) {
                    var blob = part.inlineData().get();
                    if (blob.data().isPresent()) {
                        Files.write(Paths.get("edited_image.png"), blob.data().get());
                    }
                }
            }
        }
    }
}
```

### REST

```bash
curl -s -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-image-preview:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H 'Content-Type: application/json' \
  -d "{
    \"contents\": [{
      \"parts\":[
        {\"text\": \"Change the background to a tropical beach\"},
        {\"inline_data\": {\"mime_type\":\"image/png\", \"data\": \"<BASE64_IMAGE_DATA>\"}}
      ]
    }]
  }"
```

---

## 3. Multi-turn Editing

### Go

```go
package main

import (
    "context"
    "fmt"
    "log"
    "os"
    "google.golang.org/genai"
)

func main() {
    ctx := context.Background()
    client, err := genai.NewClient(ctx, nil)
    if err != nil {
        log.Fatal(err)
    }
    defer client.Close()

    model := client.GenerativeModel("gemini-3.1-flash-image-preview")
    model.GenerationConfig = &pb.GenerationConfig{
        ResponseModalities: []pb.ResponseModality{genai.Text, genai.Image},
    }
    chat := model.StartChat()

    // Step 1: Initial generation
    resp, _ := chat.SendMessage(ctx, genai.Text("Create a vibrant infographic about photosynthesis"))
    for _, part := range resp.Candidates[0].Content.Parts {
        if txt, ok := part.(genai.Text); ok {
            fmt.Println(string(txt))
        } else if img, ok := part.(genai.ImageData); ok {
            os.WriteFile("step1.png", img.Data, 0644)
        }
    }

    // Step 2: Refinement
    resp, _ = chat.SendMessage(ctx, genai.Text("Update to Spanish"))
    // ... process in the same way
}
```

### Java

```java
import com.google.genai.*;
import com.google.genai.types.*;
import java.io.IOException;
import java.nio.file.*;

public class MultiturnImageEditing {
    public static void main(String[] args) throws IOException {
        try (Client client = new Client()) {
            GenerateContentConfig config = GenerateContentConfig.builder()
                .responseModalities("TEXT", "IMAGE")
                .tools(Tool.builder()
                    .googleSearch(GoogleSearch.builder().build())
                    .build())
                .build();

            Chat chat = client.chats.create("gemini-3.1-flash-image-preview", config);

            // Step 1: Initial generation
            GenerateContentResponse response = chat.sendMessage(
                "Create a vibrant infographic about photosynthesis");

            for (Part part : response.parts()) {
                if (part.text().isPresent()) {
                    System.out.println(part.text().get());
                } else if (part.inlineData().isPresent()) {
                    var blob = part.inlineData().get();
                    if (blob.data().isPresent()) {
                        Files.write(Paths.get("step1.png"), blob.data().get());
                    }
                }
            }

            // Step 2: Refinement
            response = chat.sendMessage("Update to Spanish");
            // ... process in the same way
        }
    }
}
```

### REST

```bash
curl -s -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-image-preview:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "contents": [{
      "role": "user",
      "parts": [{"text": "Create a vibrant infographic about photosynthesis"}]
    }],
    "generationConfig": {
      "responseModalities": ["TEXT", "IMAGE"]
    }
  }'
```

---

## 4. Multiple Reference Images

### Go

```go
package main

import (
    "context"
    "fmt"
    "log"
    "os"
    "google.golang.org/genai"
)

func main() {
    ctx := context.Background()
    client, err := genai.NewClient(ctx, nil)
    if err != nil {
        log.Fatal(err)
    }
    defer client.Close()

    model := client.GenerativeModel("gemini-3.1-flash-image-preview")
    model.GenerationConfig = &pb.GenerationConfig{
        ResponseModalities: []pb.ResponseModality{genai.Text, genai.Image},
        ImageConfig: &pb.ImageConfig{
            AspectRatio: "5:4",
            ImageSize: "2K",
        },
    }

    img1, _ := os.ReadFile("person1.png")
    img2, _ := os.ReadFile("person2.png")
    img3, _ := os.ReadFile("person3.png")

    parts := []genai.Part{
        genai.Text("An office group photo of these people, they are making funny faces."),
        genai.ImageData{MIMEType: "image/png", Data: img1},
        genai.ImageData{MIMEType: "image/png", Data: img2},
        genai.ImageData{MIMEType: "image/png", Data: img3},
    }

    resp, _ := model.GenerateContent(ctx, parts...)
    for _, part := range resp.Candidates[0].Content.Parts {
        if txt, ok := part.(genai.Text); ok {
            fmt.Println(string(txt))
        } else if img, ok := part.(genai.ImageData); ok {
            os.WriteFile("group_photo.png", img.Data, 0644)
        }
    }
}
```

### Java

```java
import com.google.genai.Client;
import com.google.genai.types.*;
import java.io.IOException;
import java.nio.file.*;

public class GroupPhoto {
    public static void main(String[] args) throws IOException {
        try (Client client = new Client()) {
            GenerateContentConfig config = GenerateContentConfig.builder()
                .responseModalities("TEXT", "IMAGE")
                .imageConfig(ImageConfig.builder()
                    .aspectRatio("5:4")
                    .imageSize("2K")
                    .build())
                .build();

            GenerateContentResponse response = client.models.generateContent(
                "gemini-3.1-flash-image-preview",
                Content.fromParts(
                    Part.fromText("An office group photo, funny faces."),
                    Part.fromBytes(Files.readAllBytes(Path.of("person1.png")), "image/png"),
                    Part.fromBytes(Files.readAllBytes(Path.of("person2.png")), "image/png"),
                    Part.fromBytes(Files.readAllBytes(Path.of("person3.png")), "image/png")
                ), config);

            for (Part part : response.parts()) {
                if (part.text().isPresent()) {
                    System.out.println(part.text().get());
                } else if (part.inlineData().isPresent()) {
                    var blob = part.inlineData().get();
                    if (blob.data().isPresent()) {
                        Files.write(Paths.get("group_photo.png"), blob.data().get());
                    }
                }
            }
        }
    }
}
```

### REST

```bash
curl -s -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-image-preview:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H 'Content-Type: application/json' \
  -d "{
    \"contents\": [{
      \"parts\":[
        {\"text\": \"An office group photo\"},
        {\"inline_data\": {\"mime_type\":\"image/png\", \"data\": \"<BASE64_IMG_1>\"}},
        {\"inline_data\": {\"mime_type\":\"image/png\", \"data\": \"<BASE64_IMG_2>\"}},
        {\"inline_data\": {\"mime_type\":\"image/png\", \"data\": \"<BASE64_IMG_3>\"}}
      ]
    }],
    \"generationConfig\": {
      \"responseModalities\": [\"TEXT\", \"IMAGE\"],
      \"imageConfig\": {\"aspectRatio\": \"5:4\", \"imageSize\": \"2K\"}
    }
  }"
```

---

## 5. Google Search Grounding

### REST

```bash
curl -s -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-image-preview:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "contents": [{"parts": [{"text": "Visualize the current weather forecast for Seoul"}]}],
    "tools": [{"google_search": {}}],
    "generationConfig": {
      "responseModalities": ["TEXT", "IMAGE"],
      "imageConfig": {"aspectRatio": "16:9"}
    }
  }'
```

### Google Image Search Grounding (REST)

```bash
curl -s -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-image-preview:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "contents": [{"parts": [{"text": "A detailed painting of a Timareta butterfly"}]}],
    "tools": [{"google_search": {"searchTypes": {"webSearch": {}, "imageSearch": {}}}}],
    "generationConfig": {"responseModalities": ["IMAGE"]}
  }'
```
