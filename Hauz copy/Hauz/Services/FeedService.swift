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
    let colors: [ShoeColor]?
    var isPinned: Bool = false
}

/// Represents a color extracted from a shoe image
struct ShoeColor: Codable, Hashable {
    let name: String
    let hex: String
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
    @Published private(set) var isSemanticSearchActive: Bool = false
    @Published private(set) var currentSearchQuery: String?
    @Published private(set) var semanticSearchNotice: String?
    @Published private(set) var returnDisabledIDs: Set<UUID> = []
    
    private var swipedRightIDs: Set<UUID> = []
    private var swipedLeftIDs: Set<UUID> = []
    private var cachedProfile: Profile?
    private let pageSize = 40
    private var preferredOffset = 0
    private var exploratoryOffset = 0
    private var isLoadingMore = false
    private var lastSearchSignature: SearchSignature?
    
    /// Load initial data: swipes + feed + liked list.
    func load() async {
        do {
            let swipes = try await fetchSwipes()
            swipedRightIDs = Set(swipes.filter { $0.direction == "right" }.map { $0.sneakerID })
            swipedLeftIDs = Set(swipes.filter { $0.direction == "left" }.map { $0.sneakerID })
            returnDisabledIDs = (try? await fetchReturnDisabledIDs()) ?? []
            
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
            lastSearchSignature = nil
        } catch {
            debugPrint("FeedService load error: \(error)")
        }
    }
    
    /// Load feed using explicit filter values (wand-safe, deterministic by default).
    func loadWithFilters(
        gender: String,
        brands: [String],
        priceMin: Double,
        priceMax: Double,
        randomizeOffsets: Bool = false
    ) async {
        do {
            let swipes = try await fetchSwipes()
            swipedRightIDs = Set(swipes.filter { $0.direction == "right" }.map { $0.sneakerID })
            swipedLeftIDs = Set(swipes.filter { $0.direction == "left" }.map { $0.sneakerID })
            returnDisabledIDs = (try? await fetchReturnDisabledIDs()) ?? []
            
            // IMPORTANT: When applying specific brand filters, ALWAYS reset offsets to 0
            // This prevents offset exhaustion when switching between brands
            if randomizeOffsets && brands.isEmpty {
                // Only randomize if showing all brands (magic wand scenario)
                let jitter = Int.random(in: 0...200) // Reduced from 400 to prevent exhaustion
                preferredOffset = jitter
                exploratoryOffset = jitter
            } else {
                // Reset to 0 for any specific brand filtering
                preferredOffset = 0
                exploratoryOffset = 0
            }
            
            lastSearchSignature = nil
            isSemanticSearchActive = false
            currentSearchQuery = nil
            semanticSearchNotice = nil
            
            let profileOverride = Profile(
                id: nil,
                username: nil,
                fullName: nil,
                gender: gender,
                avatarURL: nil,
                brands: brands,
                phoneNumber: nil,
                priceMin: priceMin,
                priceMax: priceMax,
                swipedRightIds: nil,
                swipedLeftIds: nil,
                updatedAt: nil
            )
            cachedProfile = profileOverride
            
            let cards = try await fetchSneakers(profile: profileOverride, preferredOffset: preferredOffset, exploratoryOffset: exploratoryOffset)
            feed = cards
            noResultsForFilters = cards.isEmpty
            
            // Only advance offsets if we got results
            if !cards.isEmpty {
                preferredOffset += pageSize
                exploratoryOffset += pageSize
            }
        } catch {
            debugPrint("FeedService loadWithFilters error: \(error)")
        }
    }
    
    /// Random exploration using the same filter pipeline (gender only).
    /// Clears brand filters but keeps gender and expands price range for maximum variety.
    func loadRandomExploration() async {
        let profile = await fetchProfileOrNil()
        let gender = profile?.gender ?? ""
        print("✨ loadRandomExploration: clearing brand filters, keeping gender=\(gender)")
        await loadWithFilters(
            gender: gender,
            brands: [],           // Clear brands for exploration
            priceMin: 10,         // Set reasonable minimum to exclude $0 items
            priceMax: 875,        // Keep max reasonable to avoid outliers
            randomizeOffsets: true
        )
    }
    
