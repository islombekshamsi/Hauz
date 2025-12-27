import Foundation
import Combine
import Supabase
import PostgREST

/// DTO for sneakers_only rows we care about
struct SneakerCard: Identifiable, Hashable {
    let id: UUID
    let name: String
    let brand: String
    let price: Double?
    let imageURL: URL?
    let gender: String?
    let stockxLink: String?
}

/// DTO for a swipe event
struct SwipeEvent {
    let sneakerID: UUID
    let direction: String // "right" or "left"
}

/// Service responsible for fetching feed items and recording swipes.
@MainActor
final class FeedService: ObservableObject {
    @Published private(set) var feed: [SneakerCard] = []
    @Published private(set) var liked: [SneakerCard] = []
    @Published private(set) var noResultsForFilters: Bool = false
    
    private var swipedRightIDs: Set<UUID> = []
    private var swipedLeftIDs: Set<UUID> = []
    private var cachedProfile: Profile?
    private let pageSize = 40
    private var preferredOffset = 0
    private var exploratoryOffset = 0
    private var isLoadingMore = false
    
    /// Load initial data: swipes + feed + liked list.
    func load() async {
        do {
            let swipes = try await fetchSwipes()
            swipedRightIDs = Set(swipes.filter { $0.direction == "right" }.map { $0.sneakerID })
            swipedLeftIDs = Set(swipes.filter { $0.direction == "left" }.map { $0.sneakerID })
            
            preferredOffset = 0
            exploratoryOffset = 0
            
            let profile = await fetchProfileOrNil()
            cachedProfile = profile
            
            print("🔍 FeedService.load: profile gender = \(profile?.gender ?? "nil"), brands = \(profile?.brands ?? [])")
            
            let cards = try await fetchSneakers(profile: profile, preferredOffset: preferredOffset, exploratoryOffset: exploratoryOffset)
            let likedCards = try await fetchLikedDetails()
            
            print("🔍 FeedService.load: fetched \(cards.count) cards")
            
            feed = cards.filter { !swipedRightIDs.contains($0.id) && !swipedLeftIDs.contains($0.id) }
            liked = likedCards
            
            // Track if filters are too restrictive (no results at all from DB)
            noResultsForFilters = cards.isEmpty
            
            // Advance offsets for next page
            preferredOffset += pageSize
            exploratoryOffset += pageSize
        } catch {
            debugPrint("FeedService load error: \(error)")
        }
    }
    
    /// Load more feed items when running low.
    func loadMore() async {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        
        do {
            if feed.isEmpty {
                preferredOffset = 0
                exploratoryOffset = 0
            }
            
            let profile = await fetchProfileOrNil()
            cachedProfile = profile
            
            // On reload, rely only on exploratory (no brand preference)
            var cards = try await fetchExploratorySneakers(profile: profile, offset: exploratoryOffset)
            
            // If we got nothing (e.g. offsets too far), reset offsets once and try again
            if cards.isEmpty {
                preferredOffset = 0
                exploratoryOffset = 0
                cards = try await fetchExploratorySneakers(profile: profile, offset: exploratoryOffset)
            }
            
            // Track if filters are too restrictive
            if cards.isEmpty && feed.isEmpty {
                noResultsForFilters = true
            } else {
                noResultsForFilters = false
            }
            
            // Advance offsets for next page after successful fetch
            preferredOffset += pageSize
            exploratoryOffset += pageSize
            
            // Filter out already known or swiped
            let existingIDs = Set(feed.map { $0.id })
            let newCards = cards.filter {
                !existingIDs.contains($0.id) &&
                !swipedRightIDs.contains($0.id) &&
                !swipedLeftIDs.contains($0.id)
            }
            
            feed.append(contentsOf: newCards)
            
            // Fallback: if still nothing was appended, hard reset offsets and try once more
            if newCards.isEmpty {
                preferredOffset = 0
                exploratoryOffset = 0
                let retry = try await fetchExploratorySneakers(profile: profile, offset: exploratoryOffset)
                let retryNew = retry.filter {
                    !existingIDs.contains($0.id) &&
                    !swipedRightIDs.contains($0.id) &&
                    !swipedLeftIDs.contains($0.id)
                }
                feed.append(contentsOf: retryNew)
                preferredOffset += pageSize
                exploratoryOffset += pageSize
            }
        } catch {
            debugPrint("FeedService loadMore error: \(error)")
        }
    }

