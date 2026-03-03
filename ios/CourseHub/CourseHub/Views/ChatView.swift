import SwiftUI

struct ChatView: View {
    @State private var viewModel: ChatViewModel
    let classCode: String
    @State private var showingAttachMenu = false
    @State private var showDocumentPicker = false
    @State private var showCamera = false
    @State private var pendingComment: String = ""

    init(classId: String, classCode: String) {
        self._viewModel = State(initialValue: ChatViewModel(classId: classId))
        self.classCode = classCode
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    if viewModel.messages.isEmpty && !viewModel.isLoading {
                        VStack(spacing: 16) {
                            Spacer().frame(height: 60)

                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.blue)

                            Text("Welcome to \(classCode)!")
                                .font(.title3.bold())

                            Text("This is the group chat for your class. Say hi to your classmates, ask questions, or share resources.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)

                            Text("Be the first to send a message!")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(
                                    message: message,
                                    isCurrentUser: viewModel.isCurrentUser(message: message)
                                )
                                .id(message.id)
                            }
                        }
                        .padding()
                    }
                }
                .onChange(of: viewModel.messages.count) {
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Message input
            HStack(spacing: 8) {
                // Camera
                Button {
                    showCamera = true
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.title3)
                }
                .disabled(viewModel.isSending)
                
                // Document
                Button {
                    showDocumentPicker = true
                } label: {
                    Image(systemName: "doc.fill")
                        .font(.title3)
                }
                .disabled(viewModel.isSending)
                
                // Text field
                TextField("Message", text: $viewModel.messageText)
                    .textFieldStyle(.roundedBorder)
                    .disabled(viewModel.isSending)
                
                // Send
                Button {
                    Task {
                        await viewModel.sendMessage()
                    }
                } label: {
                    if viewModel.isSending {
                        ProgressView()
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                }
                .disabled(viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .sheet(isPresented: $showDocumentPicker) {
                NavigationStack {
                    VStack {
                        TextField("Optional comment...", text: $pendingComment)
                            .textFieldStyle(.roundedBorder)
                            .padding()
                        DocumentPicker { data in
                            showDocumentPicker = false
                            let comment = pendingComment.isEmpty ? nil : pendingComment
                            pendingComment = ""
                            Task { await viewModel.sendPickedFile(data: data, mimeType: "application/pdf", comment: comment) }
                        }
                    }
                    .navigationTitle("Choose File")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showDocumentPicker = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    showCamera = false
                    guard let data = image.jpegData(compressionQuality: 0.85) else { return }
                    let comment = pendingComment.isEmpty ? nil : pendingComment
                    pendingComment = ""
                    Task { await viewModel.sendPickedFile(data: data, mimeType: "image/jpeg", comment: comment) }
                }
                .ignoresSafeArea()
            }
        }
        .navigationTitle(classCode)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.startListening()
        }
        .onDisappear {
            viewModel.stopListening()
        }
        .overlay {
            if viewModel.isLoading && viewModel.messages.isEmpty {
                ProgressView("Loading messages...")
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let isCurrentUser: Bool

    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isCurrentUser {
                    Text(message.senderName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let urlString = message.attachmentUrl, !urlString.isEmpty, let url = URL(string: urlString) {
                    if message.attachmentType == "image" {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView().frame(width: 160, height: 120)
                            case .success(let img):
                                img
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: 220, maxHeight: 180)
                                    .clipped()
                                    .cornerRadius(12)
                            case .failure:
                                Link(destination: url) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "photo")
                                        Text("View image")
                                    }
                                    .padding(10)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Link(destination: url) {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text")
                                Text("Open attachment")
                            }
                            .padding(10)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                }

                if !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(message.content.markdownFormatted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isCurrentUser ? Color.blue : Color(.systemGray5))
                        .foregroundColor(isCurrentUser ? .white : .primary)
                        .cornerRadius(16)
                }

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if !isCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChatView(classId: "ecs_032a", classCode: "ECS 032A")
    }
}
