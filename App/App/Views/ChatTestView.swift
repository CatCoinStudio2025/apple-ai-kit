import SwiftUI
import AppKit
import UniformTypeIdentifiers
import SpeechCore
import NaturalLanguage

@available(macOS 26.0, *)
struct Message: Identifiable {
    let id = UUID()
    let role: MessageRole
    let text: String
    let timestamp: Date
    let responseTimeMs: Int?
    let imageData: Data?

    enum MessageRole {
        case user
        case assistant
    }

    init(role: MessageRole, text: String, responseTimeMs: Int? = nil, imageData: Data? = nil) {
        self.role = role
        self.text = text
        self.timestamp = Date()
        self.responseTimeMs = responseTimeMs
        self.imageData = imageData
    }
}

@available(macOS 26.0, *)
struct ChatTestView: View {
    @State private var messages: [Message] = []
    @State private var input: String = ""
    @State private var isLoading: Bool = false
    @State private var isRecording: Bool = false
    @State private var isSpeaking: Bool = false
    @State private var isConversationMode: Bool = false
    @State private var conversationId: String?
    @State private var attachedImageData: Data?
    @State private var showingImagePicker: Bool = false
    @State private var speechAuthStatus: String = "Not determined"
    @State private var isServerRunning: Bool = false
    @State private var serverMessage: String = ""

    let app: AppleBaseLMApp

