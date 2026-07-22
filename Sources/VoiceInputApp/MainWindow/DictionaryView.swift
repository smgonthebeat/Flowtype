import SwiftUI

struct DictionaryView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ObservedObject var state: MainWindowState
    let hotwordStore: HotwordStore
    let uiLanguage: UILanguage

    @State private var hotwords: [Hotword] = []
    @State private var query = ""
    @State private var draftWord = ""
    @State private var errorMessage = ""
    @State private var isShowingError = false
    @State private var duplicateFeedback: String?

    private let columns = [
        GridItem(.adaptive(minimum: 190, maximum: 280), spacing: 16, alignment: .topLeading)
    ]

    var body: some View {
        let copy = AppCopy.texts(for: uiLanguage)

        GeometryReader { geometry in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24, pinnedViews: [.sectionHeaders]) {
                    header
                    Section {
                        Group {
                            if let duplicateFeedback {
                                Label(duplicateFeedback, systemImage: "info.circle.fill")
                                    .font(.callout)
                                    .foregroundStyle(theme.secondaryInk)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(theme.controlSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .transition(.opacity)
                            }
                        }
                        .animation(
                            InlineFeedbackMotion.animation(reduceMotion: reduceMotion),
                            value: duplicateFeedback
                        )
                        sectionHeader
                        wordGrid
                    } header: {
                        dictionaryControls
                            .padding(.vertical, 8)
                            .background(theme.surface)
                    }
                }
                .padding(.horizontal, MainWindowDetailLayout.horizontalPadding(forWidth: geometry.size.width))
                .padding(.top, MainWindowDetailLayout.topPadding)
                .padding(.bottom, MainWindowDetailLayout.bottomPadding)
                .frame(maxWidth: MainWindowDetailLayout.dictionaryContentMaxWidth, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(theme.surface)
        }
        .onAppear(perform: reload)
        .onChange(of: state.refreshID) {
            reload()
        }
        .alert(copy.dictionaryErrorTitle, isPresented: $isShowingError) {
            Button(copy.ok, role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var header: some View {
        let copy = AppCopy.texts(for: uiLanguage)

        return HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 8) {
                Text(copy.dictionaryTitle)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(theme.ink)

                Text(copy.dictionarySubtitle)
                    .font(.callout)
                    .foregroundStyle(theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Text(copy.termCount(hotwords.count))
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(theme.secondaryInk)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(theme.controlSurface, in: Capsule())
        }
    }

    private var dictionaryControls: some View {
        HStack(alignment: .center, spacing: 14) {
            searchField
                .frame(width: 320)

            addBar
        }
    }

    private var addBar: some View {
        let copy = AppCopy.texts(for: uiLanguage)

        return HStack(alignment: .center, spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(theme.accent)

            TextField(copy.addHotwordPlaceholder, text: $draftWord)
                .textFieldStyle(.plain)
                .font(.body)
                .onSubmit(addDraftWord)

            Button(action: addDraftWord) {
                Label(copy.addWordTitle, systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(draftWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(14)
        .foregroundStyle(theme.ink)
        .themedCard(theme, cornerRadius: 14)
    }

    private var searchField: some View {
        let copy = AppCopy.texts(for: uiLanguage)

        return HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.secondaryInk)

            TextField(copy.searchHotwordsPlaceholder, text: $query)
                .textFieldStyle(.plain)
                .font(.body)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .foregroundStyle(theme.ink)
        .themedCard(theme, cornerRadius: 14)
    }

    private var sectionHeader: some View {
        let copy = AppCopy.texts(for: uiLanguage)

        return HStack {
            Label(copy.manageHotwordsTitle, systemImage: "tag")
                .font(.headline)
            Spacer()
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(copy.matchCount(filteredWords.count))
                    .font(.caption)
                    .foregroundStyle(theme.secondaryInk)
            }
        }
    }

    private var wordGrid: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
            ForEach(filteredWords) { hotword in
                hotwordCard(hotword)
            }
        }
    }

    private func hotwordCard(_ hotword: Hotword) -> some View {
        let copy = AppCopy.texts(for: uiLanguage)

        return HotwordCard(
            hotword: hotword,
            copy: copy,
            deleteAction: { delete(hotword) }
        )
    }

    private var filteredWords: [Hotword] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return hotwords }

        return hotwords.filter {
            $0.text.range(
                of: trimmedQuery,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) != nil
        }
    }

    private func addDraftWord() {
        let trimmedWord = draftWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedWord.isEmpty else { return }

        do {
            let outcome = try hotwordStore.addWithOutcome(trimmedWord)
            draftWord = ""
            switch outcome {
            case .inserted, .updated:
                duplicateFeedback = nil
            case let .existing(hotword):
                let copy = AppCopy.texts(for: uiLanguage)
                duplicateFeedback = copy.hotwordAlreadyExists
                query = hotword.text
            }
            reload()
            state.refresh()
        } catch {
            showError(error)
        }
    }

    private func delete(_ hotword: Hotword) {
        do {
            try hotwordStore.delete(id: hotword.id)
            reload()
            state.refresh()
        } catch {
            showError(error)
        }
    }

    private func reload() {
        do {
            hotwords = try hotwordStore.load()
        } catch {
            hotwords = []
            showError(error)
        }
    }

    private func showError(_ error: Error) {
        errorMessage = error.localizedDescription
        isShowingError = true
    }
}

private struct HotwordCard: View {
    @Environment(\.appTheme) private var theme

    let hotword: Hotword
    let copy: AppCopy.Texts
    let deleteAction: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(hotword.text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.ink)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(hotword.text)

            Spacer(minLength: 8)

            Button(role: .destructive, action: deleteAction) {
                Image(systemName: "trash")
                    .imageScale(.medium)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(theme.danger)
            .opacity(isHovered ? 1 : 0.35)
            .help(copy.deleteHotwordHelp)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .themedCard(theme, cornerRadius: 14)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(copy.deleteHotwordTitle, role: .destructive, action: deleteAction)
        }
    }
}