    /// Load more feed items when running low.
    func loadMore() async {
        guard !isLoadingMore else { 
            print("⏸️ loadMore: already loading, skipping")
            return 
        }
        isLoadingMore = true
        defer { isLoadingMore = false }
        
        do {
            if feed.isEmpty {
                print("🔄 loadMore: feed empty, resetting offsets")
                preferredOffset = 0
                exploratoryOffset = 0
            }
            
            let profile = await fetchProfileOrNil()
            cachedProfile = profile
            
            // On reload, rely only on exploratory (no brand preference)
            var cards = try await fetchExploratorySneakers(profile: profile, offset: exploratoryOffset)
            
            print("🔄 loadMore: fetched \(cards.count) cards at offset \(exploratoryOffset)")
            
            // If we got nothing (e.g. offsets too far), reset offsets once and try again
            if cards.isEmpty && exploratoryOffset > 0 {
                print("🔄 loadMore: got 0 cards, resetting offset and retrying")
                preferredOffset = 0
                exploratoryOffset = 0
                cards = try await fetchExploratorySneakers(profile: profile, offset: exploratoryOffset)
            }
            
            // Track if filters are too restrictive
            if cards.isEmpty && feed.isEmpty {
                noResultsForFilters = true
                print("⚠️ loadMore: no results with current filters")
            } else {
                noResultsForFilters = false
            }
            
            // Filter out already known or swiped
            let existingIDs = Set(feed.map { $0.id })
            let newCards = cards.filter {
                !existingIDs.contains($0.id) &&
                !swipedRightIDs.contains($0.id) &&
                !swipedLeftIDs.contains($0.id)
            }
            
            print("🔄 loadMore: \(newCards.count) new cards after filtering")
            
            // Only advance offsets if we got new cards
            if !newCards.isEmpty {
                feed.append(contentsOf: newCards)
                preferredOffset += pageSize
                exploratoryOffset += pageSize
            } else if !cards.isEmpty {
                // We got cards but they were all filtered out (already seen/swiped)
                // Advance offset anyway to get fresh results next time
                print("🔄 loadMore: all cards filtered out, advancing offset")
                preferredOffset += pageSize
                exploratoryOffset += pageSize
                
                // Try once more with new offset
                let retry = try await fetchExploratorySneakers(profile: profile, offset: exploratoryOffset)
                let retryNew = retry.filter {
                    !existingIDs.contains($0.id) &&
                    !swipedRightIDs.contains($0.id) &&
                    !swipedLeftIDs.contains($0.id)
                }
                if !retryNew.isEmpty {
                    feed.append(contentsOf: retryNew)
                    preferredOffset += pageSize
                    exploratoryOffset += pageSize
                }
            }
            
            print("🔄 loadMore: complete, feed now has \(feed.count) cards")
        } catch {
            debugPrint("❌ FeedService loadMore error: \(error)")
        }
    }
    
    /*
    /// Load a random exploratory batch (gender-only, no filters).
    func loadExploratoryGenderOnly() async {
        do {
            let profile = await fetchProfileOrNil()
            cachedProfile = profile
            let gender = profile?.gender
            let excluded = swipedRightIDs.union(swipedLeftIDs)
            
            let cards = try await querySneakersGenderOnly(
                limit: pageSize,
                offset: 0,
                gender: gender,
                excludeIDs: excluded
            )
            
            feed = cards.map { row in
                SneakerCard(
                    id: row.id,
                    name: row.name,
                    brand: row.brand ?? "Unknown",
                    price: row.retail_price,
                    imageURL: row.image_url.flatMap(URL.init),
                    gender: row.gender,
                    stockxLink: row.link,
                    colors: row.colors
                )
            }
            
            noResultsForFilters = feed.isEmpty
        } catch {
            debugPrint("Exploratory gender-only load error: \(error)")
        }
    }
    */

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
    
