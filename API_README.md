# AppleAIKit API Server

## Mục lục

1. [Tổng quan](#1-tổng-quan)
2. [Kiến trúc kỹ thuật](#2-kiến-trúc-kỹ-thuật)
3. [Cách khởi động API Server](#3-cách-khởi-động-api-server)
4. [Endpoints](#4-endpoints)
5. [Định dạng request/response](#5-định-dạng-requestresponse)
6. [Ví dụ sử dụng](#6-ví-dụ-sử-dụng)
7. [Authentication](#7-authentication)
8. [Rate Limiting](#8-rate-limiting)
9. [Lỗi thường gặp](#9-lỗi-thường-gặp)

---

## 1. Tổng quan

AppleAIKit API Server là một HTTP server tích hợp sẵn trong ứng dụng, cho phép kết nối từ bên ngoài qua giao thức REST chuẩn OpenAI-compatible API.

**Thông tin kết nối mặc định:**
- **Host:** `0.0.0.0` (lắng nghe trên tất cả interfaces)
- **Port:** `8314`
- **Base URL:** `http://localhost:8314`
- **Protocol:** HTTP (chưa có HTTPS certificate)

---

## 2. Kiến trúc kỹ thuật

### 2.1 Kiến trúc tổng thể

```
Client (curl/app)  →  HTTP Server (Network.framework)
                           ↓
                    APIServer.HTTPServer
                           ↓
              ┌─────────────┴──────────────┐
              ↓                             ↓
        Chat Handler              Models Handler
              ↓                             ↓
      ┌───────┴────────┐                    ↓
      ↓                ↓              ModelInfo list
LLMEngine         ToolRouter
(Apple FM)        (Tool routing)
      ↓
  ChatResponse
      ↓
HTTP Response ← JSON encoded
```

### 2.2 Stack công nghệ

| Layer | Công nghệ | Mô tả |
|-------|-----------|--------|
| HTTP Server | `Network.framework` (NWListener) | Apple's native async networking, không cần thư viện ngoài |
| JSON Encoding | `JSONEncoder`/`JSONDecoder` | Foundation built-in |
| LLM | `FoundationModels` (Apple FM) | Apple Foundation Models |
| Threading | `DispatchQueue` | Concurrency control |
| Session | In-memory `[String: [ChatMessage]]` | Chat history per user session |

### 2.3 Source files

```
Sources/APIServer/
├── APIServer.swift       # HTTPServer class — HTTP handler, routing, lifecycle
└── APIModels.swift       # Request/Response structs — OpenAI-compatible models
```

### 2.4 Request flow

```
1. Client gửi HTTP request
        ↓
2. NWListener nhận connection
        ↓
3. receive() đọc raw bytes
        ↓
4. parseRequest() parse HTTP/1.1 format thủ công
        ↓
5. route() dispatch theo (method, path)
        ↓
6. Handler xử lý (Task async)
        ↓
7. Gọi LLM.chat() hoặc LLM.chatWithTools()
        ↓
8. JSONEncoder encode response
        ↓
9. send() gửi về client
        ↓
10. connection.cancel() đóng connection
```

---

## 3. Cách khởi động API Server

### 3.1 Từ ứng dụng (UI)

1. Mở ứng dụng AppleBaseLM
2. Nhấn nút **API** ở header (hình tròn xám/xanh)
3. Server khởi động → hiển thị "Server running at http://localhost:8314"
4. Nhấn lại để stop

### 3.2 Từ code

```swift
import APIServer

// Tạo server
let server = HTTPServer(
    host: "0.0.0.0",
    port: 8314,
    useTLS: false,
    llm: try AppleFoundationEngine()
)

// Start
try await server.start()

// Stop
server.stop()
```

### 3.3 Từ Terminal (kiểm tra)

```bash
# Health check
curl http://localhost:8314/health

# List models
curl http://localhost:8314/v1/models
```

---

## 4. Endpoints

### 4.1 `POST /v1/chat/completions`

**Mục đích:** Tạo chat completion

**Request body:**
```json
{
  "model": "string (required)",
  "messages": [
    {
      "role": "system | user | assistant | tool",
      "content": "string",
      "name": "string (optional)",
      "tool_call_id": "string (optional)",
      "tool_calls": []
    }
  ],
  "tools": [],
  "temperature": 0.7,
  "top_p": 1.0,
  "max_tokens": 1024,
  "stream": false,
  "seed": null,
  "stop": null,
  "presence_penalty": null,
  "frequency_penalty": null,
  "user": "string (optional - session ID)"
}
```

**Response:**
```json
{
  "id": "chatcmpl-xxx",
  "object": "chat.completion",
  "created": 1234567890,
  "model": "AppleFoundationModel",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "Hello!"
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 10,
    "completion_tokens": 5,
    "total_tokens": 15
  }
}
```

### 4.2 `GET /v1/models`

**Mục đích:** Danh sách models khả dụng

**Response:**
```json
{
  "object": "list",
  "data": [
    {
      "id": "AppleFoundationModel",
      "object": "model",
      "created": 1234567890,
      "owned_by": "apple"
    }
  ]
}
```

### 4.3 `GET /health`

**Mục đích:** Health check

**Response:**
```
OK
```

---

## 5. Định dạng Request/Response

### 5.1 Request headers bắt buộc

```
Content-Type: application/json
```

### 5.2 Response headers

```
Content-Type: application/json
Content-Length: <size>
```

### 5.3 Chat Message Roles

| Role | Mô tả |
|------|--------|
| `system` | Prompt hệ thống — thiết lập behavior |
| `user` | Tin nhắn người dùng |
| `assistant` | Phản hồi của AI |
| `tool` | Kết quả từ tool call |

### 5.4 Tool/Function Calling

```json
{
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "get_weather",
        "description": "Get current weather",
        "parameters": {
          "type": "object",
          "properties": {
            "location": {"type": "string"}
          },
          "required": ["location"]
        }
      }
    }
  ]
}
```

---

## 6. Ví dụ sử dụng

### 6.1 Curl

```bash
# Health check
curl http://localhost:8314/health

# List models
curl http://localhost:8314/v1/models

# Simple chat
curl -X POST http://localhost:8314/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "AppleFoundationModel",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "Hello!"}
    ]
  }'

# With temperature
curl -X POST http://localhost:8314/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "AppleFoundationModel",
    "messages": [{"role": "user", "content": "Tell me a joke"}],
    "temperature": 0.8,
    "max_tokens": 100
  }'

# Multi-turn conversation (session)
curl -X POST http://localhost:8314/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "AppleFoundationModel",
    "user": "user123",
    "messages": [
      {"role": "user", "content": "My name is John"},
      {"role": "assistant", "content": "Hello John!"},
      {"role": "user", "content": "What is my name?"}
    ]
  }'

# With tools
curl -X POST http://localhost:8314/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "AppleFoundationModel",
    "messages": [{"role": "user", "content": "What is the weather in Tokyo?"}],
    "tools": [
      {
        "type": "function",
        "function": {
          "name": "get_weather",
          "description": "Get weather for a location",
          "parameters": {
            "type": "object",
            "properties": {
              "location": {"type": "string", "description": "City name"}
            },
            "required": ["location"]
          }
        }
      }
    ]
  }'
```

### 6.2 Python

```python
import requests

# Simple chat
response = requests.post(
    "http://localhost:8314/v1/chat/completions",
    json={
        "model": "AppleFoundationModel",
        "messages": [
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": "Hello!"}
        ]
    }
)
print(response.json())

# With session
response = requests.post(
    "http://localhost:8314/v1/chat/completions",
    json={
        "model": "AppleFoundationModel",
        "user": "my-session-id",
        "messages": [{"role": "user", "content": "Hello!"}]
    }
)
```

### 6.3 Swift (URLSession)

```swift
import Foundation

let request = ChatCompletionRequest(
    model: "AppleFoundationModel",
    messages: [
        ChatMessage(role: .system, content: "You are helpful."),
        ChatMessage(role: .user, content: "Hello!")
    ]
)

var urlRequest = URLRequest(url: URL(string: "http://localhost:8314/v1/chat/completions")!)
urlRequest.httpMethod = "POST"
urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
urlRequest.httpBody = try JSONEncoder().encode(request)

let task = URLSession.shared.dataTask(with: urlRequest) { data, _, _ in
    let response = try JSONDecoder().decode(ChatCompletionResponse.self, from: data!)
    print(response.choices[0].message.content)
}
task.resume()
```

---

## 7. Authentication

**Hiện tại:** API không có authentication.

> ⚠️ **Cảnh báo:** Server chỉ nên chạy localhost. Không expose ra internet mà không có authentication.

### 7.1 Khuyến nghị triển khai thực tế

```swift
// Middleware pattern (tự thêm)
private func route(connection: NWConnection, request: APIHTTPRequest) {
    // Check API key header
    if request.headers["Authorization"] != "Bearer YOUR_API_KEY" {
        sendResponse(connection: connection, statusCode: 401, body: "Unauthorized")
        return
    }

    switch (request.method, request.path) {
    // ... routes
    }
}
```

---

## 8. Rate Limiting

**Hiện tại:** Không có rate limiting.

### 8.1 Khuyến nghị

Thêm vào `handle()`:

```swift
struct RateLimit {
    var counts: [String: (count: Int, resetTime: Date)] = [:]
    let limit = 60 // requests per minute
    let window: TimeInterval = 60
}

private var rateLimiter = RateLimit()

private func checkRateLimit(clientIP: String) -> Bool {
    let now = Date()
    if let entry = rateLimiter.counts[clientIP] {
        if now.timeIntervalSince(entry.resetTime) > rateLimiter.window {
            rateLimiter.counts[clientIP] = (1, now)
            return true
        }
        if entry.count >= rateLimiter.limit {
            return false
        }
        rateLimiter.counts[clientIP] = (entry.count + 1, entry.resetTime)
        return true
    }
    rateLimiter.counts[clientIP] = (1, now)
    return true
}
```

---

## 9. Lỗi thường gặp

### 9.1 `400 Bad Request`

**Nguyên nhân:** JSON body không đúng format

```bash
# Kiểm tra JSON có valid không
echo '{"model": "test"}' | python3 -m json.tool
```

### 9.2 `404 Not Found`

**Nguyên nhân:** Sai endpoint path

```bash
# Đúng
curl http://localhost:8314/v1/models

# Sai - thiếu /v1/
curl http://localhost:8314/models
```

### 9.3 `500 Internal Server Error`

**Nguyên nhân:** LLM không khả dụng hoặc lỗi xử lý

Kiểm tra logs trong Xcode console.

### 9.4 Connection refused

**Nguyên nhân:** Server chưa start

1. Mở ứng dụng
2. Nhấn nút API để start server
3. Kiểm tra port đúng 8314

### 9.5 `model_not_found`

**Nguyên nhân:** Model name không đúng

```json
{
  "error": {
    "message": "Model not found: wrong-model-name",
    "type": "invalid_request_error",
    "code": "model_not_found"
  }
}
```

Dùng `AppleFoundationModel` hoặc gọi `GET /v1/models` để xem danh sách.

---

## 10. Khuyến nghị triển khai Production

1. **HTTPS:** Cấu hình TLS certificate
   ```swift
   let server = HTTPServer(port: 443, useTLS: true, llm: llm)
   ```

2. **Authentication:** Thêm API key middleware

3. **Rate Limiting:** Thêm rate limiter như mô tả ở 8.1

4. **Logging:** Thêm structured logging cho requests

5. **Metrics:** Thêm Prometheus/StatsD metrics

6. **CORS:** Thêm CORS headers nếu gọi từ browser
   ```swift
   let corsHeaders = [
       "Access-Control-Allow-Origin": "*",
       "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
       "Access-Control-Allow-Headers": "Content-Type, Authorization"
   ]
   ```

7. **Process Management:** Dùng systemd/supervisord để quản lý process

8. **Firewall:** Chỉ cho phép localhost hoặc VPN interface
