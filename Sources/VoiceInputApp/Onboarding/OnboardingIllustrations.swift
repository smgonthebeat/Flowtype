import SwiftUI

// Pictures for the onboarding pages. They redraw the real capsule, the fn key and a
// text field so a user can follow the pages without reading (owner request,
// 2026-10-10). The capsule reuses `WaveformResponse` and the theme's voice colour,
// so it moves and looks like the real recording capsule.

// MARK: - Capsule

enum MockCapsuleKind: Equatable {
    case listening
    case transcribing
}

/// SwiftUI copy of `FloatingCapsulePanel`: dark pill, voice-coloured bars or dots, label.
struct MockCapsuleView: View {
    @Environment(\.appTheme) private var theme

    let kind: MockCapsuleKind
    let text: String
    /// Seconds used to drive the bar or dot motion; a fixed value gives a still frame.
    var time: Double = 0.6
    /// 0...1 voice level for the bars.
    var level: Double = 0.8
    var scale: CGFloat = 1

    var body: some View {
        HStack(spacing: 12 * scale) {
            indicator
                .frame(width: 44 * scale, height: 32 * scale)
            Text(text)
                .font(.system(size: 14 * scale, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.92))
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 24 * scale)
        .frame(height: 56 * scale)
        .background(Capsule().fill(Color(white: 0.12)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    @ViewBuilder
    private var indicator: some View {
        switch kind {
        case .listening:
            let fractions = WaveformResponse.barFractions(for: CGFloat(level), at: time)
            HStack(spacing: WaveformResponse.barGap * scale) {
                ForEach(fractions.indices, id: \.self) { index in
                    Capsule()
                        .fill(theme.voice)
                        .frame(
                            width: WaveformResponse.barWidth * scale,
                            height: max(3, 32 * scale * fractions[index])
                        )
                }
            }
        case .transcribing:
            HStack(spacing: WaveformResponse.dotGap * scale) {
                ForEach(0..<WaveformResponse.dotCount, id: \.self) { index in
                    Circle()
                        .fill(theme.voice)
                        .frame(width: WaveformResponse.dotSize * scale, height: WaveformResponse.dotSize * scale)
                        .offset(y: -dotLift(index: index) * scale)
                }
            }
        }
    }

    private func dotLift(index: Int) -> CGFloat {
        let period = WaveformResponse.bouncePeriod
        let local = (time - Double(index) * WaveformResponse.bounceStagger)
            .truncatingRemainder(dividingBy: period)
        let phase = (local < 0 ? local + period : local) / period
        return phase < 0.5 ? WaveformResponse.bounceHeight * CGFloat(sin(phase * 2 * .pi)) : 0
    }
}

// MARK: - MacBook keyboard

/// One MacBook keycap: near-black with a faint top highlight, legends placed where
/// Apple prints them.
struct MacKeycap: View {
    enum Legend {
        /// A letter in the middle.
        case centered(String)
        /// A word at the bottom-left and a symbol at the top-right (control, option, command).
        case modifier(word: String, symbol: String)
        /// The fn key on current MacBooks: globe bottom-left, "fn" top-right.
        case function
        case blank
    }

    @Environment(\.appTheme) private var theme

    let legend: Legend
    var width: CGFloat = 54
    var height: CGFloat = 50
    /// 0 = resting, 1 = fully held. In-between values let the key travel smoothly.
    var pressAmount: Double = 0
    var isDimmed = false

    var body: some View {
        let amount = min(max(pressAmount, 0), 1)
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.115), Color(white: 0.075)], startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(LinearGradient(colors: [theme.voice, theme.voice.opacity(0.85)], startPoint: .top, endPoint: .bottom))
                .opacity(amount)
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.13 + 0.27 * amount), Color.white.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
            ZStack {
                legendView
                    .foregroundStyle(Color.white.opacity(isDimmed ? 0.45 : 0.86))
                    .opacity(1 - amount)
                legendView
                    .foregroundStyle(Color.black.opacity(0.78))
                    .opacity(amount)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 6)
        }
        .frame(width: width, height: height)
        .offset(y: 2.5 * amount)
        .shadow(color: .black.opacity(0.7 * (1 - amount)), radius: 0, x: 0, y: 2.5 * (1 - amount))
        .shadow(color: theme.voice.opacity(0.55 * amount), radius: 18)
        .opacity(isDimmed ? 0.7 : 1)
    }

    @ViewBuilder
    private var legendView: some View {
        switch legend {
        case let .centered(letter):
            Text(letter)
                .font(.system(size: 15, weight: .regular))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .modifier(word, symbol):
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer(minLength: 0)
                    Text(symbol).font(.system(size: 11, weight: .regular))
                }
                Spacer(minLength: 0)
                Text(word).font(.system(size: 8.5, weight: .regular)).lineLimit(1).minimumScaleFactor(0.7)
            }
        case .function:
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer(minLength: 0)
                    Text("fn").font(.system(size: 11, weight: .medium))
                }
                Spacer(minLength: 0)
                Image(systemName: "globe").font(.system(size: 13, weight: .regular))
            }
        case .blank:
            Color.clear
        }
    }
}

