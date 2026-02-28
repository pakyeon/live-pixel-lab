# Nano Banana 이미지 생성 가이드

## 개요

**Nano Banana**는 Gemini API의 네이티브 이미지 생성 기능입니다. Gemini는 텍스트, 이미지, 또는 둘의 조합으로 이미지를 생성하고 처리할 수 있습니다. 이를 통해 전례 없는 수준의 제어로 시각 자료를 생성, 편집 및 반복할 수 있습니다.

## 이용 가능한 모델

Nano Banana는 Gemini API에서 사용 가능한 3가지 모델을 지칭합니다:

### 1. Nano Banana 2
- **모델 ID**: `gemini-3.1-flash-image-preview`
- **용도**: Gemini 3.1 Flash Image Preview 모델
- **특징**: 고효율 모델로 속도 최적화, 대량 개발자 사용 사례에 최적화

### 2. Nano Banana Pro
- **모델 ID**: `gemini-3-pro-image-preview`
- **용도**: Gemini 3 Pro Image Preview 모델
- **특징**: 전문 자산 제작을 위해 설계, 고급 추론(Thinking)으로 복잡한 지시 사항 및 고충실도 텍스트 렌더링

### 3. Nano Banana
- **모델 ID**: `gemini-2.5-flash-image`
- **용도**: Gemini 2.5 Flash Image 모델
- **특징**: 속도와 효율성 최적화, 고용량 저지연 작업에 최적화

> **참고**: 모든 생성 이미지에는 SynthID 워터마크가 포함됩니다.

---

## 이미지 생성 (Text-to-Image)

### Python

