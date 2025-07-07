import Foundation

/// Helper functions for search functionality
struct SearchHelper {
    
    /// Returns ranges of search terms in text for highlighting
    static func findSearchRanges(in text: String, searchQuery: String) -> [Range<String.Index>] {
        guard !searchQuery.isEmpty else { return [] }
        
        let lowercasedText = text.lowercased()
        let lowercasedQuery = searchQuery.lowercased()
        
        guard lowercasedText.contains(lowercasedQuery) else { return [] }
        
        var ranges: [Range<String.Index>] = []
        var searchRange = text.startIndex..<text.endIndex
        
        while let range = text.lowercased().range(of: lowercasedQuery, range: searchRange) {
            ranges.append(range)
            searchRange = range.upperBound..<text.endIndex
        }
        
        return ranges
    }
    
    /// Extracts a snippet of text around the search term for preview
    static func extractSearchSnippet(from text: String, searchQuery: String, maxLength: Int = 100) -> String {
        guard !searchQuery.isEmpty else { return String(text.prefix(maxLength)) }
        
        let lowercasedText = text.lowercased()
        let lowercasedQuery = searchQuery.lowercased()
        
        guard let range = lowercasedText.range(of: lowercasedQuery) else {
            return String(text.prefix(maxLength))
        }
        
        let startIndex = text.index(range.lowerBound, offsetBy: -min(50, text.distance(from: text.startIndex, to: range.lowerBound)))
        let endIndex = text.index(range.upperBound, offsetBy: min(50, text.distance(from: range.upperBound, to: text.endIndex)))
        
        let snippet = String(text[startIndex..<endIndex])
        
        // Add ellipsis if we truncated
        let prefix = startIndex > text.startIndex ? "..." : ""
        let suffix = endIndex < text.endIndex ? "..." : ""
        
        return prefix + snippet + suffix
    }
    
    /// Checks if text contains the search query (case-insensitive)
    static func textContainsQuery(_ text: String, query: String) -> Bool {
        guard !query.isEmpty else { return false }
        return text.lowercased().contains(query.lowercased())
    }
} 