    /// Lightweight fetch for ProfileView (public so ProfileView can reuse).
    func fetchLikedForProfile() async throws -> [SneakerCard] {
        try await fetchLikedDetails()
    }
    
    /// Record a swipe and remove it from the in-memory feed.
    func swipe(_ event: SwipeEvent) async {
        feed.removeAll { $0.id == event.sneakerID }
        if event.direction == "right" {
            swipedRightIDs.insert(event.sneakerID)
        } else {
            swipedLeftIDs.insert(event.sneakerID)
        }
        
        do {
            try await recordSwipe(event)
        } catch {
            debugPrint("Failed to record swipe: \(error)")
        }
    }
}

// MARK: - Private helpers
private extension FeedService {
    func fetchProfile() async throws -> Profile? {
        let session = try await supabase.auth.session
        let userId = session.user.id
        let profile: Profile = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        return profile
    }

    func fetchProfileOrNil() async -> Profile? {
        do {
            return try await fetchProfile()
        } catch {
            debugPrint("Profile fetch optional failure: \(error)")
            return nil
        }
    }
    
    func fetchSwipes() async throws -> [SwipeEvent] {
        let session = try await supabase.auth.session
        struct Row: Decodable { let sneaker_id: UUID; let direction: String }
        let rows: [Row] = try await supabase
            .from("user_swipes")
            .select("sneaker_id,direction")
            .eq("user_id", value: session.user.id)
            .execute()
            .value
        return rows.map { .init(sneakerID: $0.sneaker_id, direction: $0.direction) }
    }
    
    func fetchLikedDetails() async throws -> [SneakerCard] {
        let session = try await supabase.auth.session
        struct Row: Decodable {
            let sneaker_id: UUID
            let sneakers_only: SneakerRow
        }
        let rows: [Row] = try await supabase
            .from("user_swipes")
            .select("sneaker_id, direction, sneakers_only!inner (id, name, brand, image_url, retail_price, gender, link)")
            .eq("user_id", value: session.user.id)
            .eq("direction", value: "right")
            .execute()
            .value
        
        return rows.map { row in
            SneakerCard(
                id: row.sneaker_id,
                name: row.sneakers_only.name,
                brand: row.sneakers_only.brand ?? "Unknown",
                price: row.sneakers_only.retail_price,
                imageURL: row.sneakers_only.image_url.flatMap(URL.init),
                gender: row.sneakers_only.gender,
                stockxLink: row.sneakers_only.link
            )
        }
    }
    