    /// Undo a left swipe by removing it from the database and restoring the card.
    func undoLeftSwipe(_ sneaker: SneakerCard) async {
        do {
            let session = try await supabase.auth.session
            _ = try await supabase
                .from("user_swipes")
                .delete()
                .eq("user_id", value: session.user.id)
                .eq("sneaker_id", value: sneaker.id)
                .eq("direction", value: "left")
                .execute()
            
            struct ReturnPayload: Encodable {
                let user_id: UUID
                let sneaker_id: UUID
            }
            let payload = ReturnPayload(user_id: session.user.id, sneaker_id: sneaker.id)
            do {
                _ = try await supabase
                    .from("user_swipe_returns")
                    .upsert(payload, onConflict: "user_id,sneaker_id")
                    .execute()
                returnDisabledIDs.insert(sneaker.id)
            } catch {
                debugPrint("Return tracking not available: \(error)")
            }
        } catch {
            debugPrint("Failed to undo left swipe: \(error)")
            return
        }
        
        swipedLeftIDs.remove(sneaker.id)
        
        if !feed.contains(where: { $0.id == sneaker.id }) {
            feed.insert(sneaker, at: 0)
            noResultsForFilters = false
        }
    }
    
    /// Search sneakers using natural language query
    /// - Parameters:
    ///   - query: Natural language search query (e.g., "basketball shoes", "something cool for winter")
    ///   - gender: Gender filter
    ///   - priceMin: Minimum price
    ///   - priceMax: Maximum price
    /// Runs semantic search and updates `feed`.
    /// - Returns: `true` if we ended up with at least 1 result after filtering swipes; otherwise `false`.
    func searchWithNaturalLanguage(_ query: String, gender: String?, priceMin: Double, priceMax: Double) async throws -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        semanticSearchNotice = nil
        
        // If query is empty, reload normal feed
        guard !trimmedQuery.isEmpty else {
            isSemanticSearchActive = false
            currentSearchQuery = nil
            await load()
            return false
        }

        // Skip if the exact same search was just run to avoid redundant network calls
        let signature = SearchSignature(query: trimmedQuery, gender: gender, priceMin: priceMin, priceMax: priceMax)
        if let last = lastSearchSignature, last == signature {
            print("🔁 Skipping semantic search: same query/filters as last run")
            return false
        }
        lastSearchSignature = signature
        
        do {
            // Capture config on the MainActor.
            let config = SemanticSearchConfig(
                supabaseURL: AppSecrets.supabaseURL,
                supabaseAPIKey: AppSecrets.supabaseAnonKey
            )
            
            // Use semantic search with embeddings from search_metadata
            // Reverted to single-embedding approach for simplicity
            let response = try await SemanticSearchService.searchSneakersHybrid(
                config: config,
                query: trimmedQuery,
                gender: gender,
                priceMin: priceMin,
                priceMax: priceMax,
                semanticWeight: 0.6,  // Kept for API compatibility (not used)
                filterWeight: 0.4      // Kept for API compatibility (not used)
            )
            
            let results = response.cards
            print("📊 Received \(results.count) results from search service")
            
            // Filter out already swiped
            let filtered = results.filter {
                !swipedRightIDs.contains($0.id) && !swipedLeftIDs.contains($0.id)
            }
            
            print("📊 After filtering swiped: \(filtered.count) results")
            
            await MainActor.run {
                feed = filtered
                isSemanticSearchActive = true
                currentSearchQuery = trimmedQuery
                noResultsForFilters = filtered.isEmpty
                
                // Only show a message when the user truly has 0 results after all logic.
                if filtered.isEmpty {
                    let genderText = (gender?.isEmpty == false) ? gender! : "your selected gender"
                    semanticSearchNotice = "No \(genderText) shoes found for “\(trimmedQuery)” in $\(Int(priceMin))–$\(Int(priceMax)). Try increasing your max price."
                } else {
                    semanticSearchNotice = nil
                }
            }
            
            print("🔍 Semantic search complete: \(filtered.count) results for '\(trimmedQuery)'")
            return !filtered.isEmpty
        } catch {
            isSemanticSearchActive = false
            currentSearchQuery = nil
            lastSearchSignature = nil
            throw error
        }
    }
    
    /// Remove a liked shoe from user's collection (delete from database)
    nonisolated func unlikeShoe(sneakerID: UUID) async throws {
        let session = try await supabase.auth.session
        _ = try await supabase
            .from("user_swipes")
            .delete()
            .eq("user_id", value: session.user.id)
            .eq("sneaker_id", value: sneakerID)
            .execute()
        
        // Also update local state
        await MainActor.run { [weak self] in
            guard let self = self else { return }
            self.swipedRightIDs.remove(sneakerID)
            self.liked.removeAll { $0.id == sneakerID }
        }
    }
    
    /// Update pinned status for a liked shoe
    nonisolated func updatePinStatus(sneakerID: UUID, isPinned: Bool) async throws {
        let session = try await supabase.auth.session
        struct Payload: Encodable {
            let is_pinned: Bool
        }
        let payload = Payload(is_pinned: isPinned)
        _ = try await supabase
            .from("user_swipes")
            .update(payload)
            .eq("user_id", value: session.user.id)
            .eq("sneaker_id", value: sneakerID)
            .execute()
    }
}

