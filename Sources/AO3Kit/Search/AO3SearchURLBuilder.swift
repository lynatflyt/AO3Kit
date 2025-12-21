import Foundation

/// Builds URL parameters for AO3 search queries
internal struct AO3SearchURLBuilder {
    func build(from filters: AO3SearchFilters) -> String {
        var params: [String] = []

        // Work Info
        appendWorkInfoParameters(&params, filters: filters)

        // Work Tags
        appendWorkTagsParameters(&params, filters: filters)

        // Work Stats
        appendWorkStatsParameters(&params, filters: filters)

        // Results Options
        appendResultsParameters(&params, filters: filters)

        params.append("commit=Search")

        return params.joined(separator: "&")
    }

    private func appendWorkInfoParameters(_ params: inout [String], filters: AO3SearchFilters) {
        params.append("work_search%5Btitle%5D=\(filters.title.map(AO3Utils.ao3URLEncode) ?? "")")
        params.append("work_search%5Bcreators%5D=\(filters.creators.map(AO3Utils.ao3URLEncode) ?? "")")
        params.append("work_search%5Brevised_at%5D=\(filters.revisedAt.map(AO3Utils.ao3URLEncode) ?? "")")
        params.append("work_search%5Bcomplete%5D=\(filters.complete?.rawValue ?? "")")
        params.append("work_search%5Bcrossover%5D=\(filters.crossover?.rawValue ?? "")")
        params.append("work_search%5Bsingle_chapter%5D=\(filters.singleChapter.map { $0 ? "1" : "0" } ?? "0")")
        params.append("work_search%5Bword_count%5D=\(filters.wordCount.map(AO3Utils.ao3URLEncode) ?? "")")
        params.append("work_search%5Blanguage_id%5D=\(filters.languageID.map(AO3Utils.ao3URLEncode) ?? "")")
    }

    private func appendWorkTagsParameters(_ params: inout [String], filters: AO3SearchFilters) {
        params.append("work_search%5Bfandom_names%5D=\(filters.fandomNames.map(AO3Utils.ao3URLEncode) ?? "")")

        // Rating - only one can be selected
        if let rating = filters.rating {
            let ratingID = getRatingID(rating)
            params.append("work_search%5Brating_ids%5D=\(ratingID)")
        }

        // Warnings - these use IDs and array notation
        if !filters.warnings.isEmpty {
            for warning in filters.warnings {
                let warningID = getWarningID(warning)
                params.append("work_search%5Barchive_warning_ids%5D%5B%5D=\(warningID)")
            }
        }

        // Categories - these use IDs
        if !filters.categories.isEmpty {
            for category in filters.categories {
                let categoryID = getCategoryID(category)
                params.append("work_search%5Bcategory_ids%5D=\(categoryID)")
            }
        }

        params.append("work_search%5Bcharacter_names%5D=\(filters.characterNames.map(AO3Utils.ao3URLEncode) ?? "")")
        params.append("work_search%5Brelationship_names%5D=\(filters.relationshipNames.map(AO3Utils.ao3URLEncode) ?? "")")
        params.append("work_search%5Bfreeform_names%5D=\(filters.freeformNames.map(AO3Utils.ao3URLEncode) ?? "")")
    }

    private func appendWorkStatsParameters(_ params: inout [String], filters: AO3SearchFilters) {
        params.append("work_search%5Bhits%5D=\(filters.hits.map(AO3Utils.ao3URLEncode) ?? "")")
        params.append("work_search%5Bkudos_count%5D=\(filters.kudosCount.map(AO3Utils.ao3URLEncode) ?? "")")
        params.append("work_search%5Bcomments_count%5D=\(filters.commentsCount.map(AO3Utils.ao3URLEncode) ?? "")")
        params.append("work_search%5Bbookmarks_count%5D=\(filters.bookmarksCount.map(AO3Utils.ao3URLEncode) ?? "")")
    }

    private func appendResultsParameters(_ params: inout [String], filters: AO3SearchFilters) {
        let sortColumn = filters.sortColumn?.rawValue ?? "_score"
        let sortDirection = filters.sortDirection?.rawValue ?? "desc"
        params.append("work_search%5Bsort_column%5D=\(sortColumn)")
        params.append("work_search%5Bsort_direction%5D=\(sortDirection)")
    }

    // MARK: - Tag ID Conversion

    private func getRatingID(_ rating: AO3Rating) -> Int {
        switch rating {
        case .notRated: return 9
        case .general: return 10
        case .teenAndUp: return 11
        case .mature: return 12
        case .explicit: return 13
        }
    }

    private func getWarningID(_ warning: AO3Warning) -> Int {
        switch warning {
        case .noWarnings: return 14
        case .noneApply: return 16
        case .violence: return 17
        case .majorCharacterDeath: return 18
        case .nonCon: return 19
        case .underage: return 20
        case .none: return 16
        }
    }

    private func getCategoryID(_ category: AO3Category) -> Int {
        switch category {
        case .gen: return 21
        case .fm: return 22
        case .mm: return 23
        case .ff: return 116
        case .other: return 24
        case .multi: return 2246
        case .none: return 21
        }
    }
}
