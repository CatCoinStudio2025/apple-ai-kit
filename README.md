# Apple AI Kit

A modular, headless AI framework for Apple platforms built with Swift 6. Designed to process natural language queries, route intents to tools, and generate responses using on-device LLMs.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                        App Layer                          │
│   (prompt engineering, language detection, fallback logic)  │
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
└─────────────────────────────────────────────────────────┘
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
| `NLUCore` | Intent classification, entity extraction, sentence embedding |
| `ToolRouter` | Routes parsed queries to registered tools |
| `ResponseEngine` | Builds structured `ResponseData` from query + tool result |
| `LLMEngine` | Headless protocol for LLM generation |
| `LLMEngineApple` | Apple Foundation Model implementation (macOS 26.0+) |

## Requirements

- **Swift 6.0+**
- **macOS 15.0+** (for development)
- **macOS 26.0+** (for Apple Foundation Model runtime)
- **Xcode 26+**

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

@available(macOS 26.0, *)
let app = AppleBaseLMApp(
    systemPrompt: "You are a helpful assistant."
)!

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
    func generate(prompt: String) async throws -> String
    var modelName: String { get }
}
```

### 5. Language Detection

Automatically detects user language and instructs LLM to respond in the same language:

```swift
let language = app.detectLanguage(from: "Xin chào, tôi muốn đặt một căn phòng")
// → "vi"
```

## Platform Availability

| Feature | macOS | iOS |
|---------|-------|-----|
| NLUCore | ✅ 15+ | ✅ 16+ |
| ToolRouter | ✅ 15+ | ✅ 16+ |
| ResponseEngine | ✅ 15+ | ✅ 16+ |
| LLMEngine | ✅ 15+ | ✅ 16+ |
| LLMEngineApple | ✅ 26.0+ | ✅ 26.0+ |

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
