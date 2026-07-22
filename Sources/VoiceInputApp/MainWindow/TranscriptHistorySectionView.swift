import SwiftUI

enum TranscriptHistorySectionLayout {
    static let cardTopPadding: CGFloat = 0
}

struct TranscriptHistorySectionView: View {
    @Environment(\.appTheme) private var theme

    let title: String
    let items: [TranscriptHistoryItem]
    let copy: AppCopy.Texts
    let actions: MainWindowActions

    private let timestampWidth: CGFloat = 56

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title.uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(theme.secondaryInk)

                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        TranscriptRowView(
                            item: item,
                            timestampWidth: timestampWidth,
                            copy: copy,
                            actions: actions
                        )
                        .zIndex(Double(items.count - index))

                        if index < items.count - 1 {
                            Divider()
                                .overlay(theme.divider)
                                .padding(.leading, timestampWidth + 26)
                        }
                    }
                }
                .padding(.top, TranscriptHistorySectionLayout.cardTopPadding)
                .themedCard(theme, cornerRadius: 14)
            }
        }
    }
}
