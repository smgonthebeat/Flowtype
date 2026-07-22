import AVFoundation
import XCTest
@testable import VoiceInputApp

final class AudioRecorderTests: XCTestCase {
    func testTranscriptionFileFormatAvoidsHelperResamplingDependency() throws {
        let format = try XCTUnwrap(AudioRecorder.transcriptionFileFormat)

        XCTAssertEqual(format.sampleRate, 16_000)
        XCTAssertEqual(format.channelCount, 1)
        XCTAssertEqual(format.commonFormat, .pcmFormatInt16)
    }
}
