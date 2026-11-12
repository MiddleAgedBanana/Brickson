import Foundation

/// What a backup the family chose would do to the library, for the Restore
/// question: Add (`LibraryImport.merge`) and Replace
/// (`LibraryImport.replace`), each as a checked plan or the reason it
/// cannot run. Nothing is written here (docs/DECISIONS.md, "Exporting and
/// restoring a backup").
struct RestoreChoices: Equatable {
    /// Why a choice cannot run. Each has a sentence the family can read
    /// beside the dimmed choice.
    enum Refusal: Error, Equatable {
        /// The library's rules refuse it (`LibraryEditRejection`).
        case rejected(LibraryEditRejection)
        /// Replacing would remove words the person wrote that the backup
        /// does not have (docs/DECISIONS.md, "Replacing the library").
        case wouldRemoveOwnWords
        /// The backup would bring an everyday category whose name has a
        /// word too wide for Home's narrowest category button
        /// (`HomeWordRoom`). A backup's words are never changed on the way
        /// in, so it is refused whole.
        case nameTooWide(String)
        /// Everything in the backup is already in the library.
        case nothingToAdd
        /// The library already matches the backup.
        case alreadyTheSame

        var message: String {
            switch self {
            case .rejected(let rejection):
                rejection.message
            case .wouldRemoveOwnWords:
                String(localized: "Replacing would remove phrases or categories you wrote that aren't in this backup. Add it instead, then delete what you don't need.")
            case .nameTooWide(let word):
                String(localized: "A category in this backup has “\(word)” in its name, which is too wide for Home's category buttons.")
            case .nothingToAdd:
                String(localized: "Everything in this backup is already in your phrases.")
            case .alreadyTheSame:
                String(localized: "Your phrases already match this backup.")
            }
        }
    }

    let backup: LibrarySnapshot
    let add: Result<LibraryPlan, Refusal>
    let replace: Result<LibraryPlan, Refusal>

    /// - Parameters:
    ///   - starter: the bundled starter library, so a replace can tell the
    ///     person's own words from untouched starter phrases; without it,
    ///     every word counts as theirs.
    ///   - restBoard: the category Home's rest board shows
    ///     (`SetupRecord.restBoardCategory`), which a replace takes no
    ///     farther under four phrases (`LibraryEdit.plan`).
    ///   - makeID: identities for what the backup brings that clash with
    ///     the library's. Tests pass a predictable one.
    init(
        backup: LibrarySnapshot,
        library: LibrarySnapshot,
        starter: LibrarySnapshot?,
        restBoard: UUID?,
        makeID: () -> UUID = { UUID() }
    ) {
        self.backup = backup
        add = Self.check(LibraryEdit.merge(backup), in: library, starter: starter, restBoard: restBoard, makeID: makeID).flatMap { plan in
            plan.changes.isEmpty ? .failure(.nothingToAdd) : .success(plan)
        }
        replace = Self.check(LibraryEdit.replace(backup), in: library, starter: starter, restBoard: restBoard, makeID: makeID).flatMap { plan in
            if plan.needsSafetyCopy { return .failure(.wouldRemoveOwnWords) }
            return plan.changes.isEmpty ? .failure(.alreadyTheSame) : .success(plan)
        }
    }

    private static func check(
        _ edit: LibraryEdit, in library: LibrarySnapshot, starter: LibrarySnapshot?, restBoard: UUID?, makeID: () -> UUID
    ) -> Result<LibraryPlan, Refusal> {
        let plan: LibraryPlan
        do {
            plan = try edit.plan(in: library, starter: starter, restBoard: restBoard, makeID: makeID)
        } catch {
            return .failure(.rejected(error))
        }
        let names = Set(library.categories.map(\.name))
        let newNames = plan.after.categories.filter { !$0.isEmergency && !names.contains($0.name) }.map(\.name)
        for name in newNames {
            if let word = HomeWordRoom.wordsTooWide(inCategoryName: name).first {
                return .failure(.nameTooWide(word))
            }
        }
        return .success(plan)
    }
}
