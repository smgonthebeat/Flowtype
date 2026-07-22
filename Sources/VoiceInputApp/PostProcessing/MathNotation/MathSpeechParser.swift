import Foundation

enum MathSpeechParser {
    private static let compactBinaryArgumentPairs: Set<String> = [
        "xy", "xz", "yx", "yz", "zx", "zy"
    ]

    private static let codeLikePreviousWords: Set<String> = [
        "declare",
        "use",
        "using",
        "write",
        "type",
        "swift",
        "code",
        "let",
        "const",
        "function"
    ]

    private static let binaryCodeLikeContinuationWords: Set<String> = [
        "code",
        "swift"
    ]

    private static let binaryStatisticsFunctionRegex = try! NSRegularExpression(
        pattern: #"\b(covariance|cov|correlation|corr|cor)\b(?:\s+of\b)?"#,
        options: [.caseInsensitive]
    )

    private static let unaryStatisticsFunctionRegex = try! NSRegularExpression(
        pattern: #"\b(standard deviation|standard error|standard arrow|expected value|expectation|variance|variant|variants|var|s\s+d|s\s+e|sd|se|e)\b(?:\s+of\b)?\s+"#,
        options: [.caseInsensitive]
    )

    private static let compactedStandardDeviationRegex = try! NSRegularExpression(
        pattern: #"\b(sd)([A-Za-z])\b\s+(double prime|double dot|transpose|inverse|squared|square|cubed|cube|overbar|head|hat|bar|tilde|dot|prime|star|asterisk|sub\s+(?:zero|one|two|three|0|1|2|3|i|j|k|n|t))\b"#,
        options: [.caseInsensitive]
    )

    private static let punctuatedBetaHatNearMissRegex = try! NSRegularExpression(
        pattern: #"["“”']?\b(standard error|standard arrow|se)\b\s*(?:[,，]\s*)?["“”']?\s*(better|bad|beta)\s+(head|hat)\b"#,
        options: [.caseInsensitive]
    )

    private static let existingVarianceModifierRegex = try! NSRegularExpression(
        pattern: #"\b(?:Var|VAR)\s*\(\s*([A-Za-z])\s*\)\s+(double prime|double dot|transpose|inverse|squared|square|cubed|cube|overbar|head|hat|bar|tilde|dot|prime|star|asterisk)\b"#,
        options: []
    )

    private static let modifierAlternatives = [
        "double prime",
        "double dot",
        "transpose",
        "inverse",
        "squared",
        "square",
        "cubed",
        "cube",
        "overbar",
        "head",
        "hat",
        "bar",
        "tilde",
        "dot",
        "prime",
        "star",
        "asterisk"
    ]

    private static let subscriptThenModifierAlternatives = [
        "head",
        "hat"
    ]

    static func parseArgumentExpression(_ phrase: String) -> MathExpression? {
        let normalized = MathLexicon.normalizeSpaces(phrase)

        if let betaHat = parseBetaHatASRNearMiss(normalized) {
            return betaHat
        }

        if let parsed = parseExistingRenderedExpression(normalized) {
            return parsed
        }

        if let parsed = parsePowerSuffix(normalized) {
            return parsed
        }

        if let parsed = parseSubscriptSuffix(normalized) {
            return parsed
        }

        if let parsed = parseSubscriptThenModifier(normalized) {
            return parsed
        }

        for modifierPhrase in modifierAlternatives {
            let suffix = " " + modifierPhrase
            guard normalized.hasSuffix(suffix) else { continue }
            let basePhrase = String(normalized.dropLast(suffix.count))
            guard let base = parseArgumentExpression(basePhrase),
                  let modifier = MathLexicon.modifier(from: modifierPhrase) else {
                return nil
            }
            guard base.isAtomLikeModifiedBase else {
                return nil
            }
            return .modified(base: base, modifier: modifier)
        }

        guard let symbol = MathLexicon.symbol(from: normalized, uppercaseLatinForStatistics: true) else {
            return nil
        }
        return .symbol(symbol)
    }

    private static func parseExistingRenderedExpression(_ normalized: String) -> MathExpression? {
        if let powered = parseExistingUnicodePower(normalized) {
            return powered
        }

        if let subscripted = parseExistingUnicodeSubscript(normalized) {
            return subscripted
        }

        return parseExistingUnicodeModifier(normalized)
    }

