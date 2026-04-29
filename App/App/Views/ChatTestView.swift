import SwiftUI

@available(macOS 26.0, *)
struct Message: Identifiable {
    let id = UUID()
    let role: MessageRole
    let text: String
    let timestamp: Date
    let responseTimeMs: Int?

    enum MessageRole {
        case user
        case assistant
    }

    init(role: MessageRole, text: String, responseTimeMs: Int? = nil) {
        self.role = role
        self.text = text
        self.timestamp = Date()
        self.responseTimeMs = responseTimeMs
    }
}

@available(macOS 26.0, *)
struct ChatTestView: View {
    @State private var messages: [Message] = []
    @State private var input: String = ""
    @State private var isLoading: Bool = false

    let app: AppleBaseLMApp

    var body: some View {
        VStack(spacing: 0) {
            headerView

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                        }

                        if isLoading {
                            HStack {
                                ProgressView()
                                    .padding()
                                Text("Đang suy nghĩ...")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation {
                        if let lastId = messages.last?.id {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }

            inputArea
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private var headerView: some View {
        VStack(spacing: 4) {
            Text(app.llm?.modelName ?? "No LLM")
                .font(.headline)
                .foregroundColor(.primary)

            Text("macOS AI Chat")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 12) {
                TextField("Nhập câu hỏi...", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isLoading)

                Button(action: send) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(input.isEmpty ? .gray : .blue)
                }
                .disabled(input.isEmpty || isLoading)
            }
            .padding()
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func send() {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let userText = input
        let userMessage = Message(role: .user, text: userText)
        messages.append(userMessage)
        input = ""
        isLoading = true

        let startTime = CFAbsoluteTimeGetCurrent()

        Task {
            let reply = await app.processQuery(userText)
            let endTime = CFAbsoluteTimeGetCurrent()
            let responseTimeMs = Int((endTime - startTime) * 1000)

            await MainActor.run {
                let assistantMessage = Message(role: .assistant, text: reply, responseTimeMs: responseTimeMs)
                messages.append(assistantMessage)
                isLoading = false
                print("⚙️ Engine: \(app.llm?.modelName ?? "No LLM") | Response time: \(responseTimeMs)ms")
            }
        }
    }
}

@available(macOS 26.0, *)
struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack {
            if message.role == .assistant {
                Image(systemName: "apple.logo")
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(message.text)
                    .textSelection(.enabled)

                HStack(spacing: 8) {
                    Text(timeString)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if let responseTime = message.responseTimeMs {
                        Text("\(responseTime)ms")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            if message.role == .user {
                Image(systemName: "person.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(12)
        .background(bubbleColor)
        .cornerRadius(12)
    }

    private var bubbleColor: Color {
        message.role == .user
            ? Color.blue.opacity(0.1)
            : Color(NSColor.controlBackgroundColor)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.timestamp)
    }
}