/// Bottom-left corner of a MacBook keyboard. The fn key can be held, which sinks it,
/// shows a fingertip and fills a ring around it with the time held.
struct MacKeyboardCorner: View {
    @Environment(\.appTheme) private var theme

    /// 0 = resting, 1 = fully held.
    var fnPressAmount: Double
    /// 0...1 share of the hold ring that is filled.
    var holdProgress: Double
    /// The fingertip shows before the press (approaching) and while holding.
    var fingertipOpacity: Double

    private let keyHeight: CGFloat = 58
    private let keyWidth: CGFloat = 62
    private let gap: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: gap) {
            HStack(spacing: gap) {
                MacKeycap(legend: .modifier(word: "shift", symbol: "⇧"), width: 110, height: keyHeight, isDimmed: true)
                ForEach(["Z", "X", "C", "V", "B"], id: \.self) { letter in
                    MacKeycap(legend: .centered(letter), width: keyWidth, height: keyHeight, isDimmed: true)
                }
            }
            HStack(spacing: gap) {
                fnKey
                MacKeycap(legend: .modifier(word: "control", symbol: "⌃"), width: keyWidth, height: keyHeight, isDimmed: true)
                MacKeycap(legend: .modifier(word: "option", symbol: "⌥"), width: keyWidth, height: keyHeight, isDimmed: true)
                MacKeycap(legend: .modifier(word: "command", symbol: "⌘"), width: 80, height: keyHeight, isDimmed: true)
                MacKeycap(legend: .blank, width: 280, height: keyHeight, isDimmed: true)
            }
        }
        .padding(.leading, 18)
        .padding(.top, 16)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.19), Color(white: 0.145)], startPoint: .top, endPoint: .bottom))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        // The deck fades out to the right, so it reads as the corner of a whole keyboard.
        .mask(
            LinearGradient(
                stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.62), .init(color: .clear, location: 1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .accessibilityHidden(true)
    }

    private var fnKey: some View {
        let amount = min(max(fnPressAmount, 0), 1)
        let touch = min(max(fingertipOpacity, 0), 1)
        return MacKeycap(legend: .function, width: keyWidth, height: keyHeight, pressAmount: amount)
            .overlay {
                // Hovers slightly larger and higher, then settles onto the key as it goes down.
                Circle()
                    .fill(Color.white.opacity(0.22))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.55), lineWidth: 1))
                    .frame(width: 30, height: 30)
                    .scaleEffect(1.25 - 0.25 * amount)
                    .offset(y: 2.5 * amount - 6 * (1 - amount))
                    .opacity(touch)
            }
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .trim(from: 0, to: min(max(holdProgress, 0), 1))
                    .stroke(theme.voice, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: keyWidth + 10, height: keyHeight + 10)
                    .offset(y: 1)
                    .opacity(amount)
            }
            .zIndex(1)
    }
}

// MARK: - Text field

/// A small app window whose text field receives the dictated sentence.
struct MockTextWindow: View {
    @Environment(\.appTheme) private var theme

