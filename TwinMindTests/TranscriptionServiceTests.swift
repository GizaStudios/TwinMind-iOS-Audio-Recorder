import XCTest
@testable import TwinMind

final class TranscriptionServiceTests: XCTestCase {
    private class URLProtocolStub: URLProtocol {
        static var responseData: Data?
        static var statusCode: Int = 200

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            let response = HTTPURLResponse(url: request.url!, statusCode: Self.statusCode, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data = Self.responseData {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let stubSession = URLSession(configuration: config)
        TranscriptionService.sessionProvider = { stubSession }
    }

    override func tearDown() {
        TranscriptionService.sessionProvider = { URLSession(configuration: .ephemeral) }
        super.tearDown()
    }

    func testTranscriptionSuccessReturnsText() async throws {
        let expectedText = "Hello world"
        URLProtocolStub.statusCode = 200
        URLProtocolStub.responseData = "{\"text\": \"\(expectedText)\"}".data(using: .utf8)
        // supply dummy fileURL (file doesn't need to exist because protocol intercepts first)
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("dummy.caf")
        try "data".data(using: .utf8)?.write(to: tmp)

        let text = try await TranscriptionService.transcribeAudio(at: tmp)
        XCTAssertEqual(text, expectedText)
    }

    func testTranscriptionFailureThrows() async {
        URLProtocolStub.statusCode = 500
        URLProtocolStub.responseData = "Server error".data(using: .utf8)
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("dummy2.caf")
        try? "data".data(using: .utf8)?.write(to: tmp)

        do {
            _ = try await TranscriptionService.transcribeAudio(at: tmp)
            XCTFail("Expected error not thrown")
        } catch {
            // success
        }
    }
} 