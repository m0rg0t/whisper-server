import XCTest
@testable import WhisperServer

final class SubtitleFormatterTests: XCTestCase {
    private typealias Segment = WhisperSubtitleFormatter.TranscriptionSegment

    func testSRTCuesRemainConsecutiveAfterEmptySegments() {
        let segments = [
            Segment(startTime: 0, endTime: 1, text: "  \n"),
            Segment(startTime: 1, endTime: 2, text: " First "),
            Segment(startTime: 2, endTime: 3, text: ""),
            Segment(startTime: 3, endTime: 4, text: "Second")
        ]
        XCTAssertEqual(WhisperSubtitleFormatter.formatAsSRT(segments: segments),
                       "1\n00:00:01,000 --> 00:00:02,000\nFirst\n\n" +
                       "2\n00:00:03,000 --> 00:00:04,000\nSecond\n\n")
    }

    func testEmptySubtitleOutputPreservesFormatHeaders() {
        let segments = [Segment(startTime: 0, endTime: 1, text: " \n ")]
        XCTAssertEqual(WhisperSubtitleFormatter.formatAsSRT(segments: segments), "")
        XCTAssertEqual(WhisperSubtitleFormatter.formatAsVTT(segments: segments), "WEBVTT\n\n")
    }

    func testVTTKeepsUnicodeAndTimestampSeparators() {
        let segments = [Segment(startTime: 1.25, endTime: 2.5, text: " Привет 👋 ")]
        XCTAssertEqual(WhisperSubtitleFormatter.formatAsVTT(segments: segments),
                       "WEBVTT\n\n00:00:01.250 --> 00:00:02.500\nПривет 👋\n\n")
    }

    func testVerboseJSONEscapesSyntheticTextAndSkipsEmptySegments() throws {
        let segments = [
            Segment(startTime: 0, endTime: 1, text: ""),
            Segment(startTime: 1, endTime: 2, text: "a \"quote\"\\path\nПривет")
        ]
        let text = WhisperSubtitleFormatter.formatAsVerboseJSON(segments: segments)
        let value = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        let output = try XCTUnwrap(value["segments"] as? [[String: Any]])
        XCTAssertEqual(output.count, 1)
        XCTAssertEqual(output[0]["text"] as? String, segments[1].text)
        XCTAssertEqual(value["text"] as? String, segments[1].text)
    }

    @MainActor
    func testHostedUnitTestsDoNotInitializeRuntimeServices() {
        XCTAssertEqual(ProcessInfo.processInfo.environment["WHISPER_SERVER_UNIT_TESTS"], "1")
        XCTAssertFalse(AppDelegate().hasRuntimeServices)
    }
}
