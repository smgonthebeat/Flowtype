import Foundation

enum MathRenderer {
    static func render(_ expression: MathExpression, outputFormat: MathNotationOutputFormat) -> String {
        switch expression {
        case .symbol(let symbol):
            return outputFormat == .latex ? symbol.latex : symbol.unicode
        case .modified(let base, let modifier):
            return renderModified(base: base, modifier: modifier, outputFormat: outputFormat)
        case .subscripted(let base, let index):
            return renderSubscripted(base: base, index: index, outputFormat: outputFormat)
        case .powered(let base, let exponent):
            return renderPowered(base: base, exponent: exponent, outputFormat: outputFormat)
        case .function(let name, let arguments):
            return renderFunction(name: name, arguments: arguments, outputFormat: outputFormat)
        }
    }

    private static func renderFunction(
        name: MathFunctionName,
        arguments: [MathExpression],
        outputFormat: MathNotationOutputFormat
    ) -> String {
        let renderedArguments = arguments
            .map { render($0, outputFormat: outputFormat) }
            .joined(separator: ",")

        switch name {
        case .expectation:
            return "E[\(renderedArguments)]"
        default:
            let functionName = outputFormat == .latex ? name.latexName : name.unicodeName
            return "\(functionName)(\(renderedArguments))"
        }
    }

    private static func renderSubscripted(
        base: MathExpression,
        index: MathExpression,
        outputFormat: MathNotationOutputFormat
    ) -> String {
        let renderedBase = render(base, outputFormat: outputFormat)
        let renderedIndex = render(index, outputFormat: outputFormat)

        switch outputFormat {
        case .latex:
            let scriptBase = base.isSubscripted ? "{\(renderedBase)}" : renderedBase
            return scriptBase + "_" + latexScriptArgument(renderedIndex)
        case .unicode:
            return renderedBase + unicodeScriptArgument(
                renderedIndex,
                marker: "_",
                using: unicodeSubscripts
            )
        }
    }

    private static func renderPowered(
        base: MathExpression,
        exponent: MathExpression,
        outputFormat: MathNotationOutputFormat
    ) -> String {
        let renderedBase = render(base, outputFormat: outputFormat)
        let renderedExponent = render(exponent, outputFormat: outputFormat)

        switch outputFormat {
        case .latex:
            let scriptBase = base.isPowered ? "{\(renderedBase)}" : renderedBase
            return scriptBase + "^" + latexScriptArgument(renderedExponent)
        case .unicode:
            return renderedBase + unicodeScriptArgument(
                renderedExponent,
                marker: "^",
                using: unicodeSuperscripts
            )
        }
    }

    private static func renderModified(
        base: MathExpression,
        modifier: MathModifier,
        outputFormat: MathNotationOutputFormat
    ) -> String {
        precondition(
            base.isAtomLikeModifiedBase,
            "MathExpression.modified is only defined for symbol-rooted bases"
        )

        let renderedBase = render(base, outputFormat: outputFormat)
        switch (modifier, outputFormat) {
        case (.hat, .latex):
            return #"\hat{"# + renderedBase + "}"
        case (.hat, .unicode):
            return renderedBase + "\u{0302}"
        case (.bar, .latex):
            return #"\bar{"# + renderedBase + "}"
        case (.bar, .unicode):
            return renderedBase + "\u{0304}"
        case (.tilde, .latex):
            return #"\tilde{"# + renderedBase + "}"
        case (.tilde, .unicode):
            return renderedBase + "\u{0303}"
        case (.dot, .latex):
            return #"\dot{"# + renderedBase + "}"
        case (.dot, .unicode):
            return renderedBase + "\u{0307}"
        case (.doubleDot, .latex):
            return #"\ddot{"# + renderedBase + "}"
        case (.doubleDot, .unicode):
            return renderedBase + "\u{0308}"
        case (.prime, .latex):
            return renderedBase + "'"
        case (.prime, .unicode):
            return renderedBase + "′"
        case (.doublePrime, .latex):
            return renderedBase + "''"
        case (.doublePrime, .unicode):
            return renderedBase + "″"
        case (.star, .latex):
            return renderedBase + "^*"
        case (.star, .unicode):
            return renderedBase + "*"
        case (.transpose, .latex):
            return renderedBase + #"^\top"#
        case (.transpose, .unicode):
            return renderedBase + "ᵀ"
        case (.inverse, .latex):
            return renderedBase + "^{-1}"
        case (.inverse, .unicode):
            return renderedBase + "⁻¹"
        case (.squared, .latex):
            return renderedBase + "^2"
        case (.squared, .unicode):
            return renderedBase + "²"
        case (.cubed, .latex):
            return renderedBase + "^3"
        case (.cubed, .unicode):
            return renderedBase + "³"
        }
    }

    private static func unicodeScriptArgument(
        _ value: String,
        marker: String,
        using table: [Character: String]
    ) -> String {
        let converted = value.map { table[$0] }

        if converted.allSatisfy({ $0 != nil }) {
            return converted.compactMap { $0 }.joined()
        }

        return marker + latexScriptArgument(value)
    }

    private static func latexScriptArgument(_ value: String) -> String {
        value.count == 1 ? value : "{\(value)}"
    }

    private static let unicodeSubscripts: [Character: String] = [
        "0": "₀",
        "1": "₁",
        "2": "₂",
        "3": "₃",
        "4": "₄",
        "5": "₅",
        "6": "₆",
        "7": "₇",
        "8": "₈",
        "9": "₉",
        "+": "₊",
        "-": "₋",
        "=": "₌",
        "(": "₍",
        ")": "₎",
        ",": ",",
        "a": "ₐ",
        "e": "ₑ",
        "h": "ₕ",
        "i": "ᵢ",
        "j": "ⱼ",
        "k": "ₖ",
        "l": "ₗ",
        "m": "ₘ",
        "n": "ₙ",
        "o": "ₒ",
        "p": "ₚ",
        "r": "ᵣ",
        "s": "ₛ",
        "t": "ₜ",
        "u": "ᵤ",
        "v": "ᵥ"
    ]

    private static let unicodeSuperscripts: [Character: String] = [
        "0": "⁰",
        "1": "¹",
        "2": "²",
        "3": "³",
        "4": "⁴",
        "5": "⁵",
        "6": "⁶",
        "7": "⁷",
        "8": "⁸",
        "9": "⁹",
        "+": "⁺",
        "-": "⁻",
        "=": "⁼",
        "(": "⁽",
        ")": "⁾",
        "i": "ⁱ",
        "k": "ᵏ",
        "n": "ⁿ"
    ]
}

private extension MathExpression {
    var isSubscripted: Bool {
        if case .subscripted = self {
            return true
        }
        return false
    }

    var isPowered: Bool {
        if case .powered = self {
            return true
        }
        return false
    }
}