    func fetchSneakers(profile: Profile?, preferredOffset: Int, exploratoryOffset: Int) async throws -> [SneakerCard] {
        // Basic preference-aware fetch:
        // - filter by gender if set
        // - prefer brands the user selected, but allow exploration by mixing in others
        let gender = profile?.gender
        let brands = profile?.brands ?? []
        let excluded = swipedRightIDs.union(swipedLeftIDs)
        
        // Two buckets: preferred brands, and exploration
        let preferred: [SneakerRow] = try await querySneakers(limit: pageSize, offset: preferredOffset, gender: gender, brands: brands.isEmpty ? nil : brands, excludeIDs: excluded)
        let exploratory: [SneakerRow] = try await querySneakers(limit: pageSize, offset: exploratoryOffset, gender: gender, brands: nil, excludeIDs: excluded)
        
        // Combine, prioritize preferred, then fill with exploratory excluding dupes
        var combined: [SneakerRow] = []
        var seen = Set<UUID>()
        for row in preferred {
            if !seen.contains(row.id) {
                combined.append(row)
                seen.insert(row.id)
            }
        }
        for row in exploratory {
            if !seen.contains(row.id) {
                combined.append(row)
                seen.insert(row.id)
            }
        }
        
        var mapped = combined.map { row in
            SneakerCard(
                id: row.id,
                name: row.name,
                brand: row.brand ?? "Unknown",
                price: row.retail_price,
                imageURL: row.image_url.flatMap(URL.init),
                gender: row.gender,
                stockxLink: row.link
            )
        }

        // If nothing found (e.g., gender mismatch), fall back to gender-agnostic fetch (still excluding swipes)
        if mapped.isEmpty {
            let fallback: [SneakerRow] = try await querySneakers(limit: pageSize, offset: 0, gender: nil, brands: nil, excludeIDs: excluded)
            mapped = fallback.map { row in
                SneakerCard(
                    id: row.id,
                    name: row.name,
                    brand: row.brand ?? "Unknown",
                    price: row.retail_price,
                    imageURL: row.image_url.flatMap(URL.init),
                    gender: row.gender,
                    stockxLink: row.link
                )
            }
        }

        return mapped
    }

    func fetchExploratorySneakers(profile: Profile?, offset: Int) async throws -> [SneakerCard] {
        let gender = profile?.gender
        let excluded = swipedRightIDs.union(swipedLeftIDs)
        
        print("🔍 fetchExploratorySneakers: gender from profile = \(gender ?? "nil")")
        
        // Try with gender first
        var exploratory: [SneakerRow] = try await querySneakers(limit: pageSize, offset: offset, gender: gender, brands: nil, excludeIDs: excluded)
        
        // If we got 0 results and gender was set, try without gender
        if exploratory.isEmpty && gender != nil {
            print("⚠️ fetchExploratorySneakers: got 0 results with gender '\(gender!)', retrying without gender")
            exploratory = try await querySneakers(limit: pageSize, offset: offset, gender: nil, brands: nil, excludeIDs: excluded)
        }
        
        return exploratory.map { row in
            SneakerCard(
                id: row.id,
                name: row.name,
                brand: row.brand ?? "Unknown",
                price: row.retail_price,
                imageURL: row.image_url.flatMap(URL.init),
                gender: row.gender,
                stockxLink: row.link
            )
        }
    }
    
    func querySneakers(limit: Int, offset: Int, gender: String?, brands: [String]?, excludeIDs: Set<UUID>) async throws -> [SneakerRow] {
        var collected: [SneakerRow] = []
        var attempts = 0
        let maxAttempts = 5
        let batchSize = 100 // Fetch 100 at a time
        
        // Get price range from cached profile
        let priceMin = cachedProfile?.priceMin ?? 0
        let priceMax = cachedProfile?.priceMax ?? 10000
        
        // Normalize gender: "Male" -> "men", "Female" -> "women"
        let normalizedGender: String? = {
            guard let gender = gender else { return nil }
            switch gender.lowercased() {
            case "male": return "men"
            case "female": return "women"
            default: return gender.lowercased()
            }
        }()
        
        // Keep fetching batches until we have enough unique cards or hit max attempts
        while collected.count < limit && attempts < maxAttempts {
            // Use random offset to avoid always hitting the same swiped shoes
            let randomOffset = offset + (attempts * batchSize) + Int.random(in: 0...200)
            
            var query = supabase
                .from("sneakers_only")
                .select("""
                    id,
                    name,
                    brand,
                    image_url,
                    retail_price,
                    gender,
                    link
                """)
            
            if let normalizedGender, !normalizedGender.isEmpty {
                query = query.eq("gender", value: normalizedGender)
                print("🔍 querySneakers: filtering by gender = \(normalizedGender)")
            }
            if let brands, !brands.isEmpty {
                query = query.in("brand", values: brands)
            }
            
            // Add price range filters (exclude $0 and null prices)
            query = query
                .gt("retail_price", value: 0)  // Must be greater than $0
                .gte("retail_price", value: priceMin)
                .lte("retail_price", value: priceMax)
            
            let rows: [SneakerRow] = try await query
                .order("created_at", ascending: false)
                .range(from: randomOffset, to: randomOffset + batchSize - 1)
                .execute()
                .value
            
            // Debug: Log what genders we're actually getting from DB
            if attempts == 0 {
                let genderCounts = Dictionary(grouping: rows, by: { $0.gender ?? "nil" })
                    .mapValues { $0.count }
                print("🔍 querySneakers: DB returned genders: \(genderCounts)")
            }
            
            // Filter out excluded IDs and already collected ones
            let collectedIDs = Set(collected.map { $0.id })
            let freshRows = rows.filter { !excludeIDs.contains($0.id) && !collectedIDs.contains($0.id) }
            
            collected.append(contentsOf: freshRows)
            attempts += 1
            
            // If we got nothing new, break to avoid infinite loop
            if freshRows.isEmpty && rows.count < batchSize {
                break
            }
        }
        
        // Apply brand diversification to avoid showing too many shoes from the same brand
        let diversified = diversifyByBrand(collected, targetCount: limit)
        
        return diversified
    }
    
