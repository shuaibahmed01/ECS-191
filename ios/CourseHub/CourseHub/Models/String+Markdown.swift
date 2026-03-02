import Foundation

extension String {
    /// Parses the string as Markdown, preserving newlines and inline formatting.
    var markdownFormatted: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return (try? AttributedString(markdown: self, options: options))
            ?? AttributedString(self)
    }
}
