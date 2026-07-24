import XCTest
@testable import VoiceInputApp

final class QwenHelperClientTests: XCTestCase {
    func testBuildsDefaultBaseURL() {
        let client = QwenHelperClient()
        XCTAssertEqual(client.baseURL.absoluteString, "http://127.0.0.1:8765")
    }

    func testSendsAuthTokenHeader() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [QwenHelperClientTestURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let expectedToken = "test-token"

        QwenHelperClientTestURLProtocol.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-VoiceInput-Token"), expectedToken)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(#"{"ok":true,"engine":"qwen3-asr-mlx"}"#.utf8))
        }
        defer { QwenHelperClientTestURLProtocol.handler = nil }

        let client = QwenHelperClient(
            baseURL: URL(string: "http://127.0.0.1:49152")!,
            authToken: expectedToken,
            session: session
        )

        let health = try await client.health()
        XCTAssertTrue(health.ok)
    }

    func testDecodesExpandedModelStatus() async throws {
        QwenHelperClientTestURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/models/status")
            XCTAssertEqual(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "Qwen/Qwen3-ASR-1.7B")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = Data(
                #"""
                {
                  "installed": true,
                  "loaded": true,
                  "loading": false,
                  "downloading": false,
                  "progress": 1.0,
                  "phase": "ready",
                  "error_code": null,
                  "operation_id": "operation-1",
                  "updated_at": 1783872000.0,
                  "downloaded_bytes": 1880560703,
                  "total_bytes": 1880560703,
                  "download_source": "modelscope",
                  "model_id": "Qwen/Qwen3-ASR-0.6B",
                  "model_path": "/tmp/VoiceInput/Models/qwen3-asr-0.6b"
                }
                """#.utf8
            )
            return (response, data)
        }
        defer { QwenHelperClientTestURLProtocol.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [QwenHelperClientTestURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = QwenHelperClient(baseURL: URL(string: "http://127.0.0.1:8765")!, session: session)

        let status = try await client.modelStatus(modelID: "Qwen/Qwen3-ASR-1.7B")

        XCTAssertTrue(status.installed)
        XCTAssertTrue(status.loaded)
        XCTAssertEqual(status.downloading, false)
        XCTAssertEqual(status.progress, 1.0)
        XCTAssertEqual(status.phase, .ready)
        XCTAssertNil(status.errorCode)
        XCTAssertEqual(status.operationId, "operation-1")
        XCTAssertEqual(status.updatedAt, 1_783_872_000)
        XCTAssertEqual(status.downloadedBytes, 1_880_560_703)
        XCTAssertEqual(status.totalBytes, 1_880_560_703)
        XCTAssertEqual(status.downloadSource, "modelscope")
        XCTAssertEqual(status.modelId, "Qwen/Qwen3-ASR-0.6B")
        XCTAssertEqual(status.modelPath, "/tmp/VoiceInput/Models/qwen3-asr-0.6b")
    }

    func testLegacyModelStatusWithoutPreparationEvidenceStillDecodes() async throws {
        QwenHelperClientTestURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (
                response,
                Data(
                    #"{"installed":false,"loaded":false,"loading":false,"downloading":false,"progress":null,"model_id":"Qwen/Qwen3-ASR-0.6B","model_path":null}"#.utf8
                )
            )
        }
        defer { QwenHelperClientTestURLProtocol.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [QwenHelperClientTestURLProtocol.self]
        let client = QwenHelperClient(
            baseURL: URL(string: "http://127.0.0.1:8765")!,
            session: URLSession(configuration: configuration)
        )

        let status = try await client.modelStatus(modelID: VoiceInputModel.qwen3ASR06B.modelID)

        XCTAssertEqual(status.phase, .absent)
        XCTAssertNil(status.errorCode)
        XCTAssertNil(status.operationId)
        XCTAssertNil(status.updatedAt)
        XCTAssertNil(status.downloadedBytes)
        XCTAssertNil(status.totalBytes)
        XCTAssertNil(status.downloadSource)
    }

    func testFailedPreparationStatusExposesTypedErrorWithoutRawHelperMessage() async throws {
        QwenHelperClientTestURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (
                response,
                Data(
                    #"{"installed":false,"loaded":false,"loading":false,"downloading":false,"progress":0.4,"phase":"failed","error_code":"network_unavailable","operation_id":"operation-2","updated_at":1783872001.0,"model_id":"Qwen/Qwen3-ASR-0.6B","model_path":null}"#.utf8
                )
            )
        }
        defer { QwenHelperClientTestURLProtocol.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [QwenHelperClientTestURLProtocol.self]
        let client = QwenHelperClient(
            baseURL: URL(string: "http://127.0.0.1:8765")!,
            session: URLSession(configuration: configuration)
        )

        let status = try await client.modelStatus(modelID: VoiceInputModel.qwen3ASR06B.modelID)

        XCTAssertEqual(status.phase, .failed)
        XCTAssertEqual(status.errorCode, "network_unavailable")
    }

    func testDownloadModelPostsToDownloadEndpoint() async throws {
        QwenHelperClientTestURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/models/download")
            XCTAssertEqual(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "Qwen/Qwen3-ASR-1.7B")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = Data(
                #"""
                {
                  "installed": false,
                  "loaded": false,
                  "loading": true,
                  "downloading": true,
                  "progress": null,
                  "model_id": "Qwen/Qwen3-ASR-0.6B",
                  "model_path": "/tmp/VoiceInput/Models/qwen3-asr-0.6b"
                }
                """#.utf8
            )
            return (response, data)
        }
        defer { QwenHelperClientTestURLProtocol.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [QwenHelperClientTestURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = QwenHelperClient(baseURL: URL(string: "http://127.0.0.1:8765")!, session: session)

        let status = try await client.downloadModel(modelID: "Qwen/Qwen3-ASR-1.7B")

        XCTAssertEqual(status.loading, true)
        XCTAssertEqual(status.downloading, true)
    }

    func testHttpErrorsIncludeHelperDetailMessage() async throws {
        QwenHelperClientTestURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 503,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = Data(
                #"""
                {
                  "detail": {
                    "code": "audio_resampling_unavailable",
                    "message": "Audio resampling is unavailable."
                  }
                }
                """#.utf8
            )
            return (response, data)
        }
        defer { QwenHelperClientTestURLProtocol.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [QwenHelperClientTestURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = QwenHelperClient(baseURL: URL(string: "http://127.0.0.1:8765")!, session: session)

        do {
            _ = try await client.modelStatus(modelID: "Qwen/Qwen3-ASR-0.6B")
            XCTFail("Expected helper error")
        } catch QwenHelperClientError.httpStatus(let code, let message) {
            XCTAssertEqual(code, 503)
            XCTAssertEqual(message, "Audio resampling is unavailable.")
        }
    }

    func testTranscribeIncludesContextFormField() async throws {
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        try Data("RIFFfake".utf8).write(to: audioURL)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        QwenHelperClientTestURLProtocol.handler = { request in
            let body = String(data: request.bodyDataForTesting(), encoding: .utf8) ?? ""
            XCTAssertEqual(request.timeoutInterval, 120)
            XCTAssertTrue(body.contains("name=\"context\""))
            XCTAssertTrue(body.contains("name=\"model_id\""))
            XCTAssertTrue(body.contains("name=\"strategy\""))
            XCTAssertTrue(body.contains("Qwen/Qwen3-ASR-1.7B"))
            XCTAssertTrue(body.contains("Claude Code Qwen3-ASR"))
            XCTAssertTrue(body.contains("full"))
            let data = Data(#"{"text":"Claude Code"}"#.utf8)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, data)
        }
        defer { QwenHelperClientTestURLProtocol.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [QwenHelperClientTestURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = QwenHelperClient(baseURL: URL(string: "http://127.0.0.1:8765")!, session: session)

        let text = try await client.transcribe(
            wavURL: audioURL,
            modelID: "Qwen/Qwen3-ASR-1.7B",
            context: "Claude Code Qwen3-ASR"
        )

        XCTAssertEqual(text, "Claude Code")
    }

    func testTranscribeCanRequestChunkedStrategy() async throws {
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        try Data("RIFFfake".utf8).write(to: audioURL)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        QwenHelperClientTestURLProtocol.handler = { request in
            let body = String(data: request.bodyDataForTesting(), encoding: .utf8) ?? ""
            XCTAssertTrue(body.contains("name=\"strategy\""))
            XCTAssertTrue(body.contains("chunked"))
            let data = Data(#"{"text":"retried transcript"}"#.utf8)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, data)
        }
        defer { QwenHelperClientTestURLProtocol.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [QwenHelperClientTestURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = QwenHelperClient(baseURL: URL(string: "http://127.0.0.1:8765")!, session: session)

        let text = try await client.transcribe(
            wavURL: audioURL,
            modelID: "Qwen/Qwen3-ASR-0.6B",
            strategy: .chunked
        )

        XCTAssertEqual(text, "retried transcript")
    }
}

private final class QwenHelperClientTestURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: QwenHelperClientTestError.missingHandler)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private enum QwenHelperClientTestError: Error {
    case missingHandler
}

private extension URLRequest {
    func bodyDataForTesting() -> Data {
        if let httpBody {
            return httpBody
        }

        guard let httpBodyStream else {
            return Data()
        }

        httpBodyStream.open()
        defer { httpBodyStream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while httpBodyStream.hasBytesAvailable {
            let count = httpBodyStream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else {
                break
            }
            data.append(buffer, count: count)
        }
        return data
    }
}