    let text: String
    /// 0...1 share of `text` that has appeared.
    var reveal: Double = 1
    var placeholder: String = ""
    var fontSize: CGFloat = 15

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Circle().fill(Color(red: 1, green: 0.37, blue: 0.34)).frame(width: 9, height: 9)
                Circle().fill(Color(red: 1, green: 0.74, blue: 0.18)).frame(width: 9, height: 9)
                Circle().fill(Color(red: 0.16, green: 0.78, blue: 0.25)).frame(width: 9, height: 9)
                Spacer()
            }
            .opacity(0.85)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Group {
                if visibleText.isEmpty && !placeholder.isEmpty {
                    Text(placeholder).foregroundColor(theme.tertiaryInk) + caret
                } else {
                    Text(visibleText).foregroundColor(theme.ink) + caret
                }
            }
            .font(.system(size: fontSize))
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(theme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
    }

    private var caret: Text {
        Text("|").foregroundColor(theme.voice).fontWeight(.light)
    }

    private var visibleText: String {
        let characters = Array(text)
        let count = Int((Double(characters.count) * min(max(reveal, 0), 1)).rounded(.down))
        return String(characters.prefix(count))
    }
}

// MARK: - Hold-Fn animation (owner choice "A" with the hold feel of "C", 2026-10-10)

/// One loop of hold-to-talk. Each visit starts calm (owner feedback 2026-10-11: the press
/// came too abruptly): a pause, a fingertip moves onto fn, the key eases down and its ring
/// fills while the capsule listens, then release, transcribe, and the sentence appears.
struct HoldFnAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The loop is timed from when the page appears, not from a wall clock.
    @State private var start = Date()

    let copy: OnboardingCopy.Texts
    let listeningText: String
    let transcribingText: String
    /// Fixed loop time for snapshots and reduced motion; nil animates.
    var stillTime: Double? = nil

    static let cycle: Double = 8.0
    static let approachAt: Double = 0.9
    static let pressAt: Double = 1.4
    static let releaseAt: Double = 4.6
    static let pasteAt: Double = 5.6
    static let clearAt: Double = 7.5
    /// Seconds the key takes to travel down or up.
    static let travel: Double = 0.22

    enum Phase: Int {
        case idle, holding, transcribing, pasted
    }

    static func phase(at loopTime: Double) -> Phase {
        switch loopTime {
        case ..<pressAt: return .idle
        case ..<releaseAt: return .holding
        case ..<pasteAt: return .transcribing
        default: return .pasted
        }
    }

    /// 0...1 smooth ramp between two moments.
    static func ramp(_ time: Double, from lower: Double, over duration: Double) -> Double {
        let x = min(max((time - lower) / duration, 0), 1)
        return x * x * (3 - 2 * x)
    }

    static func pressAmount(at time: Double) -> Double {
        ramp(time, from: pressAt, over: travel) - ramp(time, from: releaseAt, over: travel)
    }

    var body: some View {
        if let stillTime {
            frame(loopTime: stillTime, clock: stillTime)
        } else if reduceMotion {
            frame(loopTime: 2.9, clock: 2.9)
        } else {
            TimelineView(.animation) { context in
                let elapsed = max(context.date.timeIntervalSince(start), 0)
                frame(loopTime: elapsed.truncatingRemainder(dividingBy: Self.cycle), clock: elapsed)
            }
        }
    }

    private func frame(loopTime t: Double, clock: Double) -> some View {
        let phase = Self.phase(at: t)
        let held = min(max(t - Self.pressAt, 0), Self.releaseAt - Self.pressAt)
        let typedIn = Self.ramp(t, from: Self.pasteAt, over: 0.6)
        let erased = Self.ramp(t, from: Self.clearAt, over: 0.4)
        let fingertip = Self.ramp(t, from: Self.approachAt, over: 0.35) - Self.ramp(t, from: Self.releaseAt, over: 0.3)
        let capsuleIn = Self.ramp(t, from: Self.pressAt, over: 0.25) - Self.ramp(t, from: Self.pasteAt - 0.15, over: 0.25)
        return DictationScene(
            text: copy.sampleWrittenText,
            reveal: typedIn - erased,
            placeholder: "",
            capsule: phase == .transcribing ? .transcribing : (t < Self.releaseAt ? .listening : .transcribing),
            capsuleOpacity: capsuleIn,
            listeningText: listeningText,
            transcribingText: transcribingText,
            clock: clock,
            fnPressAmount: Self.pressAmount(at: t),
            fingertipOpacity: fingertip,
            holdProgress: held / (Self.releaseAt - Self.pressAt),
            holdingText: phase == .holding ? copy.holdingText(seconds: held) : nil,
            copy: copy
        )
    }
}

