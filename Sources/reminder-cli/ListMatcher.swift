import Foundation

/// Pure (EventKit-independent) resolution logic for reminder lists, so that
/// name matching and validation can be unit tested without calendar access.
enum ListMatcher {
    struct Candidate: Equatable {
        let id: String
        let title: String
    }

    /// Resolves a user-supplied list reference (trimmed of surrounding whitespace) to exactly one list.
    ///
    /// An exact `calendarIdentifier` match wins; otherwise the title is matched
    /// case-insensitively. Multiple title matches are rejected so that
    /// destructive operations never pick a list arbitrarily.
    static func resolve(_ query: String, in candidates: [Candidate]) throws -> Candidate {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if let byID = candidates.first(where: { $0.id == query }) {
            return byID
        }

        let byTitle = candidates.filter { $0.title.lowercased() == query.lowercased() }
        switch byTitle.count {
        case 0:
            throw ReminderStoreError.listNotFound(query)
        case 1:
            return byTitle[0]
        default:
            throw ReminderStoreError.ambiguousListName(
                query,
                byTitle.map { ReminderStoreError.Match(id: $0.id, title: $0.title) }
            )
        }
    }

    /// Normalizes a name for a new list and rejects blanks and
    /// case-insensitive duplicates of existing lists.
    static func validateNewName(_ name: String, existing: [Candidate]) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ReminderStoreError.invalidListName
        }
        if let duplicate = existing.first(where: { $0.title.lowercased() == trimmed.lowercased() }) {
            throw ReminderStoreError.listAlreadyExists(duplicate.title)
        }
        return trimmed
    }
}