    private static func parseExistingUnicodePower(_ normalized: String) -> MathExpression? {
        let powerSuffixes: [(String, String)] = [
            ("²", "2"),
            ("³", "3")
        ]

        for (suffix, exponentPhrase) in powerSuffixes {
            guard let basePhrase = droppingUnicodeScalarSuffix(suffix, from: normalized),
                  !basePhrase.isEmpty,
                  let base = parseArgumentExpression(basePhrase),
                  let exponent = MathLexicon.exponent(from: exponentPhrase) else {
                continue
            }
            return .powered(base: base, exponent: exponent)
        }

        return nil
    }

    private static func parseExistingUnicodeSubscript(_ normalized: String) -> MathExpression? {
        let scalars = Array(normalized.unicodeScalars)
        var cursor = scalars.count
        var indexParts: [String] = []

        while cursor > 0 {
            let scalar = String(scalars[cursor - 1])
            guard let indexPart = existingUnicodeSubscriptScalars[scalar] else {
                break
            }
            indexParts.insert(indexPart, at: 0)
            cursor -= 1
        }

        guard cursor < scalars.count, cursor > 0 else {
            return nil
        }

        let basePhrase = String(String.UnicodeScalarView(scalars[..<cursor]))
        let indexPhrase = indexParts.joined()
        guard let base = parseArgumentExpression(basePhrase) else {
            return nil
        }

        let index = MathExpression.symbol(
            MathSymbolAtom(spoken: indexPhrase, latex: indexPhrase, unicode: indexPhrase)
        )
        return .subscripted(base: base, index: index)
    }

    private static func parseExistingUnicodeModifier(_ normalized: String) -> MathExpression? {
        let modifierSuffixes: [(String, MathModifier)] = [
            ("\u{0302}", .hat),
            ("\u{0304}", .bar),
            ("\u{0303}", .tilde),
            ("\u{0307}", .dot),
            ("\u{0308}", .doubleDot),
            ("″", .doublePrime),
            ("′", .prime),
            ("ᵀ", .transpose),
            ("⁻¹", .inverse)
        ]

        for (suffix, modifier) in modifierSuffixes {
            guard let basePhrase = droppingUnicodeScalarSuffix(suffix, from: normalized),
                  !basePhrase.isEmpty,
                  let base = parseArgumentExpression(basePhrase),
                  base.isAtomLikeModifiedBase else {
                continue
            }
            return .modified(base: base, modifier: modifier)
        }

        return nil
    }

    private static func droppingUnicodeScalarSuffix(_ suffix: String, from text: String) -> String? {
        let textScalars = Array(text.unicodeScalars)
        let suffixScalars = Array(suffix.unicodeScalars)
        guard suffixScalars.count <= textScalars.count,
              Array(textScalars.suffix(suffixScalars.count)) == suffixScalars else {
            return nil
        }

        let baseScalars = textScalars.dropLast(suffixScalars.count)
        return String(String.UnicodeScalarView(baseScalars))
    }

    private static func parseBetaHatASRNearMiss(_ normalized: String) -> MathExpression? {
        let nearMisses = [
            "better hat",
            "better head",
            "bad hat",
            "bad head"
        ]
        guard nearMisses.contains(normalized),
              let beta = MathLexicon.symbol(from: "beta", uppercaseLatinForStatistics: true) else {
            return nil
        }
        return .modified(base: .symbol(beta), modifier: .hat)
    }

    private static func parsePowerSuffix(_ normalized: String) -> MathExpression? {
        for powerPhrase in ["squared", "square", "cubed", "cube"] {
            let suffix = " " + powerPhrase
            guard normalized.hasSuffix(suffix) else { continue }
            let basePhrase = String(normalized.dropLast(suffix.count))
            guard parseSubscriptThenModifier(basePhrase) == nil else {
                return nil
            }
            guard let base = parseArgumentExpression(basePhrase),
                  let exponent = MathLexicon.exponent(from: powerPhrase) else {
                return nil
            }
            return .powered(base: base, exponent: exponent)
        }
        return nil
    }

    private static func parseSubscriptThenModifier(_ normalized: String) -> MathExpression? {
        for modifierPhrase in subscriptThenModifierAlternatives {
            let suffix = " " + modifierPhrase
            guard normalized.hasSuffix(suffix),
                  let modifier = MathLexicon.modifier(from: modifierPhrase) else {
                continue
            }

            let subscriptPhrase = String(normalized.dropLast(suffix.count))
            guard case .subscripted(let base, let index)? = parseArgumentExpression(subscriptPhrase),
                  base.isAtomLikeModifiedBase else {
                continue
            }

            return .subscripted(
                base: .modified(base: base, modifier: modifier),
                index: index
            )
        }

        return nil
    }