```python
from google import genai
from google.genai import types
from PIL import Image

client = genai.Client()

prompt = ("Create a picture of a nano banana dish in a fancy restaurant with a Gemini theme")
response = client.models.generate_content(
    model="gemini-3.1-flash-image-preview",
    contents=[prompt],
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

async function main() {
    const ai = new GoogleGenAI({});

    const prompt = "Create a picture of a nano banana dish in a fancy restaurant with a Gemini theme";

    const response = await ai.models.generateContent({
        model: "gemini-3.1-flash-image-preview",
        contents: prompt,
    });

    for (const part of response.candidates[0].content.parts) {
        if (part.text) {
            console.log(part.text);
        } else if (part.inlineData) {
            const imageData = part.inlineData.data;
            const buffer = Buffer.from(imageData, "base64");
            fs.writeFileSync("gemini-native-image.png", buffer);
            console.log("Image saved as gemini-native-image.png");
        }
    }
}

main();
```

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
        genai.Text("Create a picture of a nano banana dish in a " +
            " fancy restaurant with a Gemini theme"),
    )

    for _, part := range result.Candidates[0].Content.Parts {
        if part.Text != "" {
            fmt.Println(part.Text)
        } else if part.InlineData != nil {
            imageBytes := part.InlineData.Data
            outputFilename := "gemini_generated_image.png"
            _ = os.WriteFile(outputFilename, imageBytes, 0644)
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
                "Create a picture of a nano banana dish in a fancy restaurant with a Gemini theme",
                config);

            for (Part part : response.parts()) {
                if (part.text().isPresent()) {
                    System.out.println(part.text().get());
                } else if (part.inlineData().isPresent()) {
                    var blob = part.inlineData().get();
                    if (blob.data().isPresent()) {
                        Files.write(Paths.get("_01_generated_image.png"), blob.data().get());
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
  -H "Content-Type: application/json" \
  -d '{
    "contents": [{
      "parts": [
        {"text": "Create a picture of a nano banana dish in a fancy restaurant with a Gemini theme"}
      ]
    }]
  }'
```

---

## 이미지 편집 (Text-and-Image-to-Image)

> **주의**: 업로드하는 모든 이미지에 필요한 권리가 있는지 확인하세요. 다른 사람의 권리를 침해하는 내용, 특히 기만하거나 괴롭히거나 해를 끼치는 동영상이나 이미지는 생성하지 마세요. 이 생성형 AI 서비스 사용은 금지된 사용 정책의 적용을 받습니다.

텍스트 프롬프트를 사용하여 이미지를 제공하고 요소를 추가, 제거 또는 수정하거나, 스타일을 변경하거나, 색상 등급을 조정할 수 있습니다.

다음 예제는 base64 인코딩된 이미지 업로드를 시연합니다. 여러 이미지, 더 큰 페이로드, 지원되는 MIME 유형은 이미지 이해 페이지를 확인하세요.

### Python

```python
from google import genai
from google.genai import types
from PIL import Image

client = genai.Client()

prompt = (
    "Create a picture of my cat eating a nano-banana in a "
    "fancy restaurant under the Gemini constellation"
)

image = Image.open("/path/to/cat_image.png")

response = client.models.generate_content(
    model="gemini-3.1-flash-image-preview",
    contents=[prompt, image],
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

async function main() {
    const ai = new GoogleGenAI({});

    const imagePath = "path/to/cat_image.png";
    const imageData = fs.readFileSync(imagePath);
    const base64Image = imageData.toString("base64");

    const prompt = [
        {
            text: "Create a picture of my cat eating a nano-banana in a" +
                "fancy restaurant under the Gemini constellation"
        },
        {
            inlineData: {
                mimeType: "image/png",
                data: base64Image,
            },
        },
    ];

    const response = await ai.models.generateContent({
        model: "gemini-3.1-flash-image-preview",
        contents: prompt,
    });

    for (const part of response.candidates[0].content.parts) {
        if (part.text) {
            console.log(part.text);
        } else if (part.inlineData) {
            const imageData = part.inlineData.data;
            const buffer = Buffer.from(imageData, "base64");
            fs.writeFileSync("gemini-native-image.png", buffer);
            console.log("Image saved as gemini-native-image.png");
        }
    }
}

main();
```

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

    imagePath := "/path/to/cat_image.png"
    imgData, _ := os.ReadFile(imagePath)

    parts := []*genai.Part{
        genai.NewPartFromText("Create a picture of my cat eating a nano-banana in a fancy restaurant under the Gemini constellation"),
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
            imageBytes := part.InlineData.Data
            outputFilename := "gemini_generated_image.png"
            _ = os.WriteFile(outputFilename, imageBytes, 0644)
        }
    }
}
```

### Java

```java
import com.google.genai.Client;
import com.google.genai.types.Content;
import com.google.genai.types.GenerateContentConfig;
import com.google.genai.types.GenerateContentResponse;
import com.google.genai.types.Part;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

public class TextAndImageToImage {
    public static void main(String[] args) throws IOException {
        try (Client client = new Client()) {
            GenerateContentConfig config = GenerateContentConfig.builder()
                .responseModalities("TEXT", "IMAGE")
                .build();

            GenerateContentResponse response = client.models.generateContent(
                "gemini-3.1-flash-image-preview",
                Content.fromParts(
                    Part.fromText("""
                        Create a picture of my cat eating a nano-banana in
                        a fancy restaurant under the Gemini constellation
                        """),
                    Part.fromBytes(
                        Files.readAllBytes(
                            Path.of("src/main/resources/cat.jpg")),
                        "image/jpeg")),
                config);

            for (Part part : response.parts()) {
                if (part.text().isPresent()) {
                    System.out.println(part.text().get());
                } else if (part.inlineData().isPresent()) {
                    var blob = part.inlineData().get();
                    if (blob.data().isPresent()) {
                        Files.write(Paths.get("gemini_generated_image.png"), blob.data().get());
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
        {\"text\": \"'Create a picture of my cat eating a nano-banana in a fancy restaurant under the Gemini constellation\"},
        {
          \"inline_data\": {
            \"mime_type\":\"image/jpeg\",
            \"data\": \"<BASE64_IMAGE_DATA>\"
          }
        }
      ]
    }]
  }"
```

---

## 다중 턴 이미지 편집 (Multi-turn Image Editing)

이미지를 계속 생성하고 편집합니다. 채팅 또는 다중 턴 대화는 이미지를 반복하는 권장 방법입니다. 다음 예제는 광합성에 대한 인포그래픽을 생성하는 프롬프트를 보여줍니다.

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

message = "Create a vibrant infographic that explains photosynthesis as if it were a recipe for a plant's favorite food. Show the \"ingredients\" (sunlight, water, CO2) and the \"finished dish\" (sugar/energy). The style should be like a page from a colorful kids' cookbook, suitable for a 4th grader."

response = chat.send_message(message)

for part in response.parts:
    if part.text is not None:
        print(part.text)
    elif image := part.as_image():
        image.save("photosynthesis.png")
```

### JavaScript

```javascript
import { GoogleGenAI } from "@google/genai";

const ai = new GoogleGenAI({});

async function main() {
    const chat = ai.chats.create({
        model: "gemini-3.1-flash-image-preview",
        config: {
            responseModalities: ['TEXT', 'IMAGE'],
            tools: [{ googleSearch: {} }],
        },
    });

    await main();

    const message = "Create a vibrant infographic that explains photosynthesis as if it were a recipe for a plant's favorite food. Show the \"ingredients\" (sunlight, water, CO2) and the \"finished dish\" (sugar/energy). The style should be like a page from a colorful kids' cookbook, suitable for a 4th grader."

    let response = await chat.sendMessage({ message });

    for (const part of response.candidates[0].content.parts) {
        if (part.text) {
            console.log(part.text);
        } else if (part.inlineData) {
            const imageData = part.inlineData.data;
            const buffer = Buffer.from(imageData, "base64");
            fs.writeFileSync("photosynthesis.png", buffer);
            console.log("Image saved as photosynthesis.png");
        }
    }
}
```

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

    message := "Create a vibrant infographic that explains photosynthesis as if it were a recipe for a plant's favorite food. Show the \"ingredients\" (sunlight, water, CO2) and the \"finished dish\" (sugar/energy). The style should be like a page from a colorful kids' cookbook, suitable for a 4th grader."

    resp, err := chat.SendMessage(ctx, genai.Text(message))
    if err != nil {
        log.Fatal(err)
    }

    for _, part := range resp.Candidates[0].Content.Parts {
        if txt, ok := part.(genai.Text); ok {
            fmt.Printf("%s", string(txt))
        } else if img, ok := part.(genai.ImageData); ok {
            err := os.WriteFile("photosynthesis.png", img.Data, 0644)
            if err != nil {
                log.Fatal(err)
            }
        }
    }
}
```

### Java

```java
import com.google.genai.Chat;
import com.google.genai.Client;
import com.google.genai.types.Content;
import com.google.genai.types.GenerateContentConfig;
import com.google.genai.types.GenerateContentResponse;
import com.google.genai.types.GoogleSearch;
import com.google.genai.types.ImageConfig;
import com.google.genai.types.Part;
import com.google.genai.types.RetrievalConfig;
import com.google.genai.types.Tool;
import com.google.genai.types.ToolConfig;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

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

            GenerateContentResponse response = chat.sendMessage("""
                Create a vibrant infographic that explains photosynthesis
                as if it were a recipe for a plant's favorite food.
                Show the "ingredients" (sunlight, water, CO2)
                and the "finished dish" (sugar/energy).
                The style should be like a page from a colorful
                kids' cookbook, suitable for a 4th grader.
                """);

            for (Part part : response.parts()) {
                if (part.text().isPresent()) {
                    System.out.println(part.text().get());
                } else if (part.inlineData().isPresent()) {
                    var blob = part.inlineData().get();
                    if (blob.data().isPresent()) {
                        Files.write(Paths.get("photosynthesis.png"), blob.data().get());
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
  -H "Content-Type: application/json" \
  -d '{
    "contents": [{
      "role": "user",
      "parts": [
        {"text": "Create a vibrant infographic that explains photosynthesis as if it were a recipe for a plants favorite food. Show the \"ingredients\" (sunlight, water, CO2) and the \"finished dish\" (sugar/energy). The style should be like a page from a colorful kids cookbook, suitable for a 4th grader."}
      ]
    }],
    "generationConfig": {
      "responseModalities": ["TEXT", "IMAGE"]
    }
  }'
```

### 이미지 언어 변경

같은 채팅을 사용하여 그래픽의 언어를 스페인어로 변경할 수 있습니다.

#### Python

```python
message = "Update this infographic to be in Spanish. Do not change any other elements of the image."
aspect_ratio = "16:9" # "1:1","1:4","1:8","2:3","3:2","3:4","4:1","4:3","4:5","5:4","8:1","9:16","16:9","21:9"
resolution = "2K" # "512px", "1K", "2K", "4K"

response = chat.send_message(message,
    config=types.GenerateContentConfig(
        image_config=types.ImageConfig(
            aspect_ratio=aspect_ratio,
            image_size=resolution
        ),
    ))

for part in response.parts:
    if part.text is not None:
        print(part.text)
    elif image := part.as_image():
        image.save("photosynthesis_spanish.png")
```

#### JavaScript

```javascript
const message = 'Update this infographic to be in Spanish. Do not change any other elements of the image.';
const aspectRatio = '16:9';
const resolution = '2K';

let response = await chat.sendMessage({
    message,
    config: {
        responseModalities: ['TEXT', 'IMAGE'],
        imageConfig: {
            aspectRatio: aspectRatio,
            imageSize: resolution,
        },
        tools: [{ googleSearch: {} }],
    },
});

for (const part of response.candidates[0].content.parts) {
    if (part.text) {
        console.log(part.text);
    } else if (part.inlineData) {
        const imageData = part.inlineData.data;
        const buffer = Buffer.from(imageData, "base64");
        fs.writeFileSync("photosynthesis2.png", buffer);
        console.log("Image saved as photosynthesis2.png");
    }
}
```

---

## Gemini 3 이미지 모델의 신규 기능

Gemini 3는 최고 수준의 이미지 생성 및 편집 모델을 제공합니다. Gemini 3.1 Flash Image는 속도와 대량 사용 사례에 최적화되어 있고, Gemini 3 Pro Image는 전문 자산 제작에 최적화되어 있습니다. 고급 추론을 통해 가장 도전적인 워크플로우를 제공하도록 설계되었으며, 복잡한 다중 턴 생성 및 수정 작업을 잘 처리합니다.

### 주요 기능

- **고해상도 출력**: 1K, 2K, 4K 시각 자료에 대한 내장 생성 기능. Gemini 3.1 Flash Image는 더 작은 512px(0.5K) 해상도를 추가합니다.

- **고급 텍스트 렌더링**: 인포그래픽, 메뉴, 다이어그램 및 마케팅 자산을 위한 읽기 쉬운 스타일화된 텍스트를 생성할 수 있습니다.

- **Google Search를 통한 Grounding**: 모델은 Google Search를 도구로 사용하여 사실을 확인하고 실시간 데이터를 기반으로 이미지를 생성할 수 있습니다(예: 현재 날씨 지도, 주식 차트, 최근 이벤트). Gemini 3.1 Flash Image는 웹 검색과 함께 Google 이미지 검색 Grounding 통합을 추가합니다.

- **Thinking 모드**: 모델은 "thinking" 프로세스를 활용하여 복잡한 프롬프트를 통해 추론합니다. 최종 고품질 출력을 생성하기 전에 구성을 개선하기 위해 임시 "사고 이미지"(백엔드에서 볼 수 있지만 요금이 부과되지 않음)를 생성합니다.

- **최대 14개의 참조 이미지**: 이제 최대 14개의 참조 이미지를 혼합하여 최종 이미지를 생성할 수 있습니다.

- **새로운 종횡비**: Gemini 3.1 Flash Image Preview는 1:4, 4:1, 1:8, 8:1 종횡비를 추가합니다.

---

## 최대 14개의 참조 이미지 사용

Gemini 3 이미지 모델을 사용하면 최대 14개의 참조 이미지를 혼합할 수 있습니다. 이 14개의 이미지는 다음을 포함할 수 있습니다:

| 종류 | Gemini 3.1 Flash Image Preview | Gemini 3 Pro Image Preview |
|------|------|------|
| 최종 이미지에 포함할 높은 충실도의 객체 이미지 | 최대 10개 | 최대 6개 |
| 문자 일관성을 유지하기 위한 문자 이미지 | 최대 4개 | 최대 5개 |

### Python

```python
from google import genai
from google.genai import types
from PIL import Image

prompt = "An office group photo of these people, they are making funny faces."
aspect_ratio = "5:4" # "1:1","1:4","1:8","2:3","3:2","3:4","4:1","4:3","4:5","5:4","8:1","9:16","16:9","21:9"
resolution = "2K" # "512px", "1K", "2K", "4K"

client = genai.Client()

response = client.models.generate_content(
    model="gemini-3.1-flash-image-preview",
    contents=[
        prompt,
        Image.open('person1.png'),
        Image.open('person2.png'),
        Image.open('person3.png'),
        Image.open('person4.png'),
        Image.open('person5.png'),
    ],
    config=types.GenerateContentConfig(
        response_modalities=['TEXT', 'IMAGE'],
        image_config=types.ImageConfig(
            aspect_ratio=aspect_ratio,
            image_size=resolution
        ),
    )
)

for part in response.parts:
    if part.text is not None:
        print(part.text)
    elif image := part.as_image():
        image.save("office.png")
```

### JavaScript

```javascript
import { GoogleGenAI } from "@google/genai";
import * as fs from "node:fs";

async function main() {
    const ai = new GoogleGenAI({});

    const prompt = 'An office group photo of these people, they are making funny faces.';
    const aspectRatio = '5:4';
    const resolution = '2K';

    const contents = [
        { text: prompt },
        {
            inlineData: {
                mimeType: "image/jpeg",
                data: base64ImageFile1,
            },
        },
        {
            inlineData: {
                mimeType: "image/jpeg",
                data: base64ImageFile2,
            },
        },
        {
            inlineData: {
                mimeType: "image/jpeg",
                data: base64ImageFile3,
            },
        },
        {
            inlineData: {
                mimeType: "image/jpeg",
                data: base64ImageFile4,
            },
        },
        {
            inlineData: {
                mimeType: "image/jpeg",
                data: base64ImageFile5,
            },
        }
    ];

    const response = await ai.models.generateContent({
        model: 'gemini-3.1-flash-image-preview',
        contents: contents,
        config: {
            responseModalities: ['TEXT', 'IMAGE'],
            imageConfig: {
                aspectRatio: aspectRatio,
                imageSize: resolution,
            },
        },
    });

    for (const part of response.candidates[0].content.parts) {
        if (part.text) {
            console.log(part.text);
        } else if (part.inlineData) {
            const imageData = part.inlineData.data;
            const buffer = Buffer.from(imageData, "base64");
            fs.writeFileSync("image.png", buffer);
            console.log("Image saved as image.png");
        }
    }
}

main();
```

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

    img1, err := os.ReadFile("person1.png")
    if err != nil { log.Fatal(err) }
    img2, err := os.ReadFile("person2.png")
    if err != nil { log.Fatal(err) }
    img3, err := os.ReadFile("person3.png")
    if err != nil { log.Fatal(err) }
    img4, err := os.ReadFile("person4.png")
    if err != nil { log.Fatal(err) }
    img5, err := os.ReadFile("person5.png")
    if err != nil { log.Fatal(err) }

    parts := []genai.Part{
        genai.Text("An office group photo of these people, they are making funny faces."),
        genai.ImageData{MIMEType: "image/png", Data: img1},
        genai.ImageData{MIMEType: "image/png", Data: img2},
        genai.ImageData{MIMEType: "image/png", Data: img3},
        genai.ImageData{MIMEType: "image/png", Data: img4},
        genai.ImageData{MIMEType: "image/png", Data: img5},
    }

    resp, err := model.GenerateContent(ctx, parts...)
    if err != nil {
        log.Fatal(err)
    }

    for _, part := range resp.Candidates[0].Content.Parts {
        if txt, ok := part.(genai.Text); ok {
            fmt.Printf("%s", string(txt))
        } else if img, ok := part.(genai.ImageData); ok {
            err := os.WriteFile("office.png", img.Data, 0644)
            if err != nil {
                log.Fatal(err)
            }
        }
    }
}
```

### Java

```java
import com.google.genai.Client;
import com.google.genai.types.Content;
import com.google.genai.types.GenerateContentConfig;
import com.google.genai.types.GenerateContentResponse;
import com.google.genai.types.ImageConfig;
import com.google.genai.types.Part;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

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
                    Part.fromText("An office group photo of these people, they are making funny faces."),
                    Part.fromBytes(Files.readAllBytes(Path.of("person1.png")), "image/png"),
                    Part.fromBytes(Files.readAllBytes(Path.of("person2.png")), "image/png"),
                    Part.fromBytes(Files.readAllBytes(Path.of("person3.png")), "image/png"),
                    Part.fromBytes(Files.readAllBytes(Path.of("person4.png")), "image/png"),
                    Part.fromBytes(Files.readAllBytes(Path.of("person5.png")), "image/png")
                ), config);

            for (Part part : response.parts()) {
                if (part.text().isPresent()) {
                    System.out.println(part.text().get());
                } else if (part.inlineData().isPresent()) {
                    var blob = part.inlineData().get();
                    if (blob.data().isPresent()) {
                        Files.write(Paths.get("office.png"), blob.data().get());
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
        {\"text\": \"An office group photo of these people, they are making funny faces.\"},
        {\"inline_data\": {\"mime_type\":\"image/png\", \"data\": \"<BASE64_DATA_IMG_1>\"}},
        {\"inline_data\": {\"mime_type\":\"image/png\", \"data\": \"<BASE64_DATA_IMG_2>\"}},
        {\"inline_data\": {\"mime_type\":\"image/png\", \"data\": \"<BASE64_DATA_IMG_3>\"}},
        {\"inline_data\": {\"mime_type\":\"image/png\", \"data\": \"<BASE64_DATA_IMG_4>\"}},
        {\"inline_data\": {\"mime_type\":\"image/png\", \"data\": \"<BASE64_DATA_IMG_5>\"}}
      ]
    }],
    \"generationConfig\": {
      \"responseModalities\": [\"TEXT\", \"IMAGE\"],
      \"imageConfig\": {
        \"aspectRatio\": \"5:4\",
        \"imageSize\": \"2K\"
      }
    }
  }"
```

---

## Google Search Grounding

Google Search 도구를 사용하여 실시간 정보(예: 날씨 예보, 주식 차트, 최근 이벤트)를 기반으로 이미지를 생성합니다.

Google Search를 통한 Grounding으로 이미지를 생성할 때, 이미지 기반 검색 결과는 생성 모델에 전달되지 않으며 응답에서 제외됩니다.

### Python

```python
from google import genai
prompt = "Visualize the current weather forecast for the next 5 days in San Francisco as a clean, modern weather chart. Add a visual on what I should wear each day"
aspect_ratio = "16:9" # "1:1","1:4","1:8","2:3","3:2","3:4","4:1","4:3","4:5","5:4","8:1","9:16","16:9","21:9"

client = genai.Client()

response = client.models.generate_content(
    model="gemini-3.1-flash-image-preview",
    contents=prompt,
    config=types.GenerateContentConfig(
        response_modalities=['Text', 'Image'],
        image_config=types.ImageConfig(
            aspect_ratio=aspect_ratio,
        ),
        tools=[{"google_search": {}}]
    )
)

for part in response.parts:
    if part.text is not None:
        print(part.text)
    elif image := part.as_image():
        image.save("weather.png")
```

### REST

```bash
curl -s -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-image-preview:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "contents": [{"parts": [{"text": "Visualize the current weather forecast for the next 5 days in San Francisco as a clean, modern weather chart. Add a visual on what I should wear each day"}]}],
    "tools": [{"google_search": {}}],
    "generationConfig": {
      "responseModalities": ["TEXT", "IMAGE"],
      "imageConfig": {"aspectRatio": "16:9"}
    }
  }'
```

### 응답 메타데이터

응답에는 `groundingMetadata`가 포함되어 있으며, 다음의 필수 필드를 포함합니다:

- **searchEntryPoint**: 필수 검색 제안을 렌더링하기 위한 HTML 및 CSS를 포함합니다.
- **groundingChunks**: 생성된 이미지를 근거로 한 상위 3개의 웹 소스를 반환합니다.

---

## Google 이미지 검색을 통한 Grounding (3.1 Flash)

Google 이미지 검색을 통한 Grounding을 사용하면 모델이 Google 이미지 검색을 통해 검색된 웹 이미지를 이미지 생성을 위한 시각적 컨텍스트로 사용할 수 있습니다. 이미지 검색은 기존 Grounding with Google Search 도구 내의 새로운 검색 유형이며, 웹 검색과 함께 작동합니다.

이미지 검색을 활성화하려면 API 요청에서 `google_search` 도구를 구성하고 `search_types` 객체 내에서 `image_search`를 지정합니다. 이미지 검색은 웹 검색과 독립적으로 또는 함께 사용할 수 있습니다.

### Python

```python
from google import genai
prompt = "A detailed painting of a Timareta butterfly resting on a flower"

client = genai.Client()

response = client.models.generate_content(
    model="gemini-3.1-flash-image-preview",
    contents=prompt,
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

# Display grounding sources if available
if response.candidates and response.candidates[0].grounding_metadata and response.candidates[0].grounding_metadata.search_entry_point:
    display(HTML(response.candidates[0].grounding_metadata.search_entry_point.rendered_content))
```

### REST

```bash
curl -s -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-image-preview:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "contents": [{"parts": [{"text": "A detailed painting of a Timareta butterfly resting on a flower"}]}],
    "tools": [{"google_search": {"searchTypes": {"webSearch": {}, "imageSearch": {}}}}],
    "generationConfig": {
      "responseModalities": ["IMAGE"]
    }
  }'
```

### 표시 요구 사항

이미지 검색 내에서 Google Search를 통한 Grounding을 사용할 때, 다음 조건을 준수해야 합니다:

- **출처 표시**: 사용자가 링크로 인식할 수 있는 방식으로 소스 이미지가 포함된 웹페이지에 대한 링크를 제공해야 합니다(이미지 파일 자체가 아닌 "포함 페이지").

- **직접 탐색**: 소스 이미지도 표시하려는 경우, 소스 이미지에서 포함 소스 웹페이지로 직접 단일 클릭 경로를 제공해야 합니다. 지연 또는 최종 사용자의 소스 웹페이지 접근을 추상화하는 다른 구현은 허용되지 않습니다(예: 다중 클릭 경로 또는 중간 이미지 뷰어 사용 포함).

---

## 고해상도로 이미지 생성 (최대 4K)

Gemini 3 이미지 모델은 기본적으로 1K 이미지를 생성하지만, 2K, 4K, 512px(0.5K)(Gemini 3.1 Flash Image만 해당) 이미지도 출력할 수 있습니다. 더 높은 해상도 자산을 생성하려면 `generation_config`에서 `image_size`를 지정합니다.

대문자 'K'를 사용해야 합니다(예: 512px(0.5K), 1K, 2K, 4K). 소문자 매개변수(예: 1k)는 거부됩니다.

### 사용 가능한 해상도

- **512px** (0.5K) - Gemini 3.1 Flash Image Preview만 해당
- **1K** (기본값)
- **2K**
- **4K**

### 사용 가능한 종횡비

- 1:1 (정사각형)
- 4:3
- 3:2
- 16:9
- 21:9
- 9:16
- 1:4
- 4:1
- 1:8
- 8:1
- 2:3
- 3:4
- 4:5
- 5:4

---

## 예제 프롬프트 모음

### 1. 포토리얼리스틱 잡지 표지

```
"A photo of a glossy magazine cover, the minimal blue cover has the large bold words Nano Banana. 
The text is in a serif font and fills the view. No other text. In front of the text there is a portrait 
of a person in a sleek and minimal dress. She is playfully holding the number 2, which is the focal point. 
Put the issue number and 'Feb 2026' date in the corner along with a barcode. The magazine is on a shelf 
against an orange plastered wall, within a designer store."
```

### 2. 런던의 등각 미니어처 3D 장면

```
"Present a clear, 45° top-down isometric miniature 3D cartoon scene of London, featuring its most iconic 
landmarks and architectural elements. Use soft, refined textures with realistic PBR materials and gentle, 
lifelike lighting and shadows. Integrate the current weather conditions directly into the city environment 
to create an immersive atmospheric mood. Use a clean, minimalistic composition with a soft, solid-colored 
background. At the top-center, place the title 'London' in large bold text, a prominent weather icon 
beneath it, then the date (small text) and temperature (medium text)."
```

### 3. 초호텔 새 월페이퍼

```
"Use image search to find accurate images of a resplendent quetzal bird. Create a beautiful 3:2 wallpaper 
of this bird, with a natural top to bottom gradient and minimal composition."
```

### 4. 고급 향수 광고

```
"Put this logo on a high-end ad for a banana scented perfume. The logo is perfectly integrated into the bottle."
```

### 5. 카페 다양한 스타일 혼합

```
"A photo of an everyday scene at a busy cafe serving breakfast. In the foreground is an anime man with 
blue hair, one of the people is a pencil sketch, another is a claymation person."
```

### 6. 매거진에서의 뉘우스 기사

```
"Use search to find how the Gemini 3 Flash launch has been received. Use this information to write a 
short article about it (with headings). Return a photo of the article as it appeared in a design focused 
glossy magazine. It is a photo of a single folded over page, showing the article about Gemini 3 Flash. 
One hero photo. Headline in serif."
```

### 7. 귀여운 개 아이콘

```
"An icon representing a cute dog. The background is white. Make the icons in a colorful and tactile 3D 
style. No text."
```

### 8. 나노 바나나 2 정원

```
"Make a photo that is perfectly isometric. It is not a miniature, it is a captured photo that just happened 
to be perfectly isometric. It is a photo of a beautiful modern garden. There's a large 2 shaped pool and 
the words: Nano Banana 2."
```

---

## 모범 사례 (Best Practices)

1. **구체적인 설명**: "판타지 갑옷" 대신 "은박 리프 패턴이 새겨진 정교한 엘프 플레이트 갑옷"
2. **컨텍스트 제공**: "고급 미니멀 스킨케어 브랜드 로고"
3. **반복적인 개선**: "조명을 더 따뜻하게", "표정을 더 진지하게"
4. **단계적 지시**: 배경 → 전경 → 주요 요소 순서로 설명
5. **긍정적 네거티브**: "교통 표시 없는 한적한 거리"
6. **카메라 제어**: "와이드 앵글", "매크로 샷", "로우 앵글" 등 명시

---

## 시작하기

1. **API 키 설정**: `$GEMINI_API_KEY` 환경 변수 설정
2. **라이브러리 설치**: 해당 언어의 Google GenAI SDK 설치
3. **프롬프트 작성**: 원하는 이미지를 명확하게 설명
4. **생성 실행**: 코드 예제 중 선택하여 실행
5. **반복**: 원하는 결과를 얻을 때까지 프롬프트 수정

---

## 추가 리소스

- [Gemini API 문서](https://ai.google.dev/)
- [이미지 이해 가이드](https://ai.google.dev/gemini-api/docs/vision/)
- [Google Search Grounding](https://ai.google.dev/gemini-api/docs/grounding/)
- [AI Studio](https://aistudio.google.com)

