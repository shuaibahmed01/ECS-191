import SwiftUI

struct FlashcardStudyView: View {
    let cards: [Flashcard]
    let slideTitle: String

    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var dragOffset: CGFloat = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            if cards.isEmpty {
                ContentUnavailableView("No Flashcards", systemImage: "rectangle.on.rectangle.slash", description: Text("There are no flashcards to study."))
                    .navigationTitle(slideTitle)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { dismiss() }
                        }
                    }
            } else {
            VStack(spacing: 24) {
                // Progress counter
                Text("\(currentIndex + 1) / \(cards.count)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.top)

                Spacer()

                // Card
                FlashcardCardView(
                    card: cards[currentIndex],
                    isFlipped: isFlipped
                )
                .offset(x: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 80
                            withAnimation(.spring(response: 0.3)) {
                                if value.translation.width < -threshold {
                                    goNext()
                                } else if value.translation.width > threshold {
                                    goPrevious()
                                }
                                dragOffset = 0
                            }
                        }
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        isFlipped.toggle()
                    }
                }

                Spacer()

                // Navigation arrows
                HStack(spacing: 48) {
                    Button {
                        withAnimation(.spring(response: 0.3)) { goPrevious() }
                    } label: {
                        Image(systemName: "arrow.left.circle.fill")
                            .font(.system(size: 44))
                    }
                    .disabled(currentIndex == 0)
                    .opacity(currentIndex == 0 ? 0.3 : 1)

                    Button {
                        withAnimation(.spring(response: 0.3)) { goNext() }
                    } label: {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 44))
                    }
                    .disabled(currentIndex == cards.count - 1)
                    .opacity(currentIndex == cards.count - 1 ? 0.3 : 1)
                }
                .padding(.bottom)

                Text("Tap card to flip")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom)
            }
            .navigationTitle(slideTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            } // end else (cards not empty)
        }
    }

    private func goNext() {
        guard currentIndex < cards.count - 1 else { return }
        isFlipped = false
        currentIndex += 1
    }

    private func goPrevious() {
        guard currentIndex > 0 else { return }
        isFlipped = false
        currentIndex -= 1
    }
}