/// The page layout from concept A: a text field with the capsule at its bottom edge,
/// the MacBook keyboard corner under it, and two captions. The practice page feeds
/// it live state; the hold-Fn page feeds it the animation.
struct DictationScene: View {
    @Environment(\.appTheme) private var theme

    let text: String
    var reveal: Double = 1
    let placeholder: String
    let capsule: MockCapsuleKind?
    var capsuleOpacity: Double = 1
    let listeningText: String
    let transcribingText: String
    let clock: Double
    let fnPressAmount: Double
    var fingertipOpacity: Double
    let holdProgress: Double
    /// Replaces the "this key" caption while the key is held.
    let holdingText: String?
    let copy: OnboardingCopy.Texts

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .bottom) {
                MockTextWindow(text: text, reveal: reveal, placeholder: placeholder, fontSize: 16)
                Group {
                    switch capsule {
                    case .listening:
                        MockCapsuleView(kind: .listening, text: listeningText, time: clock, scale: 0.78)
                    case .transcribing:
                        MockCapsuleView(kind: .transcribing, text: transcribingText, time: clock, scale: 0.78)
                    case nil:
                        Color.clear.frame(height: 44)
                    }
                }
                .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
                .opacity(capsuleOpacity)
                .scaleEffect(0.94 + 0.06 * capsuleOpacity, anchor: .bottom)
                .padding(.bottom, 12)
            }
            .frame(height: 150)

            MacKeyboardCorner(fnPressAmount: fnPressAmount, holdProgress: holdProgress, fingertipOpacity: fingertipOpacity)
                .padding(.top, 8)

            HStack(alignment: .center) {
                // Under the fn key: where the key is, or how long it has been held.
                if let holdingText {
                    Text(holdingText)
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(theme.onAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(theme.voice))
                } else {
                    Label(copy.holdKeyPointer, systemImage: "arrow.up")
                        .foregroundStyle(theme.secondaryInk)
                        .padding(.vertical, 4)
                }
                Spacer(minLength: 12)
                Text(copy.holdRule)
                    .foregroundStyle(theme.ink)
                Text("·").foregroundStyle(theme.tertiaryInk)
                Text(copy.holdTapWarning)
                    .foregroundStyle(theme.danger.opacity(0.9))
            }
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Welcome flow

/// "You speak → recognized on this Mac → clean text at your cursor" in three pictures.
struct WelcomeFlowIllustration: View {
    @Environment(\.appTheme) private var theme

    let copy: OnboardingCopy.Texts
    let listeningText: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            tile(caption: copy.welcomeFlowSpeak) {
                Text("“\(copy.sampleSpokenText)”")
                    .font(.system(size: 12.5))
                    .foregroundStyle(theme.secondaryInk)
                    .lineSpacing(3)
                    .padding(12)
                    .frame(width: 158, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(theme.controlSurface)
                    )
            }
            arrow
            tile(caption: copy.welcomeFlowListen) {
                MockCapsuleView(kind: .listening, text: listeningText, scale: 0.62)
            }
            arrow
            tile(caption: copy.welcomeFlowPaste) {
                MockTextWindow(text: copy.sampleWrittenText, fontSize: 12.5)
                    .frame(width: 168, height: 88)
            }
        }
    }

    private func tile<Content: View>(caption: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 12) {
            content()
                .frame(height: 92)
            Text(caption)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(theme.secondaryInk)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var arrow: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(theme.tertiaryInk)
            .frame(height: 92)
    }
}