    private static func parseSubscriptSuffix(_ normalized: String) -> MathExpression? {
        let marker = " sub "
        guard let markerRange = normalized.range(of: marker, options: .backwards) else {
            return nil
        }

        let basePhrase = String(normalized[..<markerRange.lowerBound])
        let indexPhrase = String(normalized[markerRange.upperBound...])

        guard let base = parseArgumentExpression(basePhrase),
              let index = MathLexicon.subscriptIndex(from: indexPhrase) else {
            return nil
        }
        return .subscripted(base: base, index: index)
    }

    static func replaceStatisticsFunctions(
        in text: String,
        outputFormat: MathNotationOutputFormat
    ) -> String {
        let textWithExistingNotationModifiers = replaceExistingVarianceNotationModifiers(
            in: text,
            outputFormat: outputFormat
        )
        let textWithBinaryStatistics = replaceBinaryStatisticsFunctions(
            in: textWithExistingNotationModifiers,
            outputFormat: outputFormat
        )
        let textWithPunctuatedBetaHatNearMisses = replacePunctuatedBetaHatNearMisses(
            in: textWithBinaryStatistics,
            outputFormat: outputFormat
        )
        let textWithCompactedStandardDeviation = replaceCompactedStandardDeviation(
            in: textWithPunctuatedBetaHatNearMisses,
            outputFormat: outputFormat
        )
        return replaceUnaryStatisticsFunctions(in: textWithCompactedStandardDeviation, outputFormat: outputFormat)
    }

    private static func replaceExistingVarianceNotationModifiers(
        in text: String,
        outputFormat: MathNotationOutputFormat
    ) -> String {
        var result = ""
        var searchStart = text.startIndex
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)

        existingVarianceModifierRegex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match,
                  let matchRange = Range(match.range, in: text),
                  matchRange.lowerBound >= searchStart,
                  !isInsideInlineCode(in: text, at: matchRange.lowerBound),
                  let symbolPhrase = group(1, in: match, text: text),
                  let modifierPhrase = group(2, in: match, text: text),
                  let symbol = MathLexicon.symbol(from: symbolPhrase, uppercaseLatinForStatistics: true),
                  let modifier = MathLexicon.modifier(from: modifierPhrase) else {
                return
            }

