import Foundation

/// Resolves the system's interior exclusions using the same ordered Home
/// cells. No control state, device identity or pose enters this allocator.
/// See docs/work/layout-engine.md, "Resolved geometry for implementation".
nonisolated struct HomeReservedLayout {
    typealias Slot = HomeLayout.Slot

    enum Issue: Equatable, Sendable {
        case insufficientControlSpace
        case insufficientPhraseWidth
        case divisionCrossesScrollingViewport
        case controlCannotAvoidRegion(Slot)
        case wellEnvelopeCannotBePreserved
        case backToTalkingCannotFit
    }

    let allocations: [Slot: CGRect]
    let frames: [Slot: CGRect]
    let grid: HomeLayout.Grid
    let backToTalking: CGRect
    let issues: [Issue]

    private struct Candidate {
        var allocations: [Slot: CGRect]
        var frames: [Slot: CGRect]
        var grid: HomeLayout.Grid
        var issues: [Issue]
    }

    init(base: HomeLayout, space: HomeLayout.Space, profile: HomeLayout.Profile,
         text: HomeLayout.Text, largestCategory: Int) {
        let minimum = HomeLayout.MinimumWidths.forBoldText(text.boldText)
        // Standard containers round target frames to screen pixels. An
        // outward whole-point enclosure keeps that rounding outside the
        // raw fractional band on every display density. Zero-area markers
        // remain presence-only inputs, not one-point gaps.
        let divisions = space.regions.filter { $0.kind == .division }.map(\.frame).filter {
            !$0.isEmpty && $0.minX.isFinite && $0.minY.isFinite && $0.maxX.isFinite && $0.maxY.isFinite
        }.map { $0.integral }
        let occlusions = space.regions.filter { $0.kind == .occlusion }.map(\.frame)
        let vertical = divisions.first {
            $0.height > $0.width && Self.overlaps($0, base.content)
                && $0.minX > base.content.minX && $0.maxX < base.content.maxX
        }
        let horizontal = divisions.first { $0.width >= $0.height && Self.overlaps($0, base.content) }
        let modeFloor = max(profile.floor, text.quickControlLine + 2 * HomeLayout.labelInset.vertical,
            base.backToTalking.width < minimum.backToTalkingOneLine - 0.001 ? HomeLayout.twoLineCategoryHeight : 0)
        let returnable = base.modes == .phrasesAndTyping ? max(0, min(
            2 * (base.frame(.phrases).height - modeFloor), base.frame(.message).height - 2 * text.messageLine)) : 0

        let quickFloor = max(profile.floor, text.quickControlLine + 2 * HomeLayout.labelInset.vertical,
            base.frame(.getAttention).width < minimum.getAttentionOneLine - 0.001 ? HomeLayout.twoLineQuickControlHeight : 0)
        let categoryFloor = max(profile.floor, text.categoryLine + 2 * HomeLayout.labelInset.vertical)
        let quickGrowth = max(0, base.quickControlHeight - max(quickFloor, categoryFloor))
        let categoryGrowth = max(0, base.categoryHeight - categoryFloor)

        func resolve(smallerGaps: Bool) -> Candidate {
            let constrained = horizontal != nil && !base.isRegular
            let modeSteps = constrained ? Int((returnable / 0.5).rounded(.down)) : 0
            var first: Candidate?
            func returning(quick: CGFloat, category: CGFloat) -> Candidate? {
                for step in 0...max(0, modeSteps) {
                    let trial = Self.allocate(base: base, space: space, profile: profile, text: text,
                        vertical: vertical, horizontal: horizontal, occlusions: occlusions,
                        modeReturn: CGFloat(step) * 0.5, quickReturn: quick, categoryReturn: category,
                        smallerGaps: smallerGaps)
                    if first == nil { first = trial }
                    if trial.issues.isEmpty && (horizontal == nil || HomeWellEnvelope.preserves(base.frames, trial.frames)) {
                        return trial
                    }
                }
                return nil
            }
            // Preserve primary/category growth until A alone has exhausted
            // its ordinary budget. Then return the shared primary-row
            // growth, with categories never taller than the primary row.
            if let result = returning(quick: 0, category: 0) { return result }
            if constrained {
                let quickSteps = Int((quickGrowth / 0.5).rounded(.down))
                if quickSteps > 0 {
                    for step in 1...quickSteps {
                        if let result = returning(quick: CGFloat(step) * 0.5, category: 0) { return result }
                    }
                }
                let categorySteps = Int((categoryGrowth / 0.5).rounded(.down))
                if categorySteps > 0 {
                    for step in 1...categorySteps {
                        if let result = returning(quick: CGFloat(quickSteps) * 0.5, category: CGFloat(step) * 0.5) { return result }
                    }
                }
            }
            var failed = first!
            if horizontal != nil && !HomeWellEnvelope.preserves(base.frames, failed.frames) {
                failed.issues.append(.wellEnvelopeCannotBePreserved)
            }
            return failed
        }

        // Both capacities use the fixed reference library. A family's
        // added phrases must not enter control sizing.
        let referenceShortfall = base.grid.reflow(in: base.grid.frame,
            phraseCount: HomeLayout.referencePhraseCount).shortfall

        func recoverCapacity(from original: Candidate, smallerGaps: Bool) -> Candidate {
            func safe(_ trial: Candidate) -> Bool {
                trial.issues.isEmpty && HomeWellEnvelope.preserves(base.frames, trial.frames)
            }
            guard safe(original) else { return original }
            var best = original
            let modeSteps = Int((returnable / 0.5).rounded(.down))
            let quickSteps = Int((quickGrowth / 0.5).rounded(.down))
            let categorySteps = Int((categoryGrowth / 0.5).rounded(.down))

            func returning(quick: CGFloat, category: CGFloat) -> Candidate? {
                for step in 0...max(0, modeSteps) {
                    let trial = Self.allocate(base: base, space: space, profile: profile, text: text,
                        vertical: vertical, horizontal: horizontal, occlusions: occlusions,
                        modeReturn: CGFloat(step) * 0.5, quickReturn: quick, categoryReturn: category,
                        smallerGaps: smallerGaps)
                    guard safe(trial) else { continue }
                    if trial.grid.shortfall < best.grid.shortfall - 0.001 { best = trial }
                    if trial.grid.shortfall <= referenceShortfall + 0.001 { return trial }
                }
                return nil
            }

            // Keep the existing preference order in finite half-point
            // sweeps: A, shared primary growth, then category growth.
            if let trial = returning(quick: 0, category: 0) { return trial }
            if quickSteps > 0 {
                for step in 1...quickSteps {
                    if let trial = returning(quick: CGFloat(step) * 0.5, category: 0) { return trial }
                }
            }
            if categorySteps > 0 {
                for step in 1...categorySteps {
                    if let trial = returning(quick: CGFloat(quickSteps) * 0.5, category: CGFloat(step) * 0.5) { return trial }
                }
            }
            // Ties keep the original; any residual shortage stays visible.
            return best
        }

        var chosen = resolve(smallerGaps: false)
        var chosenSmallerGaps = false
        // Controls are allocated from the reference library, never from a
        // person's added phrases. More phrases change only D's rows.
        if chosen.grid.shortfall > 0.001 && base.regionGap > HomeLayout.minimumRegionSpacing + 0.001 {
            let compacted = resolve(smallerGaps: true)
            if compacted.grid.shortfall < chosen.grid.shortfall && compacted.issues.isEmpty {
                chosen = compacted
                chosenSmallerGaps = true
            }
        }
        if chosen.grid.shortfall > referenceShortfall + 0.001 {
            chosen = recoverCapacity(from: chosen, smallerGaps: chosenSmallerGaps)
        }
        allocations = chosen.allocations
        frames = chosen.frames
        grid = chosen.grid.reflow(in: chosen.grid.frame, phraseCount: largestCategory)
        var faults = chosen.issues
        let back = Self.backFrame(base: base, frames: frames)
        if !back.isNull && (back.width < profile.floor || back.height < profile.floor) {
            faults.append(.backToTalkingCannotFit)
        }
        backToTalking = back
        issues = faults
    }

    private static func allocate(base: HomeLayout, space: HomeLayout.Space, profile: HomeLayout.Profile,
                                 text: HomeLayout.Text, vertical: CGRect?, horizontal: CGRect?,
                                 occlusions: [CGRect], modeReturn: CGFloat, quickReturn: CGFloat,
                                 categoryReturn: CGFloat, smallerGaps: Bool,
                                 minimumQuickHeight: CGFloat = 0, minimumModeHeight: CGFloat = 0) -> Candidate {
        let spacing = HomeLayout.controlSpacing
        let minimum = HomeLayout.MinimumWidths.forBoldText(text.boldText)
        var cells = base.frames
        var faults: [Issue] = []
        func move(_ slots: [Slot], by offset: CGFloat) {
            for slot in slots where cells[slot] != nil { cells[slot] = cells[slot]!.offsetBy(dx: 0, dy: offset) }
        }
        func moveGrid(by offset: CGFloat) {
            cells[.phraseGrid] = cells[.phraseGrid]!.offsetBy(dx: 0, dy: offset)
            cells[.phraseGrid]!.size.height = max(0, base.content.maxY - cells[.phraseGrid]!.minY)
        }
        if modeReturn > 0 {
            cells[.message]!.size.height -= modeReturn
            cells[.statusLine]!.origin.y -= modeReturn
            cells[.phrases]!.size.height -= modeReturn / 2
            cells[.type]!.origin.y -= modeReturn / 2
            cells[.type]!.size.height -= modeReturn / 2
            move(Slot.safetyRow + Slot.categoriesRegion, by: -modeReturn)
            moveGrid(by: -modeReturn)
        }
        if quickReturn > 0 {
            let safety = Slot.safetyRow.map { base.frame($0) }
            let firstTop = safety.map(\.minY).min()!
            let rowCount = base.isRegular && base.modes == .phrasesAndTyping ? 1 : 2
            for slot in Slot.safetyRow {
                let row: CGFloat = abs(base.frame(slot).minY - firstTop) < 0.001 ? 0 : 1
                cells[slot]!.origin.y -= row * quickReturn
                cells[slot]!.size.height -= quickReturn
            }
            move(Slot.categoriesRegion, by: -CGFloat(rowCount) * quickReturn)
            moveGrid(by: -CGFloat(rowCount) * quickReturn)
        }
        let categoryCut = max(categoryReturn, base.categoryHeight - (base.quickControlHeight - quickReturn))
        if categoryCut > 0 {
            switch base.categoryArrangement {
            case .band:
                cells[.stop]!.size.height -= categoryCut
                cells[.category(0)]!.origin.y -= categoryCut
                cells[.category(0)]!.size.height -= categoryCut
                for slot in [Slot.category(1), .category(2), .category(3), .settings] { cells[slot]!.size.height -= 2 * categoryCut }
                moveGrid(by: -2 * categoryCut)
            case .threeColumns, .twoColumns:
                let categoryRows: [[Slot]] = base.categoryArrangement == .threeColumns
                    ? [[.stop, .category(0), .category(1)], [.category(2), .category(3), .settings]]
                    : [[.stop, .category(0)], [.category(1), .category(2)], [.category(3), .settings]]
                for (row, slots) in categoryRows.enumerated() {
                    for slot in slots {
                        cells[slot]!.origin.y -= CGFloat(row) * categoryCut
                        cells[slot]!.size.height -= categoryCut
                    }
                }
                moveGrid(by: -CGFloat(categoryRows.count) * categoryCut)
            }
        }
        if smallerGaps {
            let cut = base.regionGap - HomeLayout.minimumRegionSpacing
            // A horizontal division pins a later row: returning A-to-C
            // would move the first safety row without gaining viewport.
            let upper = horizontal == nil ? cut : 0
            let middle = horizontal == nil ? cut : 0
            move(Slot.safetyRow, by: -upper)
            move(Slot.categoriesRegion, by: -upper - middle)
            moveGrid(by: -upper - middle - cut)
        }

        if let vertical {
            if base.isRegular && base.modes == .phrasesAndTyping {
                let left = vertical.minX - base.content.minX
                let right = base.content.maxX - vertical.maxX
                let leading = (left - 2 * spacing) / 3
                let again = max(minimum.category, (right - 2 * spacing) / 3)
                let attention = right - again - spacing
                if leading < max(minimum.category, minimum.emergency, profile.floor)
                    || again < max(minimum.again, minimum.category, profile.floor)
                    || attention < max(minimum.getAttention, profile.floor) {
                    faults.append(.insufficientControlSpace)
                } else {
                    let origins = [base.content.minX, base.content.minX + leading + spacing,
                        base.content.minX + 2 * (leading + spacing), vertical.maxX, vertical.maxX + again + spacing]
                    let widths = [leading, leading, leading, again, attention]
                    for (index, slot) in [Slot.emergency, .yes, .no, .again, .getAttention].enumerated() {
                        cells[slot]!.origin.x = origins[index]
                        cells[slot]!.size.width = widths[index]
                    }
                    for (slot, index) in [(Slot.stop, 0), (.category(0), 0), (.category(1), 1),
                                          (.category(2), 2), (.category(3), 3), (.settings, 4)] {
                        cells[slot]!.origin.x = origins[index]
                        cells[slot]!.size.width = widths[index]
                    }
                    for slot in [Slot.message, .statusLine] { cells[slot]!.size.width = left }
                    for slot in [Slot.phrases, .type] {
                        cells[slot]!.origin.x = vertical.maxX
                        cells[slot]!.size.width = right
                    }
                }
            } else {
                faults.append(.insufficientControlSpace)
            }
        }

        // Width fitting can require an existing two-line label floor.
        // Carry only increasing floor requirements through allocation, so
        // camera/row interactions settle without an oscillating layout.
        if base.modes == .phrasesAndTyping && cells[.phrases]!.height < minimumModeHeight - 0.001 {
            let growth = 2 * (minimumModeHeight - cells[.phrases]!.height)
            cells[.message]!.size.height += growth
            cells[.statusLine]!.origin.y += growth
            cells[.phrases]!.size.height += growth / 2
            cells[.type]!.origin.y += growth / 2
            cells[.type]!.size.height += growth / 2
            move(Slot.safetyRow + Slot.categoriesRegion, by: growth)
            moveGrid(by: growth)
        }
        if cells[.again]!.height < minimumQuickHeight - 0.001 {
            let growth = minimumQuickHeight - cells[.again]!.height
            let firstTop = Slot.safetyRow.map { base.frame($0).minY }.min()!
            let rowCount = base.isRegular && base.modes == .phrasesAndTyping ? 1 : 2
            for slot in Slot.safetyRow {
                let row: CGFloat = abs(base.frame(slot).minY - firstTop) < 0.001 ? 0 : 1
                cells[slot]!.origin.y += row * growth
                cells[slot]!.size.height += growth
            }
            move(Slot.categoriesRegion, by: CGFloat(rowCount) * growth)
            moveGrid(by: CGFloat(rowCount) * growth)
        }

        let rows = logicalRows(base)
        if let horizontal {
            if let boundary = rows.firstIndex(where: { overlaps(union($0, cells), horizontal) }) {
                let drop = max(0, horizontal.maxY - union(rows[boundary], cells).minY)
                for row in rows[boundary...] { move(row, by: drop) }
                moveGrid(by: drop)
                // Keep B's upper row in its own band, never move the whole
                // region to another half or put a gap in scrolling content.
                if base.categoryArrangement == .threeColumns,
                   Set(rows[boundary]) == Set([Slot.category(2), .category(3), .settings]) {
                    let first: [Slot] = [.stop, .category(0), .category(1)]
                    move(first, by: max(0, horizontal.minY - union(first, cells).maxY))
                }
            }
            if overlaps(cells[.phraseGrid]!, horizontal) { faults.append(.divisionCrossesScrollingViewport) }
        }

        let allocations = cells
        let fitted = fitOcclusions(cells, occlusions: occlusions, base: base, minimum: minimum, floor: profile.floor)
        var occupied = fitted.frames
        faults += fitted.issues
        let quickFloor = max(profile.floor, text.quickControlLine + 2 * HomeLayout.labelInset.vertical,
            occupied[.getAttention]!.width < minimum.getAttentionOneLine - 0.001 ? HomeLayout.twoLineQuickControlHeight : 0)
        let back = backFrame(base: base, frames: occupied)
        let modeFloor = base.modes == .phrasesAndTyping ? max(profile.floor,
            text.quickControlLine + 2 * HomeLayout.labelInset.vertical,
            back.width < minimum.backToTalkingOneLine - 0.001 ? HomeLayout.twoLineCategoryHeight : 0) : 0
        if occupied[.again]!.height < quickFloor - 0.001
            || (base.modes == .phrasesAndTyping && occupied[.phrases]!.height < modeFloor - 0.001) {
            // Each requirement has only a one-line/two-line tier and only
            // increases, so this finite sizing pass cannot oscillate.
            return allocate(base: base, space: space, profile: profile, text: text,
                vertical: vertical, horizontal: horizontal, occlusions: occlusions,
                modeReturn: modeReturn, quickReturn: quickReturn, categoryReturn: categoryReturn,
                smallerGaps: smallerGaps, minimumQuickHeight: max(minimumQuickHeight, quickFloor),
                minimumModeHeight: max(minimumModeHeight, modeFloor))
        }

        var viewport = cells[.phraseGrid]!
        for region in occlusions where overlaps(viewport, region) {
            let distances = [region.maxY, region.maxX, space.size.height - region.minY, space.size.width - region.minX]
            let edge = distances.enumerated().min { $0.element < $1.element }!.offset
            switch edge {
            case 0:
                let bottom = viewport.maxY
                viewport.origin.y = max(viewport.minY, region.maxY)
                viewport.size.height = max(0, bottom - viewport.minY)
            case 1:
                let trailing = viewport.maxX
                viewport.origin.x = max(viewport.minX, region.maxX)
                viewport.size.width = max(0, trailing - viewport.minX)
            case 2: viewport.size.height = max(0, min(viewport.maxY, region.minY) - viewport.minY)
            default: viewport.size.width = max(0, min(viewport.maxX, region.minX) - viewport.minX)
            }
        }
        occupied[.phraseGrid] = viewport
        // D's allocation is its fixed usable viewport. Unlike an individual
        // narrowed control, its camera strip must not return on reflow.
        cells[.phraseGrid] = viewport
        var gridFault = false
        let grid = phraseGrid(frame: viewport, vertical: vertical,
            hasDivision: space.regions.contains { $0.kind == .division }, regular: base.isRegular,
            boldText: text.boldText, floor: profile.floor, insufficientWidth: &gridFault)
        if gridFault { faults.append(.insufficientPhraseWidth) }
        for slot in base.slots where slot != .phraseGrid {
            let frame = occupied[slot]!
            if frame.width < minimumWidth(slot, frames: occupied, base: base, minimum: minimum, floor: profile.floor) - 0.001
                || space.regions.contains(where: { overlaps(frame, $0.frame) }) {
                let issue = Issue.controlCannotAvoidRegion(slot)
                if !faults.contains(issue) { faults.append(issue) }
            }
        }
        // The cells above D retain the camera-free target's original room.
        var finalAllocations = allocations
        finalAllocations[.phraseGrid] = cells[.phraseGrid]
        return Candidate(allocations: finalAllocations, frames: occupied, grid: grid, issues: faults)
    }

    /// Subtract all intersecting camera intervals before selecting a
    /// target's free interval. Choosing after each cut is order-dependent
    /// and can throw away the only interval that clears a later camera.
    private static func fitOcclusions(_ cells: [Slot: CGRect], occlusions: [CGRect], base: HomeLayout,
                                      minimum: HomeLayout.MinimumWidths, floor: CGFloat)
        -> (frames: [Slot: CGRect], issues: [Issue]) {
        var occupied = cells
        var faults: [Issue] = []
        var treated = Set<Slot>()
        for slot in base.slots where slot != .phraseGrid && !treated.contains(slot) {
            let group: [Slot] = [.message, .statusLine].contains(slot) ? [.message, .statusLine]
                : [.phrases, .type].contains(slot) ? [.phrases, .type] : [slot]
            let present = group.filter { cells[$0] != nil }
            treated.formUnion(present)
            let bounds = union(present, cells)
            let cuts = occlusions.filter { overlaps(bounds, $0) }
            guard !cuts.isEmpty else { continue }
            let needed: CGFloat
            if present == [.phrases, .type] { needed = max(minimum.phrases, minimum.type, floor) }
            else if slot == .getAttention { needed = max(minimum.getAttention, floor) }
            else { needed = present.map { minimumWidth($0, frames: cells, base: base, minimum: minimum, floor: floor) }.max()! }
            var chosen: (start: CGFloat, end: CGFloat)?
            for clearance in [HomeLayout.controlSpacing, CGFloat(0)] {
                var intervals: [(start: CGFloat, end: CGFloat)] = [(bounds.minX, bounds.maxX)]
                for cut in cuts.sorted(by: { $0.minX < $1.minX }) {
                    let leading = cut.minX - clearance, trailing = cut.maxX + clearance
                    intervals = intervals.flatMap { interval -> [(start: CGFloat, end: CGFloat)] in
                        if trailing <= interval.start || leading >= interval.end { return [interval] }
                        var remaining: [(start: CGFloat, end: CGFloat)] = []
                        if leading > interval.start { remaining.append((interval.start, min(interval.end, leading))) }
                        if trailing < interval.end { remaining.append((max(interval.start, trailing), interval.end)) }
                        return remaining
                    }
                }
                chosen = intervals.filter { $0.end - $0.start >= needed }.sorted {
                    let a = $0.end - $0.start, b = $1.end - $1.start
                    return a == b ? $0.start < $1.start : a > b
                }.first
                if chosen != nil { break }
            }
            if let chosen {
                for target in present {
                    occupied[target]!.origin.x = chosen.start
                    occupied[target]!.size.width = chosen.end - chosen.start
                }
            } else { faults.append(.controlCannotAvoidRegion(slot)) }
        }
        return (occupied, faults)
    }

    private static func minimumWidth(_ slot: Slot, frames: [Slot: CGRect], base: HomeLayout,
                                     minimum: HomeLayout.MinimumWidths, floor: CGFloat) -> CGFloat {
        let word: CGFloat
        switch slot {
        case .message, .statusLine: return minimum.message
        case .yes, .no: word = minimum.yesNo
        case .emergency: word = minimum.emergency
        case .again: word = minimum.again
        case .getAttention: word = frames[slot]!.height < HomeLayout.twoLineQuickControlHeight ? minimum.getAttentionOneLine : minimum.getAttention
        case .phrases: word = minimum.phrases
        case .type: word = minimum.type
        case .stop: word = minimum.stop
        case .category: word = minimum.category
        case .settings: word = base.settingsShowsName ? minimum.settings : minimum.settingsSymbol
        case .phraseGrid: word = floor
        }
        return max(floor, word)
    }

    private static func phraseGrid(frame: CGRect, vertical: CGRect?, hasDivision: Bool, regular: Bool,
                                   boldText: Bool, floor: CGFloat, insufficientWidth: inout Bool) -> HomeLayout.Grid {
        let spacing = HomeLayout.controlSpacing
        let minimum = regular ? (boldText ? HomeLayout.regularTile.boldMinimumWidth : HomeLayout.regularTile.minimumWidth)
            : (boldText ? HomeLayout.compactTile.boldMinimumWidth : HomeLayout.compactTile.minimumWidth)
        var columns: [CGRect] = []
        func append(_ count: Int, start: CGFloat, width: CGFloat) {
            let cell = max(0, (width - CGFloat(count - 1) * spacing) / CGFloat(count))
            if cell < max(minimum, floor) - 0.001 { insufficientWidth = true }
            for index in 0..<count {
                columns.append(CGRect(x: start + CGFloat(index) * (cell + spacing), y: frame.minY, width: cell, height: frame.height))
            }
        }
        if let vertical, overlaps(vertical, frame), vertical.minX > frame.minX, vertical.maxX < frame.maxX {
            let left = vertical.minX - frame.minX, right = frame.maxX - vertical.maxX
            let count = min(left, right) >= 2 * max(minimum, floor) + spacing ? 2 : 1
            append(count, start: frame.minX, width: left)
            append(count, start: vertical.maxX, width: right)
        } else {
            let preferred = hasDivision ? 4 : regular ? 4 : 3
            let fallback = hasDivision ? 2 : regular ? 3 : 2
            let count = frame.width >= CGFloat(preferred) * max(minimum, floor) + CGFloat(preferred - 1) * spacing ? preferred : fallback
            append(count, start: frame.minX, width: frame.width)
        }
        let floors = regular ? HomeLayout.regularTile.floors : HomeLayout.compactTile.floors
        let rowFloor = columns.map { HomeLayout.TileFloor.height(for: $0.width, in: floors, boldText: boldText, profileFloor: floor) }.max() ?? floor
        return HomeLayout.Grid(frame: frame, columnFrames: columns, phraseCount: HomeLayout.referencePhraseCount, tileFloor: rowFloor, spacing: spacing)
    }

    private static func logicalRows(_ base: HomeLayout) -> [[Slot]] {
        var rows: [[Slot]] = [[.message, .statusLine] + (base.modes == .phrasesAndTyping ? [.phrases, .type] : [])]
        if base.isRegular && base.modes == .phrasesAndTyping { rows += [Slot.safetyRow] }
        else { rows += [[.yes, .no, .emergency], [.again, .getAttention]] }
        switch base.categoryArrangement {
        case .band: rows += [[.stop, .category(0), .category(1), .category(2), .category(3), .settings]]
        case .threeColumns: rows += [[.stop, .category(0), .category(1)], [.category(2), .category(3), .settings]]
        case .twoColumns: rows += [[.stop, .category(0)], [.category(1), .category(2)], [.category(3), .settings]]
        }
        return rows
    }

    private static func backFrame(base: HomeLayout, frames: [Slot: CGRect]) -> CGRect {
        guard let phrases = frames[.phrases] else { return .null }
        var width = min(phrases.width, base.backToTalking.width)
        if base.isRegular {
            for slot in Slot.safetyRow {
                let other = frames[slot]!
                let across = abs(other.midX - phrases.midX), down = abs(other.midY - phrases.midY)
                if across > 0.001 {
                    width = min(width, max(0, (across * across + down * down - down * phrases.height) / across - 4))
                }
            }
        }
        return CGRect(x: phrases.midX - width / 2, y: phrases.minY, width: width, height: phrases.height)
    }

    private static func union(_ slots: [Slot], _ frames: [Slot: CGRect]) -> CGRect {
        slots.compactMap { frames[$0] }.reduce(CGRect.null) { $0.union($1) }
    }

    static func overlaps(_ a: CGRect, _ b: CGRect) -> Bool {
        !a.isEmpty && !b.isEmpty && a.minX < b.maxX && b.minX < a.maxX && a.minY < b.maxY && b.minY < a.maxY
    }
}
