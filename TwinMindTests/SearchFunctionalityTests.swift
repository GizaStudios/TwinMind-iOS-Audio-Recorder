import XCTest
@testable import TwinMind

final class SearchFunctionalityTests: XCTestCase {
    
    func testSearchHelperFindRanges() {
        let text = "This is a sample transcription with some important words"
        let searchQuery = "important"
        
        let ranges = SearchHelper.findSearchRanges(in: text, searchQuery: searchQuery)
        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(String(text[ranges[0]]), "important")
    }
    
    func testSearchHelperCaseInsensitive() {
        let text = "This is a SAMPLE transcription"
        let searchQuery = "sample"
        
        let ranges = SearchHelper.findSearchRanges(in: text, searchQuery: searchQuery)
        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(String(text[ranges[0]]), "SAMPLE")
    }
    
    func testSearchHelperMultipleMatches() {
        let text = "The word word appears multiple times in this word text"
        let searchQuery = "word"
        
        let ranges = SearchHelper.findSearchRanges(in: text, searchQuery: searchQuery)
        XCTAssertEqual(ranges.count, 3)
        for range in ranges {
            XCTAssertEqual(String(text[range]), "word")
        }
    }
    
    func testSearchHelperSnippetExtraction() {
        let text = "This is a very long transcription text that contains the search term somewhere in the middle of the text and should be extracted properly"
        let searchQuery = "search term"
        
        let snippet = SearchHelper.extractSearchSnippet(from: text, searchQuery: searchQuery)
        XCTAssertTrue(snippet.contains("search term"))
        XCTAssertTrue(snippet.contains("..."))
    }
    
    func testSearchHelperTextContainsQuery() {
        let text = "Sample transcription text"
        
        XCTAssertTrue(SearchHelper.textContainsQuery(text, query: "sample"))
        XCTAssertTrue(SearchHelper.textContainsQuery(text, query: "transcription"))
        XCTAssertFalse(SearchHelper.textContainsQuery(text, query: "missing"))
        XCTAssertFalse(SearchHelper.textContainsQuery(text, query: ""))
    }
    
    func testSearchHelperEmptyQuery() {
        let text = "Sample text"
        
        let ranges = SearchHelper.findSearchRanges(in: text, searchQuery: "")
        XCTAssertEqual(ranges.count, 0)
        
        let snippet = SearchHelper.extractSearchSnippet(from: text, searchQuery: "")
        XCTAssertEqual(snippet, "Sample text")
        
        XCTAssertFalse(SearchHelper.textContainsQuery(text, query: ""))
    }
} 