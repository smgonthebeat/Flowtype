import Foundation

struct QwenHealth: Decodable {
    let ok: Bool
    let engine: String
}

enum QwenModelPreparationPhase: String, Decodable {
    case absent
    case downloading
    case loading
    case installed
    case ready
    case failed
}

struct QwenModelStatus: Decodable {
    let installed: Bool
    let loaded: Bool
    let loading: Bool?
    let downloading: Bool?
    let progress: Double?
    let phase: QwenModelPreparationPhase
    let errorCode: String?
    let operationId: String?
    let updatedAt: TimeInterval?
    let modelId: String
    let modelPath: String?

    enum CodingKeys: String, CodingKey {
        case installed
        case loaded
        case loading
        case downloading
        case progress
        case phase
        case errorCode = "error_code"
        case operationId = "operation_id"
        case updatedAt = "updated_at"
        case modelId = "model_id"
        case modelPath = "model_path"
    }

    init(
        installed: Bool,
        loaded: Bool,
        loading: Bool?,
        downloading: Bool?,
        progress: Double?,
        modelId: String,
        modelPath: String?,
        phase: QwenModelPreparationPhase? = nil,
        errorCode: String? = nil,
        operationId: String? = nil,
        updatedAt: TimeInterval? = nil
    ) {
        self.installed = installed
        self.loaded = loaded
        self.loading = loading
        self.downloading = downloading
        self.progress = progress
        self.phase = phase ?? Self.legacyPhase(
            installed: installed,
            loaded: loaded,
            loading: loading,
            downloading: downloading
        )
        self.errorCode = errorCode
        self.operationId = operationId
        self.updatedAt = updatedAt
        self.modelId = modelId
        self.modelPath = modelPath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let installed = try container.decode(Bool.self, forKey: .installed)
        let loaded = try container.decode(Bool.self, forKey: .loaded)
        let loading = try container.decodeIfPresent(Bool.self, forKey: .loading)
        let downloading = try container.decodeIfPresent(Bool.self, forKey: .downloading)
        self.init(
            installed: installed,
            loaded: loaded,
            loading: loading,
            downloading: downloading,
            progress: try container.decodeIfPresent(Double.self, forKey: .progress),
            modelId: try container.decode(String.self, forKey: .modelId),
            modelPath: try container.decodeIfPresent(String.self, forKey: .modelPath),
            phase: try container.decodeIfPresent(QwenModelPreparationPhase.self, forKey: .phase),
            errorCode: try container.decodeIfPresent(String.self, forKey: .errorCode),
            operationId: try container.decodeIfPresent(String.self, forKey: .operationId),
            updatedAt: try container.decodeIfPresent(TimeInterval.self, forKey: .updatedAt)
        )
    }

    private static func legacyPhase(
        installed: Bool,
        loaded: Bool,
        loading: Bool?,
        downloading: Bool?
    ) -> QwenModelPreparationPhase {
        if loaded { return .ready }
        if downloading == true { return .downloading }
        if loading == true { return .loading }
        if installed { return .installed }
        return .absent
    }
}

struct QwenTranscript: Decodable {
    let text: String
}

enum QwenTranscriptionStrategy: String {
    case full
    case chunked
}

protocol QwenTranscriptionClient {
    func transcribe(
        wavURL: URL,
        modelID: String,
        context: String,
        strategy: QwenTranscriptionStrategy
    ) async throws -> String
}

final class QwenHelperClient: QwenTranscriptionClient {
    private static let transcriptionTimeout: TimeInterval = 120

    let baseURL: URL
    private let authToken: String?
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(
        baseURL: URL = URL(string: "http://127.0.0.1:8765")!,
        authToken: String? = nil,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.authToken = authToken
        self.session = session
    }

    func health() async throws -> QwenHealth {
        try await get(path: "/health")
    }

    func modelStatus() async throws -> QwenModelStatus {
        try await modelStatus(modelID: VoiceInputModel.qwen3ASR06B.modelID)
    }

    func modelStatus(modelID: String) async throws -> QwenModelStatus {
        try await get(path: "/models/status", queryItems: [URLQueryItem(name: "model_id", value: modelID)])
    }

    func downloadModel() async throws -> QwenModelStatus {
        try await downloadModel(modelID: VoiceInputModel.qwen3ASR06B.modelID)
    }

    func downloadModel(modelID: String) async throws -> QwenModelStatus {
        var request = URLRequest(url: url(path: "/models/download", queryItems: [URLQueryItem(name: "model_id", value: modelID)]))
        request.httpMethod = "POST"
        applyAuth(to: &request)
        return try await send(request)
    }

    func transcribe(
        wavURL: URL,
        modelID: String,
        context: String = "",
        strategy: QwenTranscriptionStrategy = .full
    ) async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url(path: "/transcribe"))
        request.httpMethod = "POST"
        request.timeoutInterval = Self.transcriptionTimeout
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        applyAuth(to: &request)
        request.httpBody = try await Task.detached(priority: .userInitiated) {
            try Self.multipartBody(fileURL: wavURL, boundary: boundary, fields: [
                "context": context,
                "model_id": modelID,
                "strategy": strategy.rawValue
            ])
        }.value

        let transcript: QwenTranscript = try await send(request)
        return transcript.text
    }

    private func get<T: Decodable>(path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        var request = URLRequest(url: url(path: path, queryItems: queryItems))
        request.httpMethod = "GET"
        applyAuth(to: &request)
        return try await send(request)
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw QwenHelperClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw QwenHelperClientError.httpStatus(
                httpResponse.statusCode,
                Self.errorDetailMessage(from: data)
            )
        }
        return try decoder.decode(T.self, from: data)
    }

    private static func errorDetailMessage(from data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let detail = object["detail"]
        else {
            return nil
        }

        if let message = detail as? String {
            return message
        }
        if let detail = detail as? [String: Any],
           let message = detail["message"] as? String {
            return message
        }
        return nil
    }

    private func url(path: String, queryItems: [URLQueryItem] = []) -> URL {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return components.url!
    }

    private func applyAuth(to request: inout URLRequest) {
        guard let authToken else { return }
        request.setValue(authToken, forHTTPHeaderField: "X-VoiceInput-Token")
    }

    private static func multipartBody(fileURL: URL, boundary: String, fields: [String: String] = [:]) throws -> Data {
        let filename = Self.multipartHeaderSafeFilename(fileURL.lastPathComponent)
        let fileData = try Data(contentsOf: fileURL)
        var body = Data()

        for (name, value) in fields {
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            body.appendString(value)
            body.appendString("\r\n")
        }

        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"audio\"; filename=\"\(filename)\"\r\n")
        body.appendString("Content-Type: audio/wav\r\n\r\n")
        body.append(fileData)
        body.appendString("\r\n--\(boundary)--\r\n")

        return body
    }

    private static func multipartHeaderSafeFilename(_ filename: String) -> String {
        filename
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }
}

extension QwenHelperClient: QwenModelStatusProviding {}

enum QwenHelperClientError: Error, Equatable, LocalizedError {
    case invalidResponse
    case httpStatus(Int, String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from local transcription helper."
        case .httpStatus(_, let message):
            return message
        }
    }
}

private extension Data {
    mutating func appendString(_ string: String) {
        append(Data(string.utf8))
    }
}
