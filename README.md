# Apple AI Kit

A modular, headless AI framework for Apple platforms built with Swift 6. Designed to process natural language queries, route intents to tools, generate responses using on-device LLMs, with support for speech recognition, speech synthesis, and vision capabilities.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                        App Layer                          │
│   AppleBaseLMApp (orchestration, API, speech synthesis)    │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│                       NLUCore                            │
│   IntentClassification  EntityExtraction  SentenceEmbedding│
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│                     ToolRouter                           │
│              Route intent → tool execution                │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│                   ResponseEngine                         │
│              Build structured ResponseData                 │
└──────────────────────┬──────────────────────────────────┘
                       │
┌─────────────────────────────────────────────────────────┐
│                       LLMEngine                          │
│              Headless LLM interface (protocol)          │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│                    LLMEngineApple                       │
│           Apple Foundation Model implementation          │
│                    (macOS 26.0+)                        │
└─────────────────────────────────────────────────────────┘
```

## Modules

| Module | Description |
|--------|-------------|
| `NLUCore` | Intent classification, entity extraction, sentence embedding, context memory |
| `ToolRouter` | Routes parsed queries to registered tools |
| `ResponseEngine` | Builds structured `ResponseData` from query + tool result |
| `LLMEngine` | Headless protocol for LLM generation |
| `LLMEngineApple` | Apple Foundation Model implementation (macOS 26.0+) |
| `SpeechCore` | Real-time speech recognition from microphone |
| `AudioCore` | Speech synthesis (text-to-speech) with multi-language support |
| `VisionCore` | Image analysis and understanding |
| `APIServer` | HTTP server for external API access |

## Requirements

- **Swift 6.0+**
- **macOS 15.0+** (for development)
- **macOS 26.0+** (for Apple Foundation Model runtime)
- **Xcode 26+**

## Project Structure

```
apple-ai-kit/
├── App/
│   └── App/
│       ├── AppleBaseLMApp.swift      # Main orchestrator
│       ├── AppDelegate.swift          # App lifecycle
│       └── Views/
│           └── ChatTestView.swift     # Test UI
└── Sources/
    ├── NLUCore/                       # Natural language understanding
    ├── ToolRouter/                    # Intent routing
    ├── ResponseEngine/                # Response generation
    ├── LLMEngine/                      # LLM protocol
    ├── LLMEngineApple/                 # Apple Foundation Model
    ├── SpeechCore/                     # Speech recognition
    ├── AudioCore/                      # Speech synthesis
    ├── VisionCore/                     # Image analysis
    └── APIServer/                      # HTTP API server
```

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourname/apple-ai-kit.git", from: "0.0.1")
]
```

### Or via Xcode

1. File → Add Package Dependencies
2. Paste repository URL
3. Add to your target

## Quick Start

```swift
import NLUCore
import ToolRouter
import ResponseEngine
import LLMEngine
import LLMEngineApple
import SpeechCore
import AudioCore

@available(macOS 26.0, *)
let app = AppleBaseLMApp(
    systemPrompt: "You are a helpful assistant."
)

let response = await app.processQuery("What is the capital of France?")
print(response)
```

## Framework Usage

### 1. NLUCore

```swift
let nluCore = NLUCore()

let parsed = try await nluCore.parse("Book a flight to Tokyo")
// parsed.intent    → .createOrder
// parsed.entities  → [Entity(type: .location, value: "Tokyo")]
```

### 2. ToolRouter

```swift
let toolRouter = ToolRouter()

struct FlightBookingTool: ToolProtocol {
    let intent: Intent = .createOrder

    func execute(input: ToolInput) async throws -> ToolOutput {
        return ToolOutput(message: "Flight booked to \(input.entities.first?.value ?? "unknown")")
    }
}

toolRouter.register(FlightBookingTool())

let result = try await toolRouter.route(parsedQuery)
```

### 3. ResponseEngine

```swift
let responseEngine = ResponseEngine()

let responseData = responseEngine.buildResponseData(
    from: parsedQuery,
    toolResult: toolOutput
)
```

### 4. LLMEngine Protocol

Implement the protocol to add your own LLM:

```swift
public protocol LLMEngineProtocol: Sendable {
    func chat(messages: [ChatMessage], config: GenerationConfig?) async throws -> ChatResponse
    var modelName: String { get }
}
```

### 5. Speech Recognition

```swift
let speechService = SpeechRecognitionServiceImpl()

let status = await speechService.requestAuthorization()
// .authorized | .denied | .notDetermined

try await speechService.startLiveRecognition { text, isFinal in
    print("Recognized: \(text)")
    if isFinal {
        print("Final result")
    }
}

await speechService.stopLiveRecognition()
```

### 6. Speech Synthesis

```swift
let synthesisService = SpeechSynthesisServiceImpl()

await synthesisService.speak("Hello world", language: "en")
await synthesisService.stop()
await synthesisService.pause()
```

### 7. Vision

```swift
let visionService = VisionImageAnalysisService()
let description = try await visionService.analyze(imageData: imageData)
```

### 8. Language Detection

Automatically detects user language and instructs LLM to respond in the same language:

```swift
let language = app.detectLanguage(from: "Xin chào, tôi muốn đặt một căn phòng")
// → "vi"
```

### 9. Conversation Management

```swift
let conversationId = app.startConversation()

let response1 = await app.processQuery(conversationId: conversationId, text: "Book a flight")
let response2 = await app.processQuery(conversationId: conversationId, text: "To Tokyo")

app.endConversation(conversationId)
```

### 10. HTTP API Server

```swift
try await app.startServer(port: 8080)
app.stopServer()
```

## Platform Availability

| Feature | macOS | iOS |
|---------|-------|-----|
| NLUCore | ✅ 15+ | ✅ 16+ |
| ToolRouter | ✅ 15+ | ✅ 16+ |
| ResponseEngine | ✅ 15+ | ✅ 16+ |
| LLMEngine | ✅ 15+ | ✅ 16+ |
| LLMEngineApple | ✅ 26.0+ | ✅ 26.0+ |
| SpeechCore | ✅ 15+ | ✅ 16+ |
| AudioCore | ✅ 15+ | ✅ 16+ |
| VisionCore | ✅ 15+ | ✅ 16+ |
| APIServer | ✅ 15+ | ✅ 16+ |

## Fallback Behavior

- **LLM available** → LLM generates natural language response
- **LLM unavailable** → Returns `toolResult.message` (text fallback)
- **Tool not found** → Returns graceful message in user's language

## Testing

```bash
swift test --package-path Sources/NLUCore
swift test --package-path Sources/ToolRouter
swift test --package-path Sources/ResponseEngine
```

## License

MIT License - see [LICENSE](LICENSE) file.