// Lightweight signature to detect identical semantic searches
private struct SearchSignature: Equatable {
    let query: String
    let gender: String?
    let priceMin: Double
    let priceMax: Double
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
    
    func fetchReturnDisabledIDs() async throws -> Set<UUID> {
        let session = try await supabase.auth.session
        struct Row: Decodable { let sneaker_id: UUID }
        let rows: [Row] = try await supabase
            .from("user_swipe_returns")
            .select("sneaker_id")
            .eq("user_id", value: session.user.id)
            .execute()
            .value
        return Set(rows.map { $0.sneaker_id })
    }
    
    func fetchLikedDetails() async throws -> [SneakerCard] {
        let session = try await supabase.auth.session
        struct Row: Decodable {
            let sneaker_id: UUID
            let is_pinned: Bool?
            let sneakers_only: SneakerRow
        }
        let rows: [Row] = try await supabase
            .from("user_swipes")
            .select("sneaker_id, direction, is_pinned, sneakers_only!inner (id, name, brand, image_url, retail_price, gender, link)")
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
                stockxLink: row.sneakers_only.link,
                colors: nil, // Colors not needed for liked shoes view
                isPinned: row.is_pinned ?? false
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
                stockxLink: row.link,
                colors: row.colors
            )
        }

        // IMPROVED FALLBACK: Only fall back if truly empty AND gender was set
        // This prevents showing all brands when specific brand filter returns nothing
        if mapped.isEmpty && gender != nil {
            print("⚠️ fetchSneakers: trying fallback without gender filter")
            let fallback: [SneakerRow] = try await querySneakers(limit: pageSize, offset: 0, gender: nil, brands: brands.isEmpty ? nil : brands, excludeIDs: excluded)
            mapped = fallback.map { row in
                SneakerCard(
                    id: row.id,
                    name: row.name,
                    brand: row.brand ?? "Unknown",
                    price: row.retail_price,
                    imageURL: row.image_url.flatMap(URL.init),
                    gender: row.gender,
                    stockxLink: row.link,
                    colors: row.colors
                )
            }
            
            // If STILL empty after removing gender, only then remove brand filter
            if mapped.isEmpty && !brands.isEmpty {
                print("⚠️ fetchSneakers: final fallback - removing brand filter")
                let finalFallback: [SneakerRow] = try await querySneakers(limit: pageSize, offset: 0, gender: nil, brands: nil, excludeIDs: excluded)
                mapped = finalFallback.map { row in
                    SneakerCard(
                        id: row.id,
                        name: row.name,
                        brand: row.brand ?? "Unknown",
                        price: row.retail_price,
                        imageURL: row.image_url.flatMap(URL.init),
                        gender: row.gender,
                        stockxLink: row.link,
                        colors: row.colors
                    )
                }
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
                stockxLink: row.link,
                colors: row.colors
            )
        }
    }
    
    func querySneakers(limit: Int, offset: Int, gender: String?, brands: [String]?, excludeIDs: Set<UUID>) async throws -> [SneakerRow] {
        var collected: [SneakerRow] = []
        var attempts = 0
        let maxAttempts = 3  // Reduced from 5 to improve performance
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

        // When the user selects multiple brands, a single `.in(brand, [...])` query + random offsets can
        // still over-sample a dominant brand (e.g. Nike) and under-sample smaller brands.
        // Fix: if the user picked a *small* set of brands, fetch a quota from each brand and then interleave.
        if let brands, brands.count > 1, brands.count <= 8 {
            print("🧩 querySneakers: balanced per-brand fetch enabled (brands=\(brands.count), limit=\(limit))")
            let balanced = try await querySneakersBalancedAcrossBrands(
                limit: limit,
                offset: offset,
                normalizedGender: normalizedGender,
                brands: brands,
                priceMin: priceMin,
                priceMax: priceMax,
                excludeIDs: excludeIDs
            )
            return balanced
        }
        
        // Keep fetching batches until we have enough unique cards or hit max attempts
        while collected.count < limit && attempts < maxAttempts {
            // OPTIMIZATION: Use smaller random jitter to prevent offset exhaustion
            // For specific brands, keep offset low; for all brands, allow more exploration
            let maxJitter = (brands?.isEmpty ?? true) ? 150 : 50
            let randomJitter = Int.random(in: 0...maxJitter)
            let currentOffset = offset + (attempts * batchSize) + randomJitter
            
            // SAFETY: Cap the offset to prevent querying beyond reasonable limits
            // This prevents timeout errors and empty results
            let safeOffset = min(currentOffset, 800)
            
            var query = supabase
                .from("sneakers_only")
                .select("""
                    id,
                    name,
                    brand,
                    image_url,
                    retail_price,
                    gender,
                    link,
                    colors
                """)
            
            if let normalizedGender, !normalizedGender.isEmpty {
                query = query.eq("gender", value: normalizedGender)
                print("🔍 querySneakers: filtering by gender = \(normalizedGender)")
            }
            if let brands, !brands.isEmpty {
                query = query.in("brand", values: brands)
                print("🔍 querySneakers: filtering by brands = \(brands)")
                print("🔍 querySneakers: price range = $\(Int(priceMin))-$\(Int(priceMax))")
            } else {
                print("🔍 querySneakers: NO brand filter (showing all brands)")
            }
            
            // Add price range filters (exclude $0 and null prices)
            query = query
                .gt("retail_price", value: 0)  // Must be greater than $0
                .gte("retail_price", value: priceMin)
                .lte("retail_price", value: priceMax)
                .not("image_url", operator: .is, value: "null")
                .neq("image_url", value: "")
            
            let rows: [SneakerRow] = try await query
                .order("created_at", ascending: false)
                .range(from: safeOffset, to: safeOffset + batchSize - 1)
                .execute()
                .value
            
            // Debug: Log what genders we're actually getting from DB
            if attempts == 0 {
                let genderCounts = Dictionary(grouping: rows, by: { $0.gender ?? "nil" })
                    .mapValues { $0.count }
                print("🔍 querySneakers: DB returned genders: \(genderCounts)")
                if rows.isEmpty {
                    print("⚠️ querySneakers: EMPTY RESULT on first attempt (offset: \(safeOffset))")
                }
            }
            
            // Filter out excluded IDs and already collected ones
            let collectedIDs = Set(collected.map { $0.id })
            let freshRows = rows.filter { !excludeIDs.contains($0.id) && !collectedIDs.contains($0.id) }
            
            collected.append(contentsOf: freshRows)
            attempts += 1
            
            // EARLY EXIT: If we got no rows from DB (not just filtered out), we've hit the end
            if rows.isEmpty {
                print("🔍 querySneakers: reached end of available inventory (attempt \(attempts))")
                break
            }
            
            // If we got nothing new after filtering, try once more with reset offset
            if freshRows.isEmpty && attempts == 1 && safeOffset > 0 {
                print("🔍 querySneakers: no fresh results, resetting offset for retry")
                continue
            }
            
            // If still nothing fresh and we've tried twice, break
            if freshRows.isEmpty && attempts >= 2 {
                print("🔍 querySneakers: no fresh results after \(attempts) attempts, stopping")
                break
            }
        }
        
        print("🔍 querySneakers: collected \(collected.count) items after \(attempts) attempts")
        
        // Apply brand diversification to avoid showing too many shoes from the same brand
        let diversified = diversifyByBrand(collected, targetCount: limit)
        
        return diversified
    }
    
    /*
    func querySneakersGenderOnly(
        limit: Int,
        offset: Int,
        gender: String?,
        excludeIDs: Set<UUID>
    ) async throws -> [SneakerRow] {
        var collected: [SneakerRow] = []
        var attempts = 0
        let maxAttempts = 5
        let batchSize = 100
        
        let normalizedGender: String? = {
            guard let gender = gender else { return nil }
            switch gender.lowercased() {
            case "male": return "men"
            case "female": return "women"
            default: return gender.lowercased()
            }
        }()
        
        while collected.count < limit && attempts < maxAttempts {
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
                    link,
                    colors
                """)
            
            if let normalizedGender, !normalizedGender.isEmpty {
                query = query.eq("gender", value: normalizedGender)
            }
            
            let rows: [SneakerRow] = try await query
                .order("created_at", ascending: false)
                .range(from: randomOffset, to: randomOffset + batchSize - 1)
                .execute()
                .value
            
            let collectedIDs = Set(collected.map { $0.id })
            let freshRows = rows.filter { !excludeIDs.contains($0.id) && !collectedIDs.contains($0.id) }
            
            collected.append(contentsOf: freshRows)
            attempts += 1
            
            if freshRows.isEmpty && rows.count < batchSize {
                break
            }
        }
        
        return diversifyByBrand(collected, targetCount: limit)
    }
    */
    
    /// Fetch a quota per selected brand, then interleave to prevent one brand/model dominating.
    /// This is intentionally used only when brands.count is small (<= 8) to avoid excessive network calls.
    private func querySneakersBalancedAcrossBrands(
        limit: Int,
        offset: Int,
        normalizedGender: String?,
        brands: [String],
        priceMin: Double,
        priceMax: Double,
        excludeIDs: Set<UUID>
    ) async throws -> [SneakerRow] {
        // Oversample so we can diversify (e.g. cap per model) and still hit `limit`.
        let oversampleFactor = 2.2
        let targetTotal = Int(ceil(Double(limit) * oversampleFactor))
        let perBrandTarget = max(20, Int(ceil(Double(targetTotal) / Double(brands.count))))
        let perBrandBatchSize = max(60, perBrandTarget)
        let perBrandAttempts = 2  // Reduced from 3 for efficiency
        
        var combined: [SneakerRow] = []
        combined.reserveCapacity(targetTotal)
        
        // Fetch each brand separately so smaller brands don't get drowned out by Nike/adidas volume.
        for (i, brand) in brands.enumerated() {
            var brandCollected: [SneakerRow] = []
            var attempts = 0
            
            while brandCollected.count < perBrandTarget && attempts < perBrandAttempts {
                // OPTIMIZATION: Use smaller jitter to prevent exhaustion on small-inventory brands
                let jitter = (i * 50) + Int.random(in: 0...50)  // Reduced from 97/150
                let currentOffset = offset + (attempts * perBrandBatchSize) + jitter
                
                // SAFETY: Cap offset per brand to prevent exhaustion
                let randomOffset = min(currentOffset, 400)
                
                var query = supabase
                    .from("sneakers_only")
                    .select("""
                        id,
                        name,
                        brand,
                        image_url,
                        retail_price,
                        gender,
                        link,
                        colors
                    """)
                
                if let normalizedGender, !normalizedGender.isEmpty {
                    query = query.eq("gender", value: normalizedGender)
                }
                
                // Exact brand match
                query = query.eq("brand", value: brand)
                
                // Price range filters (exclude $0 and null)
                query = query
                    .gt("retail_price", value: 0)
                    .gte("retail_price", value: priceMin)
                    .lte("retail_price", value: priceMax)
                    .not("image_url", operator: .is, value: "null")
                    .neq("image_url", value: "")
                
                let rows: [SneakerRow] = try await query
                    .order("created_at", ascending: false)
                    .range(from: randomOffset, to: randomOffset + perBrandBatchSize - 1)
                    .execute()
                    .value
                
                let existing = Set(brandCollected.map { $0.id })
                let fresh = rows.filter { !excludeIDs.contains($0.id) && !existing.contains($0.id) }
                brandCollected.append(contentsOf: fresh)
                
                attempts += 1
                
                // EARLY EXIT: If we got no rows from DB, we've reached the end for this brand
                if rows.isEmpty {
                    print("🧩 Brand '\(brand)': reached end of inventory (attempt \(attempts))")
                    break
                }
                
                if fresh.isEmpty && rows.count < perBrandBatchSize {
                    break
                }
            }
            
            print("🧩 Brand '\(brand)': collected \(brandCollected.count) items")
            combined.append(contentsOf: brandCollected)
        }
        
        // Now enforce brand + model diversity (hard cap per model in the first page).
        let diversified = diversifyByBrand(combined, targetCount: limit)
        
#if DEBUG
        // Quick sanity preview (first few cards should show mixed brands + mixed models).
        let preview = diversified.prefix(12).map { row -> String in
            let b = row.brand ?? "Unknown"
            // modelKey() already namespaces with brand; keep output short.
            let mk = modelKey(for: row).replacingOccurrences(of: b + " ", with: "")
            return "\(b):\(mk)"
        }
        print("🧩 diversified preview: \(preview)")
#endif
        
        return diversified
    }
    
    /// Diversifies sneakers by brand AND model to prevent repetitive shoes/colorways.
    /// Key improvements vs typical round-robin:
    /// - Removes exhausted brands/models from the cycle (avoids "skipping" that creates streaks).
    /// - Enforces a cap on how many times the same model can appear in the first `targetCount`.
    private func diversifyByBrand(_ sneakers: [SneakerRow], targetCount: Int) -> [SneakerRow] {
        guard !sneakers.isEmpty else { return [] }
        
        // Group sneakers by brand.
        var brandGroups: [String: [SneakerRow]] = [:]
        for sneaker in sneakers {
            let brand = sneaker.brand ?? "Unknown"
            brandGroups[brand, default: []].append(sneaker)
        }
        
        // Within each brand, diversify by model (better model key extraction + model round-robin).
        for brand in brandGroups.keys {
            if var shoes = brandGroups[brand] {
                shoes = diversifyWithinBrandByModel(shoes)
                brandGroups[brand] = shoes
            }
        }
        
        // Brands with more inventory go earlier, but we still interleave.
        var activeBrands = brandGroups.keys.sorted { (a, b) -> Bool in
            (brandGroups[a]?.count ?? 0) > (brandGroups[b]?.count ?? 0)
        }
        
        var result: [SneakerRow] = []
        result.reserveCapacity(min(targetCount, sneakers.count))
        
        // Hard caps to prevent "same model different colorway" floods in the first page.
        let maxPerModelInFirstPage = 2
        var modelCounts: [String: Int] = [:] // key: "\(brand)|\(modelKey)"
        
        var brandIndex = 0
        var safety = 0
        while result.count < targetCount && !activeBrands.isEmpty && safety < 10_000 {
            safety += 1
            
            if brandIndex >= activeBrands.count { brandIndex = 0 }
            let brand = activeBrands[brandIndex]
            
            guard var queue = brandGroups[brand], !queue.isEmpty else {
                activeBrands.removeAll { $0 == brand }
                continue
            }
            
            // Pop the next shoe for this brand.
            let candidate = queue.removeFirst()
            brandGroups[brand] = queue
            
            // Apply model cap in the first page. If we hit the cap, push it to the back and try later.
            let candidateModelKey = modelKey(for: candidate)
            let globalModelKey = "\(brand)|\(candidateModelKey)"
            let currentCount = modelCounts[globalModelKey, default: 0]
            
            if currentCount >= maxPerModelInFirstPage && result.count < targetCount {
                // Put it back at the end and move on.
                brandGroups[brand, default: []].append(candidate)
                brandIndex += 1
                continue
            }
            
            result.append(candidate)
            modelCounts[globalModelKey] = currentCount + 1
            
            // Drop brands that are empty so we don't "skip" them and accidentally create streaks.
            if (brandGroups[brand]?.isEmpty ?? true) {
                activeBrands.removeAll { $0 == brand }
                if brandIndex >= activeBrands.count { brandIndex = 0 }
            } else {
                brandIndex += 1
            }
        }
        
        return result
    }
    
    /// Diversifies shoes within a brand by model to avoid showing the same model consecutively.
    private func diversifyWithinBrandByModel(_ sneakers: [SneakerRow]) -> [SneakerRow] {
        guard sneakers.count > 1 else { return sneakers }
        
        // Group by derived model key (tries to isolate silhouette/model, not colorway).
        var modelGroups: [String: [SneakerRow]] = [:]
        for sneaker in sneakers {
            let key = modelKey(for: sneaker)
            modelGroups[key, default: []].append(sneaker)
        }
        
        if modelGroups.count == 1 {
            return sneakers.shuffled()
        }
        
        // Shuffle within each model group so colorways rotate.
        for key in modelGroups.keys {
            modelGroups[key]?.shuffle()
        }
        
        // Interleave models; remove exhausted models as we go to avoid streaks.
        var activeModels = modelGroups.keys.sorted { (a, b) -> Bool in
            (modelGroups[a]?.count ?? 0) > (modelGroups[b]?.count ?? 0)
        }
        
        var result: [SneakerRow] = []
        result.reserveCapacity(sneakers.count)
        
        var idx = 0
        var safety = 0
        while result.count < sneakers.count && !activeModels.isEmpty && safety < 10_000 {
            safety += 1
            
            if idx >= activeModels.count { idx = 0 }
            let key = activeModels[idx]
            
            guard var queue = modelGroups[key], !queue.isEmpty else {
                activeModels.removeAll { $0 == key }
                continue
            }
            
            result.append(queue.removeFirst())
            modelGroups[key] = queue
            
            if queue.isEmpty {
                activeModels.removeAll { $0 == key }
                if idx >= activeModels.count { idx = 0 }
            } else {
                idx += 1
            }
        }
        
        return result
    }
    
    /// Derives a model key from the shoe name. This is a best-effort silhouette/model extractor
    /// (because the DB doesn't contain `style_id`/`sku`). Goal: group colorways together.
    private func modelKey(for sneaker: SneakerRow) -> String {
        let brand = (sneaker.brand ?? "Unknown").trimmingCharacters(in: .whitespacesAndNewlines)
        return deriveModelKey(name: sneaker.name, brand: brand)
    }
    
    private func deriveModelKey(name: String, brand: String) -> String {
        // 1) Strip parenthetical suffixes like (GS), (TD), (2025), etc.
        var s = name
            .replacingOccurrences(of: "\\s*\\([^\\)]*\\)\\s*$", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 2) Split on common separators where the right side is often a colorway/pack.
        if let dashRange = s.range(of: " - ") {
            s = String(s[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 3) Remove brand prefix if present, to better isolate the model tokens.
        let lower = s.lowercased()
        let brandLower = brand.lowercased()
        if lower.hasPrefix(brandLower + " ") {
            s = String(s.dropFirst(brandLower.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 4) Token cleanup: remove common suffix tokens that don't define silhouette.
        // Keep important variant tokens like low/mid/high, max numbers, etc.
        let removableTokens: Set<String> = [
            "retro", "og", "premium", "prm", "se", "sp", "qs", "pe", "gs", "ps", "td",
            "men's", "w", "wmns", "women's", "kids", "toddler", "infant",
            "2020", "2021", "2022", "2023", "2024", "2025", "2026"
        ]
        let colorwayTokens: Set<String> = [
            "black","white","red","blue","green","grey","gray","pink","purple","orange","yellow","brown","beige","tan",
            "cream","sail","ivory","silver","gold","navy","teal","aqua","volt","multi","multicolor"
        ]
        
        var tokens = s
            .replacingOccurrences(of: "[^A-Za-z0-9]+", with: " ", options: .regularExpression)
            .lowercased()
            .split(separator: " ")
            .map(String.init)
        
        // Strip trailing tokens that look like colorway descriptors.
        while let last = tokens.last, (colorwayTokens.contains(last) || removableTokens.contains(last)) {
            tokens.removeLast()
        }
        
        // Also strip leading removable tokens (rare, but safe).
        while let first = tokens.first, removableTokens.contains(first) {
            tokens.removeFirst()
        }
        
        // If we stripped too far, fall back to first few tokens of original.
        if tokens.isEmpty {
            tokens = name.lowercased().split(separator: " ").prefix(4).map(String.init)
        }
        
        // Limit key size to keep grouping stable.
        let keyTokens = tokens.prefix(5)
        let key = keyTokens.joined(separator: " ")
        
        // Include brand in the key namespace so identical model tokens across brands don't collide.
        return "\(brand) \(key)".trimmingCharacters(in: .whitespacesAndNewlines)
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
    let colors: [ShoeColor]?
}
