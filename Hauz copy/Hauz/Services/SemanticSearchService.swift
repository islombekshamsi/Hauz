
import Foundation
import os

// MARK: - Supporting Types

private struct SearchResult: Decodable, Sendable {
    let id: UUID
    let name: String
    let brand: String?
    let image_url: String?
    let retail_price: Double?
    let gender: String?
    let link: String?
    let similarity: Double
}

// MARK: - Semantic Search Service

struct SemanticSearchConfig: Sendable {
    let supabaseURL: URL
    let supabaseAPIKey: String
    // OpenAI key is NO LONGER HERE - it's secure in Edge Function! 🔒
}

struct SemanticSearchResponse: Sendable {
    let cards: [SneakerCard]
    let usedFallback: Bool
    let searchType: SearchType
}

enum SearchType: String, Sendable {
    case semantic = "semantic"
    case hybrid = "hybrid"
    case filterOnly = "filter"
}

/// Service responsible for semantic search using OpenAI embeddings
final class SemanticSearchService: @unchecked Sendable {
    private let config: SemanticSearchConfig
    private let logger = Logger(subsystem: "Hauz", category: "SemanticSearch")
    
    init(config: SemanticSearchConfig) {
        self.config = config
    }
    
    private nonisolated static func normalizeGender(_ gender: String?) -> String? {
        guard let g = gender?.trimmingCharacters(in: .whitespacesAndNewlines), !g.isEmpty else { return nil }
        switch g.lowercased() {
        case "male", "men", "m": return "men"
        case "female", "women", "w": return "women"
        case "unisex", "u": return "unisex"
        default: return g.lowercased()
        }
    }
    
    /// Generate embedding for a user query using Supabase Edge Function (secure!)
    /// - Parameter query: The natural language search query
    /// - Returns: Array of 1536 floating point numbers representing the embedding
    nonisolated func generateEmbedding(for query: String) async throws -> [Double] {
        guard !query.isEmpty else {
            throw SemanticSearchError.emptyQuery
        }
        
        // Call OUR Edge Function instead of OpenAI directly (OpenAI key is server-side now!)
        let url = config.supabaseURL.appendingPathComponent("/functions/v1/generate-search-embedding")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.supabaseAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let payload: [String: String] = [
            "query": query
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SemanticSearchError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorString = String(data: data, encoding: .utf8) {
                logger.error("Edge Function error: \(errorString, privacy: .public)")
            }
            throw SemanticSearchError.apiError(statusCode: httpResponse.statusCode)
        }
        
        struct EdgeFunctionResponse: Decodable {
            let embedding: [Double]
        }
        
        let embeddingResponse = try JSONDecoder().decode(EdgeFunctionResponse.self, from: data)
        
        logger.info("Generated embedding with \(embeddingResponse.embedding.count, privacy: .public) dimensions")
        return embeddingResponse.embedding
    }
    
    /// Search sneakers using semantic similarity
    /// - Parameters:
    ///   - query: Natural language search query (e.g., "basketball shoes", "something cool")
    ///   - gender: Optional gender filter ("Male" or "Female")
    ///   - priceMin: Minimum price filter
    ///   - priceMax: Maximum price filter
    /// - Returns: Array of matching sneaker cards sorted by similarity
    // Static entrypoint to guarantee there's no accidental actor hop via instance isolation.
    nonisolated static func searchSneakers(
        config: SemanticSearchConfig,
        query: String,
        gender: String?,
        priceMin: Double,
        priceMax: Double
    ) async throws -> SemanticSearchResponse {
        let service = SemanticSearchService(config: config)
        return try await service.searchSneakersImpl(
            query: query,
            gender: gender,
            priceMin: priceMin,
            priceMax: priceMax
        )
    }
    
