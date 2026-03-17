import SwiftUI

struct ExamResultsView: View {
    let results: ExamResults
    let questions: [ExamQuestion]
    var onRetry: (() -> Void)?

    private var scoreColor: Color {
        let pct = Double(results.score) / Double(max(results.total, 1))
        if pct >= 0.8 { return .green }
        if pct >= 0.6 { return .orange }
        return .red
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Score Header
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 12)
                            .frame(width: 120, height: 120)
                        Circle()
                            .trim(from: 0, to: Double(results.score) / Double(max(results.total, 1)))
                            .stroke(scoreColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                        Text("\(results.score)/\(results.total)")
                            .font(.title.bold())
                    }
                    Text("Score")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top)

                // Per-question breakdown
                VStack(alignment: .leading, spacing: 12) {
                    Text("Question Breakdown")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(results.perQuestion, id: \.questionIndex) { result in
                        let question = result.questionIndex < questions.count ? questions[result.questionIndex] : nil
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                Image(systemName: result.correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(result.correct ? .green : .red)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Q\(result.questionIndex + 1)")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                    if let q = question {
                                        Text(q.question)
                                            .font(.subheadline)
                                    }
                                    Text(result.explanation)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if let partial = result.partial, partial {
                                        Text("Partial credit")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal)
                    }
                }

                // Feedback
                if !results.feedback.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Feedback")
                            .font(.headline)
                        Text(results.feedback)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                // Retry button
                if let onRetry {
                    Button {
                        onRetry()
                    } label: {
                        Label("Try Again", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .padding(.horizontal)
                }

                Spacer(minLength: 32)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
    }
}