            let expression = MathExpression.function(
                name: .variance,
                arguments: [.modified(base: .symbol(symbol), modifier: modifier)]
            )
            result += text[searchStart..<matchRange.lowerBound]
            result += MathRenderer.render(expression, outputFormat: outputFormat)
            searchStart = matchRange.upperBound
        }

        result += text[searchStart..<text.endIndex]
        return result
    }

    private static func replaceCompactedStandardDeviation(
        in text: String,
        outputFormat: MathNotationOutputFormat
    ) -> String {
        var result = ""
        var searchStart = text.startIndex
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)

        compactedStandardDeviationRegex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match,
                  let matchRange = Range(match.range, in: text),
                  matchRange.lowerBound >= searchStart,
                  !isInsideInlineCode(in: text, at: matchRange.lowerBound),
                  let symbolPhrase = group(2, in: match, text: text),
                  let suffixPhrase = group(3, in: match, text: text),
                  let argument = parseArgumentExpression("\(symbolPhrase) \(suffixPhrase)"),
                  !isCodeLikeContinuation(in: text, from: matchRange.upperBound),
                  !isInsideInlineCode(in: text, at: matchRange.upperBound) else {
                return
            }

            let expression = MathExpression.function(name: .standardDeviation, arguments: [argument])
            result += text[searchStart..<matchRange.lowerBound]
            result += MathRenderer.render(expression, outputFormat: outputFormat)
            searchStart = matchRange.upperBound
        }

        result += text[searchStart..<text.endIndex]
        return result
    }

    private static func replaceBinaryStatisticsFunctions(
        in text: String,
        outputFormat: MathNotationOutputFormat
    ) -> String {
        var result = ""
        var searchStart = text.startIndex
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)

        binaryStatisticsFunctionRegex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match,
                  let matchRange = Range(match.range, in: text),
                  matchRange.lowerBound >= searchStart,
                  !isInsideInlineCode(in: text, at: matchRange.lowerBound),
                  let functionPhrase = group(1, in: match, text: text),
                  !isCodeLikeBinaryStatisticsPhrase(functionPhrase: functionPhrase, in: text, before: matchRange.lowerBound),
                  let function = MathLexicon.function(from: functionPhrase),
                  function != .variance,
                  let parsedArguments = parseBinaryArgumentCandidate(in: text, from: matchRange.upperBound),
                  !isCodeLikeBinaryContinuation(in: text, from: parsedArguments.end),
                  !isInsideInlineCode(in: text, at: parsedArguments.end) else {
                return
            }

            let expression = MathExpression.function(name: function, arguments: parsedArguments.expressions)
            result += text[searchStart..<matchRange.lowerBound]
            result += MathRenderer.render(expression, outputFormat: outputFormat)
            searchStart = parsedArguments.end
        }

        result += text[searchStart..<text.endIndex]
        return result
    }

    private static func replacePunctuatedBetaHatNearMisses(
        in text: String,
        outputFormat: MathNotationOutputFormat
    ) -> String {
        var result = ""
        var searchStart = text.startIndex
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)

        punctuatedBetaHatNearMissRegex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match,
                  let matchRange = Range(match.range, in: text),
                  matchRange.lowerBound >= searchStart,
                  !isInsideInlineCode(in: text, at: matchRange.lowerBound),
                  let nearMiss = group(2, in: match, text: text),
                  let modifier = group(3, in: match, text: text),
                  let argument = parseBetaHatASRNearMiss("\(nearMiss) \(modifier)"),
                  !isCodeLikeContinuation(in: text, from: matchRange.upperBound),
                  !isInsideInlineCode(in: text, at: matchRange.upperBound) else {
                return
            }

            let expression = MathExpression.function(name: .standardError, arguments: [argument])
            result += text[searchStart..<matchRange.lowerBound]
            result += MathRenderer.render(expression, outputFormat: outputFormat)
            searchStart = matchRange.upperBound
        }

        result += text[searchStart..<text.endIndex]
        return result
    }

    private static func replaceUnaryStatisticsFunctions(
        in text: String,
        outputFormat: MathNotationOutputFormat
    ) -> String {
        var result = ""
        var searchStart = text.startIndex
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)

        unaryStatisticsFunctionRegex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match,
                  let matchRange = Range(match.range, in: text),
                  matchRange.lowerBound >= searchStart,
                  !isInsideInlineCode(in: text, at: matchRange.lowerBound),
                  let functionPhrase = group(1, in: match, text: text),
                  !isCodeLikeBareVar(functionPhrase: functionPhrase, in: text, before: matchRange.lowerBound),
                  let function = MathLexicon.function(from: functionPhrase),
                  let parsedArgument = parseArgumentCandidate(in: text, from: matchRange.upperBound),
                  !isVariantGreekAlias(functionPhrase: functionPhrase, argumentPhrase: parsedArgument.phrase),
                  !isPlainEnglishUnaryFalsePositive(functionPhrase: functionPhrase, argumentPhrase: parsedArgument.phrase),
                  !isBareExpectationFalsePositive(
                    functionPhrase: functionPhrase,
                    in: text,
                    before: matchRange.lowerBound,
                    argumentEnd: parsedArgument.end
                  ),
                  !isCodeLikeContinuation(in: text, from: parsedArgument.end),
                  !isInsideInlineCode(in: text, at: parsedArgument.end) else {
                return
            }

            let expression = MathExpression.function(name: function, arguments: [parsedArgument.expression])
            result += text[searchStart..<matchRange.lowerBound]
            result += MathRenderer.render(expression, outputFormat: outputFormat)
            searchStart = parsedArgument.end
        }

        result += text[searchStart..<text.endIndex]
        return result
    }

    private static func parseArgumentCandidate(
        in text: String,
        from start: String.Index
    ) -> (expression: MathExpression, phrase: String, end: String.Index)? {
        var tokens: [(start: String.Index, end: String.Index)] = []
        var cursor = start

        for _ in 0..<6 {
            while cursor < text.endIndex, text[cursor].isWhitespace {
                cursor = text.index(after: cursor)
            }

            guard cursor < text.endIndex, text[cursor].isLetter || text[cursor].isNumber else {
                break
            }

            let tokenStart = cursor
            while cursor < text.endIndex, text[cursor].isLetter || text[cursor].isNumber {
                cursor = text.index(after: cursor)
            }
            tokens.append((start: tokenStart, end: cursor))
        }

        guard let firstToken = tokens.first else {
            return nil
        }

        for tokenCount in stride(from: tokens.count, through: 1, by: -1) {
            let end = tokens[tokenCount - 1].end
            let phrase = String(text[firstToken.start..<end])
            if let expression = parseArgumentExpression(phrase) {
                return (expression: expression, phrase: phrase, end: end)
            }
        }

        return nil
    }

    private static func isPlainEnglishUnaryFalsePositive(
        functionPhrase: String,
        argumentPhrase: String
    ) -> Bool {
        switch MathLexicon.normalizeSpaces(functionPhrase) {
        case "standard error", "standard arrow", "se":
            return ["message", "messages", "log", "logs"].contains(MathLexicon.normalizeSpaces(argumentPhrase))
        case "expectation", "expected value":
            return ["is", "was", "that"].contains(MathLexicon.normalizeSpaces(argumentPhrase))
        default:
            return false
        }
    }

    private static func isBareExpectationFalsePositive(
        functionPhrase: String,
        in text: String,
        before functionStart: String.Index,
        argumentEnd: String.Index
    ) -> Bool {
        guard MathLexicon.normalizeSpaces(functionPhrase) == "e" else {
            return false
        }

        if let previousWord = previousWord(in: text, before: functionStart),
           codeLikePreviousWords.union(["press", "hit", "tap", "select", "choose"]).contains(previousWord) {
            return true
        }

        let nextWordStart = skipWhitespace(in: text, from: argumentEnd)
        guard let nextWordRange = wordRange(in: text, from: nextWordStart) else {
            return false
        }
        return MathLexicon.normalizeSpaces(String(text[nextWordRange])) == "to"
    }

    private static func parseBinaryArgumentCandidate(
        in text: String,
        from start: String.Index
    ) -> (expressions: [MathExpression], end: String.Index)? {
        let argumentStart = skipWhitespace(in: text, from: start)

        if let compactArguments = parseCompactBinaryArgumentCandidate(in: text, from: argumentStart) {
            return compactArguments
        }

        guard let firstArgument = parseArgumentCandidate(in: text, from: argumentStart) else {
            return nil
        }

        let secondStart = skipBinaryArgumentSeparator(in: text, from: firstArgument.end)
        guard let secondArgument = parseArgumentCandidate(in: text, from: secondStart) else {
            return nil
        }

        return (
            expressions: [firstArgument.expression, secondArgument.expression],
            end: secondArgument.end
        )
    }

    private static func parseCompactBinaryArgumentCandidate(
        in text: String,
        from start: String.Index
    ) -> (expressions: [MathExpression], end: String.Index)? {
        guard start < text.endIndex,
              text[start].isLetter else {
            return nil
        }

        var cursor = start
        while cursor < text.endIndex, text[cursor].isLetter {
            cursor = text.index(after: cursor)
        }

        let token = MathLexicon.normalizeSpaces(String(text[start..<cursor]))
        guard compactBinaryArgumentPairs.contains(token) else {
            return nil
        }

        let expressions = token.compactMap { character -> MathExpression? in
            guard let symbol = MathLexicon.symbol(from: String(character), uppercaseLatinForStatistics: true) else {
                return nil
            }
            return .symbol(symbol)
        }

        guard expressions.count == 2 else {
            return nil
        }

        return (expressions: expressions, end: cursor)
    }

    private static func skipBinaryArgumentSeparator(in text: String, from start: String.Index) -> String.Index {
        var cursor = skipWhitespace(in: text, from: start)

        if cursor < text.endIndex, text[cursor] == "," {
            cursor = text.index(after: cursor)
            cursor = skipWhitespace(in: text, from: cursor)
        }

        while let wordRange = wordRange(in: text, from: cursor) {
            let separator = MathLexicon.normalizeSpaces(String(text[wordRange]))
            guard separator == "and" || separator == "comma" else {
                break
            }
            cursor = skipWhitespace(in: text, from: wordRange.upperBound)
        }

        return cursor
    }

    private static func isVariantGreekAlias(functionPhrase: String, argumentPhrase: String) -> Bool {
        guard MathLexicon.normalizeSpaces(functionPhrase) == "variant" else {
            return false
        }

        switch MathLexicon.normalizeSpaces(argumentPhrase) {
        case "epsilon", "theta", "pi", "rho", "sigma", "phi":
            return true
        default:
            return false
        }
    }

    private static func group(_ index: Int, in match: NSTextCheckingResult, text: String) -> String? {
        let range = match.range(at: index)
        guard range.location != NSNotFound,
              let swiftRange = Range(range, in: text) else {
            return nil
        }
        return String(text[swiftRange])
    }

    private static func isCodeLikeContinuation(in text: String, from start: String.Index) -> Bool {
        var cursor = start
        while cursor < text.endIndex, text[cursor].isWhitespace {
            cursor = text.index(after: cursor)
        }

        guard cursor < text.endIndex else {
            return false
        }

        if ["=", ":", ";", "{"].contains(text[cursor]) {
            return true
        }

        let nextTwoCharacters = String(text[cursor..<minIndex(text.endIndex, offsetBy: 2, from: cursor, in: text)])
        return nextTwoCharacters.lowercased() == "in"
            && (text.index(cursor, offsetBy: 2, limitedBy: text.endIndex) == text.endIndex
                || !text[text.index(cursor, offsetBy: 2)].isLetter)
    }

    private static func isCodeLikeBinaryContinuation(in text: String, from start: String.Index) -> Bool {
        var cursor = start
        while cursor < text.endIndex, text[cursor].isWhitespace {
            cursor = text.index(after: cursor)
        }

        guard cursor < text.endIndex else {
            return false
        }

        if ["=", ":", ";", "{"].contains(text[cursor]) {
            return true
        }

        guard let inRange = wordRange(in: text, from: cursor),
              MathLexicon.normalizeSpaces(String(text[inRange])) == "in" else {
            return false
        }

        let nextWordStart = skipWhitespace(in: text, from: inRange.upperBound)
        guard let nextWordRange = wordRange(in: text, from: nextWordStart) else {
            return false
        }

        return binaryCodeLikeContinuationWords.contains(
            MathLexicon.normalizeSpaces(String(text[nextWordRange]))
        )
    }

    private static func isCodeLikeBareVar(
        functionPhrase: String,
        in text: String,
        before index: String.Index
    ) -> Bool {
        guard MathLexicon.normalizeSpaces(functionPhrase) == "var",
              let previousWord = previousWord(in: text, before: index) else {
            return false
        }

        return codeLikePreviousWords.contains(previousWord)
    }

    private static func isCodeLikeBinaryStatisticsPhrase(
        functionPhrase: String,
        in text: String,
        before index: String.Index
    ) -> Bool {
        guard ["corr", "cor", "cov"].contains(MathLexicon.normalizeSpaces(functionPhrase)),
              let previousWord = previousWord(in: text, before: index) else {
            return false
        }

        return codeLikePreviousWords.contains(previousWord)
    }

    private static func previousWord(in text: String, before index: String.Index) -> String? {
        var cursor = index
        while cursor > text.startIndex {
            let previous = text.index(before: cursor)
            guard text[previous].isWhitespace else {
                break
            }
            cursor = previous
        }

        let wordEnd = cursor
        while cursor > text.startIndex {
            let previous = text.index(before: cursor)
            guard text[previous].isLetter else {
                break
            }
            cursor = previous
        }

        guard cursor < wordEnd else {
            return nil
        }
        return String(text[cursor..<wordEnd]).lowercased()
    }

    private static func wordRange(in text: String, from start: String.Index) -> Range<String.Index>? {
        guard start < text.endIndex, text[start].isLetter else {
            return nil
        }

        var cursor = start
        while cursor < text.endIndex, text[cursor].isLetter {
            cursor = text.index(after: cursor)
        }

        return start..<cursor
    }

    private static func skipWhitespace(in text: String, from start: String.Index) -> String.Index {
        var cursor = start
        while cursor < text.endIndex, text[cursor].isWhitespace {
            cursor = text.index(after: cursor)
        }
        return cursor
    }

    private static func isInsideInlineCode(in text: String, at index: String.Index) -> Bool {
        var backtickCount = 0
        var cursor = text.startIndex

        while cursor < index {
            if text[cursor] == "`" {
                backtickCount += 1
            }
            cursor = text.index(after: cursor)
        }

        return !backtickCount.isMultiple(of: 2)
    }

    private static func minIndex(
        _ end: String.Index,
        offsetBy offset: Int,
        from start: String.Index,
        in text: String
    ) -> String.Index {
        text.index(start, offsetBy: offset, limitedBy: end) ?? end
    }

    private static let existingUnicodeSubscriptScalars: [String: String] = [
        "₀": "0",
        "₁": "1",
        "₂": "2",
        "₃": "3",
        "₄": "4",
        "₅": "5",
        "₆": "6",
        "₇": "7",
        "₈": "8",
        "₉": "9",
        "₊": "+",
        "₋": "-",
        "ᵢ": "i",
        "ⱼ": "j",
        "ₖ": "k",
        "ₙ": "n",
        "ₜ": "t"
    ]
}