    // Implementation (instance) kept separate for organization/testing.
    private nonisolated func searchSneakersImpl(
        query: String,
        gender: String?,
        priceMin: Double,
        priceMax: Double
    ) async throws -> SemanticSearchResponse {
        let overallStart = Date()
        logger.info("searchSneakers() started")
        // Generate embedding for the query
        let embedStart = Date()
        let embedding = try await generateEmbedding(for: query)
        logger.info("Embedding step finished in \(Date().timeIntervalSince(embedStart), privacy: .public)s")
        
        // Normalize gender for DB query (Male -> men, Female -> women)
        let normalizedGender = Self.normalizeGender(gender)
        
        logger.info("Semantic search query='\(query, privacy: .public)' gender='\(normalizedGender ?? "any", privacy: .public)' price=\(priceMin, privacy: .public)-\(priceMax, privacy: .public)")
        
        
        func rpcCall(threshold: Double, genderFilter: String?, requestedCount: Int) async throws -> [SearchResult] {
            let rpcURL = config.supabaseURL.appendingPathComponent("/rest/v1/rpc/search_sneakers_semantic")
            
            var request = URLRequest(url: rpcURL)
            request.httpMethod = "POST"
            request.timeoutInterval = 10  // Reduced from 30s - faster fail if slow
            request.cachePolicy = .reloadIgnoringLocalCacheData  // Don't cache POST requests
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("keep-alive", forHTTPHeaderField: "Connection")  // Connection reuse
            
            let apiKey = config.supabaseAPIKey
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue(apiKey, forHTTPHeaderField: "apikey")
            
            // Send embedding as a JSON array of numbers (PostgREST will cast to vector type)
            let body: [String: Any?] = [
                "query_embedding": embedding,
                "match_threshold": threshold,
                "match_count": requestedCount,
                "gender_filter": genderFilter,
                "price_min": priceMin,
                "price_max": priceMax
            ]
            
            let encodeStart = Date()
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })
            } catch {
                logger.error("Failed to serialize RPC JSON body: \(String(describing: error), privacy: .public)")
                throw SemanticSearchError.invalidResponse
            }
            logger.info("RPC JSON encoded in \(Date().timeIntervalSince(encodeStart), privacy: .public)s (bytes=\(request.httpBody?.count ?? 0, privacy: .public)) threshold=\(threshold, privacy: .public) gender=\(genderFilter ?? "any", privacy: .public)")
            
            logger.info("Sending Supabase RPC request...")
            let rpcStart = Date()
            let (data, response) = try await URLSession.shared.data(for: request)
            let rpcDuration = Date().timeIntervalSince(rpcStart)
            logger.info("Supabase RPC completed in \(rpcDuration, privacy: .public)s (bytes=\(data.count, privacy: .public))")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SemanticSearchError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if let errorString = String(data: data, encoding: .utf8) {
                    logger.error("Supabase error status=\(httpResponse.statusCode, privacy: .public) body=\(errorString, privacy: .public)")
                }
                throw SemanticSearchError.apiError(statusCode: httpResponse.statusCode)
            }
            
            let decodeStart = Date()
            let results = try JSONDecoder().decode([SearchResult].self, from: data)
            logger.info("Decoded results in \(Date().timeIntervalSince(decodeStart), privacy: .public)s")
            return results
        }
        
        // SPEED: Try with 40 results first (faster), fallback to 60 if needed
        var results = try await rpcCall(threshold: 0.6, genderFilter: normalizedGender, requestedCount: 40)
        logger.info("Found \(results.count, privacy: .public) matches at threshold=0.6 gender=\(normalizedGender ?? "any", privacy: .public)")
        
        var usedFallback = false
        if results.isEmpty {
            logger.info("0 matches at threshold=0.6; falling back to top matches (threshold=-1, keeping gender+price)")
            results = try await rpcCall(threshold: -1.0, genderFilter: normalizedGender, requestedCount: 60)
            logger.info("Fallback returned \(results.count, privacy: .public) matches (gender=\(normalizedGender ?? "any", privacy: .public))")
            usedFallback = true
        }
        
        logger.info("searchSneakers() total time \(Date().timeIntervalSince(overallStart), privacy: .public)s")
        
        let cards = results.map { result in
            SneakerCard(
                id: result.id,
                name: result.name,
                brand: result.brand ?? "Unknown",
                price: result.retail_price,
                imageURL: result.image_url.flatMap(URL.init),
                gender: result.gender,
                stockxLink: result.link
            )
        }
        
        return SemanticSearchResponse(cards: cards, usedFallback: usedFallback, searchType: .semantic)
    }
    
    // MARK: - Hybrid Search (Now using original single embedding for simplicity)
    
    /// Search sneakers using semantic search with single embedding
    /// Reverted from dual-embedding system to use original search_metadata + embedding only
    nonisolated static func searchSneakersHybrid(
        config: SemanticSearchConfig,
        query: String,
        gender: String?,
        priceMin: Double,
        priceMax: Double,
        semanticWeight: Double = 0.5,
        filterWeight: Double = 0.5
    ) async throws -> SemanticSearchResponse {
        let service = SemanticSearchService(config: config)
        // Call the original semantic search implementation (single embedding)
        return try await service.searchSneakersImpl(
            query: query,
            gender: gender,
            priceMin: priceMin,
            priceMax: priceMax
        )
    }
}

// MARK: - Error Types
enum SemanticSearchError: LocalizedError {
    case emptyQuery
    case invalidResponse
    case apiError(statusCode: Int)
    case noEmbeddingReturned
    case databaseError(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "Search query cannot be empty"
        case .invalidResponse:
            return "Invalid response from the server"
        case .apiError(let statusCode):
            if statusCode == 500 {
                return "Search timed out on the server. Please try again."
            }
            return "Search request failed (status \(statusCode)). Please try again."
        case .noEmbeddingReturned:
            return "No embedding returned from OpenAI"
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
        }
    }
}