    var body: some View {
        VStack(spacing: 0) {
            headerView

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { msg in
                            MessageBubble(
                                message: msg,
                                isSpeaking: isSpeaking,
                                onSpeak: { speakText(msg.text) },
                                onCancel: { cancelSpeaking() }
                            )
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
        .frame(minWidth: 600, minHeight: 500)
        .onAppear {
            requestSpeechAuth()
        }
    }

    private var headerView: some View {
        VStack(spacing: 4) {
            HStack {
                Text(app.llm?.modelName ?? "No LLM")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                if isConversationMode {
                    Text("Session: \(conversationId?.prefix(8) ?? "-")")
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                Toggle("Đa luồng", isOn: $isConversationMode)
                    .toggleStyle(.switch)
                    .font(.caption)
                    .onChange(of: isConversationMode) { _, newValue in
                        handleConversationModeChange(newValue)
                    }

                Button(action: toggleServer) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isServerRunning ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Text("API")
                            .font(.caption2)
                    }
                }
                .buttonStyle(.plain)
                .help(isServerRunning ? "Stop API Server" : "Start API Server")

                Text("Mic: \(speechAuthStatus)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text("macOS AI Chat")
                .font(.caption)
                .foregroundColor(.secondary)

            if !serverMessage.isEmpty {
                Text(serverMessage)
                    .font(.caption2)
                    .foregroundColor(isServerRunning ? .green : .orange)
            }

            Divider()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var inputArea: some View {
        VStack(spacing: 0) {
            if let imageData = attachedImageData, let nsImage = NSImage(data: imageData) {
                HStack {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 60)
                        .cornerRadius(8)
                    Text("Ảnh đính kèm")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("×") {
                        attachedImageData = nil
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            Divider()

            HStack(spacing: 12) {
                Button(action: toggleRecording) {
                    Image(systemName: isRecording ? "mic.fill" : "mic")
                        .foregroundColor(isRecording ? .red : .gray)
                }
                .buttonStyle(.plain)
                .help("Nhấn giữ để nói")

                Button(action: { showingImagePicker = true }) {
                    Image(systemName: "paperclip")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .help("Đính kèm ảnh")

                TextField("Nhập câu hỏi...", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isLoading)

                Button(action: send) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor((input.isEmpty && attachedImageData == nil) ? .gray : .blue)
                }
                .buttonStyle(.plain)
                .disabled((input.isEmpty && attachedImageData == nil) || isLoading)
            }
            .padding()
        }
        .background(Color(NSColor.windowBackgroundColor))
        .fileImporter(isPresented: $showingImagePicker, allowedContentTypes: [.image]) { result in
            if case .success(let url) = result {
                attachedImageData = try? Data(contentsOf: url)
            }
        }
    }

    private func handleConversationModeChange(_ enabled: Bool) {
        if enabled {
            conversationId = app.startConversation()
            messages.removeAll()
        } else {
            if let id = conversationId {
                app.endConversation(id)
            }
            conversationId = nil
            messages.removeAll()
        }
    }

    private func toggleServer() {
        if isServerRunning {
            app.stopServer()
            isServerRunning = false
            serverMessage = "Server stopped"
        } else {
            Task {
                do {
                    try await app.startServer(port: 8314)
                    await MainActor.run {
                        isServerRunning = true
                        serverMessage = "Server running at http://localhost:8314"
                    }
                } catch {
                    await MainActor.run {
                        serverMessage = "Error: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func requestSpeechAuth() {
        Task {
            let impl = SpeechRecognitionServiceImpl()
            let status = await impl.requestAuthorization()
            await MainActor.run {
                switch status {
                case .authorized:
                    speechAuthStatus = "OK"
                case .denied:
                    speechAuthStatus = "Từ chối"
                case .notDetermined:
                    speechAuthStatus = "Chưa xác định"
                }
            }
        }
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
    }

    private func stopRecording() {
        isRecording = false
    }

    private func speakText(_ text: String) {
        isSpeaking = true
        app.speakMultiLanguage(text)
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(text.count) / 10.0) {
            self.isSpeaking = false
        }
    }

    private func cancelSpeaking() {
        isSpeaking = false
        app.stopSpeaking()
    }

    private func send() {
        let userText = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userText.isEmpty || attachedImageData != nil else { return }

        let imageData = attachedImageData
        attachedImageData = nil
        input = ""

        let userMessage = Message(role: .user, text: userText.isEmpty ? "[Hình ảnh]" : userText, imageData: imageData)
        messages.append(userMessage)
        isLoading = true

        let startTime = CFAbsoluteTimeGetCurrent()

        Task {
            let reply: String
            if let imgData = imageData {
                if let convId = conversationId {
                    reply = await app.processQueryWithImage(conversationId: convId, text: userText, imageData: imgData)
                } else {
                    reply = await app.processQueryWithImage(userText, imageData: imgData)
                }
            } else {
                if let convId = conversationId {
                    reply = await app.processQuery(conversationId: convId, text: userText)
                } else {
                    reply = await app.processQuery(userText)
                }
            }
            let endTime = CFAbsoluteTimeGetCurrent()
            let responseTimeMs = Int((endTime - startTime) * 1000)

            await MainActor.run {
                let assistantMessage = Message(role: .assistant, text: reply, responseTimeMs: responseTimeMs)
                messages.append(assistantMessage)
                isLoading = false
                print("⚙️ Engine: \(self.app.llm?.modelName ?? "No LLM") | Response time: \(responseTimeMs)ms | Mode: \(self.isConversationMode ? "conversation" : "stateless")")
            }
        }
    }
}

@available(macOS 26.0, *)
struct MessageBubble: View {
    let message: Message
    let isSpeaking: Bool
    let onSpeak: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .assistant {
                Image(systemName: "apple.logo")
                    .foregroundColor(.blue)
                    .frame(width: 24)
            } else {
                Image(systemName: "person.fill")
                    .foregroundColor(.green)
                    .frame(width: 24)
            }

            VStack(alignment: .leading, spacing: 8) {
                if let imageData = message.imageData, let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 150)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }

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

                    if message.role == .assistant {
                        Button(action: isSpeaking ? onCancel : onSpeak) {
                            Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                                .font(.caption)
                                .foregroundColor(isSpeaking ? .blue : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help(isSpeaking ? "Dừng đọc" : "Đọc phản hồi")
                    }
                }
            }

            Spacer()
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
