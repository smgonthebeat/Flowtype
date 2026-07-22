import AppKit
import SwiftUI

@MainActor
final class HelpWindowController: NSWindowController {
    private let settingsStore: SettingsStore

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 560, height: 460)
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        let copy = AppCopy.texts(for: settingsStore.uiLanguage)
        let theme = AppTheme.theme(for: settingsStore.appThemeID)

        window?.title = copy.helpMessageTitle
        window?.backgroundColor = theme.usesSystemMaterials ? .windowBackgroundColor : NSColor(theme.surface)
        window?.appearance = theme.usesSystemMaterials ? nil : NSAppearance(named: .darkAqua)
        window?.contentView = NSHostingView(
            rootView: HelpWindowView(copy: copy)
                .flowtypeTheme(theme)
        )
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct HelpWindowView: View {
    @Environment(\.appTheme) private var theme

    let copy: AppCopy.Texts

    private var sections: [(title: String, icon: String, body: String)] {
        let bodies = copy.helpMessageBody
            .components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let metadata: [(String, String)] = copy.timesUnit == "次"
            ? [
                ("开始听写", "keyboard"),
                ("历史与重试", "clock.arrow.circlepath"),
                ("词典、模型与转写设置", "text.book.closed"),
                ("权限与本地数据", "lock.shield")
            ]
            : [
                ("Start Dictating", "keyboard"),
                ("History & Retry", "clock.arrow.circlepath"),
                ("Dictionary, Models & Formatting", "text.book.closed"),
                ("Permissions & Local Data", "lock.shield")
            ]

        return zip(metadata, bodies).map { metadata, body in
            (title: metadata.0, icon: metadata.1, body: body)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(copy.helpMessageTitle)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(theme.ink)
                    Text(copy.mainSubtitle)
                        .font(.callout)
                        .foregroundStyle(theme.secondaryInk)
                }

                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: section.icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(theme.accent)
                            .frame(width: 30, height: 30)
                            .background(theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.title)
                                .font(.headline)
                                .foregroundStyle(theme.ink)
                            Text(section.body)
                                .font(.callout)
                                .foregroundStyle(theme.secondaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .themedCard(theme, cornerRadius: 12)
                }
            }
            .padding(28)
            .frame(maxWidth: 720, alignment: .topLeading)
        }
        .background(theme.surface)
    }
}
