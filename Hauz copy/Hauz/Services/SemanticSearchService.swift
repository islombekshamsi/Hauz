import Foundation
import Supabase

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

/// Service responsible for semantic search using OpenAI embeddings
final class SemanticSearchService {
    
    /// Generate embedding for a user query using OpenAI API
    /// - Parameter query: The natural language search query
    /// - Returns: Array of 1536 floating point numbers representing the embedding
    nonisolated func generateEmbedding(for query: String) async throws -> [Double] {
        guard !query.isEmpty else {
            throw SemanticSearchError.emptyQuery
        }
        
        let apiKey = AppSecrets.openAIKey // From Secrets.swift
        let url = URL(string: "https://api.openai.com/v1/embeddings")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "model": "text-embedding-3-small",
            "input": query
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SemanticSearchError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw SemanticSearchError.apiError(statusCode: httpResponse.statusCode)
        }
        
        struct EmbeddingResponse: Decodable {
            struct EmbeddingData: Decodable {
                let embedding: [Double]
            }
            let data: [EmbeddingData]
        }
        
        let embeddingResponse = try JSONDecoder().decode(EmbeddingResponse.self, from: data)
        
        guard let embedding = embeddingResponse.data.first?.embedding else {
            throw SemanticSearchError.noEmbeddingReturned
        }
        
        print("✅ Generated embedding with \(embedding.count) dimensions")
        return embedding
    }
    
    /// Search sneakers using semantic similarity
    /// - Parameters:
    ///   - query: Natural language search query (e.g., "basketball shoes", "something cool")
    ///   - gender: Optional gender filter ("Male" or "Female")
    ///   - priceMin: Minimum price filter
    ///   - priceMax: Maximum price filter
    /// - Returns: Array of matching sneaker cards sorted by similarity
    nonisolated func searchSneakers(
        query: String,
        gender: String?,
        priceMin: Double,
        priceMax: Double
    ) async throws -> [SneakerCard] {
        // Generate embedding for the query
        let embedding = try await generateEmbedding(for: query)
        
        // Normalize gender for DB query (Male -> men, Female -> women)
        let normalizedGender: String? = {
            guard let gender = gender else { return nil }
            switch gender.lowercased() {
            case "male": return "men"
            case "female": return "women"
            default: return gender.lowercased()
            }
        }()
        
        print("🔍 Searching with query: '\(query)', gender: \(normalizedGender ?? "any"), price: $\(priceMin)-$\(priceMax)")
        
        // Call Supabase RPC via REST to avoid actor isolation issues with the SDK
        print("🔧 Building RPC URL...")
        let rpcURL = AppSecrets.supabaseURL.appendingPathComponent("/rest/v1/rpc/search_sneakers_semantic")
        print("🔧 RPC URL: \(rpcURL.absoluteString)")
        
        print("🔧 Creating URLRequest...")
        var request = URLRequest(url: rpcURL)
        print("🔧 Setting HTTP method...")
        request.httpMethod = "POST"
        print("🔧 Setting timeout...")
        request.timeoutInterval = 30 // 30 second timeout
        print("🔧 Setting headers...")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(AppSecrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(AppSecrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        print("🔧 Headers set successfully")
        
        print("🔧 Preparing request body dictionary...")
        let body: [String: Any?] = [
            "query_embedding": embedding,
            "match_threshold": 0.7,
            "match_count": 40,
            "gender_filter": normalizedGender,
            "price_min": priceMin,
            "price_max": priceMax
        ]
        print("🔧 Body dictionary created (embedding size: \(embedding.count))")
        
        print("🔧 Serializing JSON body...")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })
            print("🔧 Body size: \(request.httpBody?.count ?? 0) bytes")
        } catch {
            print("❌ Failed to serialize JSON: \(error)")
            throw SemanticSearchError.invalidResponse
        }
        
        print("📡 Sending RPC request to Supabase...")
        let startTime = Date()
        let (data, response) = try await URLSession.shared.data(for: request)
        let duration = Date().timeIntervalSince(startTime)
        print("⏱️ RPC request completed in \(String(format: "%.2f", duration))s")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SemanticSearchError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            // Log the error response for debugging
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ Supabase error response: \(errorString)")
            }
            throw SemanticSearchError.apiError(statusCode: httpResponse.statusCode)
        }
        
        let results = try JSONDecoder().decode([SearchResult].self, from: data)
        print("✅ Found \(results.count) matching sneakers (before filtering swiped)")
        
        // Convert to SneakerCard objects
        return results.map { result in
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
            return "Invalid response from OpenAI API"
        case .apiError(let statusCode):
            return "OpenAI API error: Status code \(statusCode)"
        case .noEmbeddingReturned:
            return "No embedding returned from OpenAI"
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
        }
    }
}

