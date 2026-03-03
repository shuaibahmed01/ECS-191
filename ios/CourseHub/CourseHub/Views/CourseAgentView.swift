import SwiftUI

struct CourseAgentView: View {
    @State private var viewModel: CourseAgentViewModel
    @State private var expandedCard: String?
    let classCode: String

    init(classId: String, classCode: String) {
        self._viewModel = State(initialValue: CourseAgentViewModel(classId: classId))
        self.classCode = classCode
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    if viewModel.messages.isEmpty && !viewModel.isLoading {
                        emptyStateView
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                AgentMessageBubble(message: message)
                                    .id(message.id)
                            }

                            if viewModel.isSending {
                                typingIndicator
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

            // Persistent suggestion buttons (visible when messages exist)
            if !viewModel.messages.isEmpty && !viewModel.isSending {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        suggestionButton("When is the midterm?")
                        suggestionButton("What's the grading breakdown?")
                        suggestionButton("Office hours?")
                        suggestionButton("Course policies?")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }

            // Message input
            HStack(spacing: 12) {
                TextField("Ask about your course...", text: $viewModel.messageText)
                    .textFieldStyle(.roundedBorder)
                    .disabled(viewModel.isSending)

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
            .padding()
        }
        .navigationTitle("Course Agent")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            async let historyTask: () = viewModel.loadHistory()
            async let syllabusTask: () = viewModel.loadSyllabus()
            _ = await (historyTask, syllabusTask)
        }
        .overlay {
            if viewModel.isLoading && viewModel.messages.isEmpty {
                ProgressView("Loading...")
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(item: $expandedCard) { cardId in
            SyllabusCardDetailSheet(
                cardId: cardId,
                syllabusContext: viewModel.syllabusContext
            )
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            if let context = viewModel.syllabusContext {
                // Dashboard with info cards
                syllabusDashboard(context)
            } else if viewModel.isSyllabusLoading {
                Spacer().frame(height: 60)
                ProgressView()
                Text("Loading course info...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                // No syllabus — original-style empty state with suggestions
                noSyllabusEmptyState
            }
        }
    }

    private func syllabusDashboard(_ context: SyllabusContext) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                Text("Course Insights")
                    .font(.headline)
            }
            .padding(.top, 20)

            Text("Tap a card for details, or ask a question below.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                insightCard(
                    title: "Instructor",
                    content: context.instructor,
                    icon: "person.fill",
                    color: .blue,
                    id: "instructor"
                )
                insightCard(
                    title: "Office Hours",
                    content: context.officeHours,
                    icon: "clock.fill",
                    color: .green,
                    id: "officeHours"
                )
                insightCard(
                    title: "Grading",
                    content: context.gradingPolicy,
                    icon: "chart.bar.fill",
                    color: .orange,
                    id: "gradingPolicy"
                )
                insightCard(
                    title: "Key Dates",
                    content: context.importantDates,
                    icon: "calendar",
                    color: .red,
                    id: "importantDates"
                )
            }
            .padding(.horizontal)

            insightCardWide(
                title: "Course Policies",
                content: context.coursePolicies,
                icon: "list.clipboard.fill",
                color: .purple,
                id: "coursePolicies"
            )
            .padding(.horizontal)

            // Suggestion buttons below cards
            VStack(spacing: 8) {
                Text("Or ask a question")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                HStack(spacing: 8) {
                    suggestionButton("When is the midterm?")
                    suggestionButton("Prerequisites?")
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
    }

    private var noSyllabusEmptyState: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.purple)

            Text("Course Agent")
                .font(.title2.bold())

            Text("Ask questions about your course syllabus and I'll help find the answers.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text("Upload a syllabus to unlock course insight cards.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 32)

            VStack(spacing: 8) {
                suggestionButton("When is the midterm?")
                suggestionButton("What's the grading breakdown?")
                suggestionButton("What are the office hours?")
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Insight Cards

    private func insightCard(title: String, content: String, icon: String, color: Color, id: String) -> some View {
        Button {
            expandedCard = id
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(color)
                    Text(title)
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                }
                Text(content.markdownFormatted)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private func insightCardWide(title: String, content: String, icon: String, color: Color, id: String) -> some View {
        Button {
            expandedCard = id
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(color)
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                }
                Text(content.markdownFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Suggestion Buttons (auto-send)

    private func suggestionButton(_ text: String) -> some View {
        Button {
            viewModel.messageText = text
            Task {
                await viewModel.sendMessage()
            }
        } label: {
            Text(text)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.purple)
                Text("Thinking...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray5))
            .cornerRadius(16)
            Spacer()
        }
    }
}

// MARK: - Card Detail Sheet

struct SyllabusCardDetailSheet: View {
    let cardId: String
    let syllabusContext: SyllabusContext?
    @Environment(\.dismiss) private var dismiss

    private var title: String {
        switch cardId {
        case "instructor": return "Instructor"
        case "officeHours": return "Office Hours"
        case "gradingPolicy": return "Grading Breakdown"
        case "importantDates": return "Important Dates"
        case "coursePolicies": return "Course Policies"
        default: return ""
        }
    }

    private var icon: String {
        switch cardId {
        case "instructor": return "person.fill"
        case "officeHours": return "clock.fill"
        case "gradingPolicy": return "chart.bar.fill"
        case "importantDates": return "calendar"
        case "coursePolicies": return "list.clipboard.fill"
        default: return "info.circle"
        }
    }

    private var color: Color {
        switch cardId {
        case "instructor": return .blue
        case "officeHours": return .green
        case "gradingPolicy": return .orange
        case "importantDates": return .red
        case "coursePolicies": return .purple
        default: return .gray
        }
    }

    private var content: String {
        guard let ctx = syllabusContext else { return "" }
        switch cardId {
        case "instructor": return ctx.instructor
        case "officeHours": return ctx.officeHours
        case "gradingPolicy": return ctx.gradingPolicy
        case "importantDates": return ctx.importantDates
        case "coursePolicies": return ctx.coursePolicies
        default: return ""
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundStyle(color)
                        Text(title)
                            .font(.title2.bold())
                    }

                    Text(content.markdownFormatted)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Make String identifiable for sheet(item:)

extension String: @retroactive Identifiable {
    public var id: String { self }
}

struct AgentMessageBubble: View {
    let message: AgentMessage

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                if !isUser {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                        Text("Course Agent")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Text(message.content.markdownFormatted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(isUser ? .white : .primary)
                    .cornerRadius(16)
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }
}