    /// Diversifies sneakers by brand to prevent one brand from dominating the feed
    /// Uses a round-robin approach to distribute brands evenly
    private func diversifyByBrand(_ sneakers: [SneakerRow], targetCount: Int) -> [SneakerRow] {
        guard !sneakers.isEmpty else { return [] }
        
        // Group sneakers by brand
        var brandGroups: [String: [SneakerRow]] = [:]
        for sneaker in sneakers {
            let brand = sneaker.brand ?? "Unknown"
            brandGroups[brand, default: []].append(sneaker)
        }
        
        // Shuffle each brand's shoes for variety
        for brand in brandGroups.keys {
            brandGroups[brand]?.shuffle()
        }
        
        // Get brand keys sorted by count (descending) for fair distribution
        let sortedBrands = brandGroups.keys.sorted { brand1, brand2 in
            brandGroups[brand1]!.count > brandGroups[brand2]!.count
        }
        
        // Round-robin selection to mix brands
        var result: [SneakerRow] = []
        var brandIndices: [String: Int] = sortedBrands.reduce(into: [:]) { $0[$1] = 0 }
        
        // Keep cycling through brands until we have enough shoes
        var currentBrandIndex = 0
        while result.count < targetCount && result.count < sneakers.count {
            let brand = sortedBrands[currentBrandIndex % sortedBrands.count]
            
            if let index = brandIndices[brand],
               let shoes = brandGroups[brand],
               index < shoes.count {
                result.append(shoes[index])
                brandIndices[brand] = index + 1
            }
            
            currentBrandIndex += 1
            
            // Safety check: if we've cycled through all brands and no one added anything, break
            if currentBrandIndex > sortedBrands.count * 100 {
                break
            }
        }
        
        return result
    }
    
    func recordSwipe(_ event: SwipeEvent) async throws {
        let session = try await supabase.auth.session
        struct Payload: Encodable {
            let user_id: UUID
            let sneaker_id: UUID
            let direction: String
        }
        let payload = Payload(user_id: session.user.id, sneaker_id: event.sneakerID, direction: event.direction)
        _ = try await supabase
            .from("user_swipes")
            .upsert(payload, onConflict: "user_id,sneaker_id")
            .select()
            .single()
            .execute()
    }
}

// MARK: - Rows
private struct SneakerRow: Decodable {
    let id: UUID
    let name: String
    let brand: String?
    let image_url: String?
    let retail_price: Double?
    let gender: String?
    let link: String?
}

