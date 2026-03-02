import SwiftUI

struct FlashcardCardView: View {
    let card: Flashcard
    let isFlipped: Bool

    var body: some View {
        ZStack {
            // Front (Question)
            cardFace(
                label: "Question",
                text: card.question,
                accentColor: .blue
            )
            .opacity(isFlipped ? 0 : 1)
            .rotation3DEffect(
                .degrees(isFlipped ? 180 : 0),
                axis: (x: 0, y: 1, z: 0)
            )

            // Back (Answer)
            cardFace(
                label: "Answer",
                text: card.answer,
                accentColor: .green
            )
            .opacity(isFlipped ? 1 : 0)
            .rotation3DEffect(
                .degrees(isFlipped ? 0 : -180),
                axis: (x: 0, y: 1, z: 0)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: 350)
        .padding(.horizontal)
    }

    private func cardFace(label: String, text: String, accentColor: Color) -> some View {
        VStack(spacing: 16) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .foregroundStyle(accentColor)

            Text(text)
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: 350)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.background)
                .shadow(color: accentColor.opacity(0.2), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(accentColor.opacity(0.3), lineWidth: 1)
        )
    }
}
