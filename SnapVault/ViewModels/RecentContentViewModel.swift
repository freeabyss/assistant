import Foundation
import AppKit
import Combine
import os.log

/// Filter for the "Recent" content center.
///
/// `screenshot` is a heuristic over the existing schema (no new column): an image
/// item that has OCR text recognised is treated as a screenshot, since the OCR
/// pipeline (US-006 / US-012) runs on captured screenshots and pasted screenshots
/// alike, but rarely on pure design assets pasted via Finder.
enum RecentFilter: Equatable, Hashable, Identifiable, CaseIterable {
    case all
    case screenshot
    case ocr
    case clipboard

    var id: String { title }

    var title: String {
        switch self {
        case .all: return "All"
        case .screenshot: return "Screenshot"
        case .ocr: return "OCR"
        case .clipboard: return "Clipboard"
        }
    }

    var iconName: String {
        switch self {
        case .all: return "tray.full"
        case .screenshot: return "camera.viewfinder"
        case .ocr: return "doc.text.viewfinder"
        case .clipboard: return "clipboard"
        }
    }
}

/// Logical date bucket for the Recent list section headers.
///
/// `.weekday(name:)` covers earlier-this-week (e.g. "周一"), `.older(monthDay:)`
/// covers anything before this week (e.g. "5月23日"). The ordering is fixed by
/// the order items are appended to `groups` (today first → older last).
enum DateGroup: Identifiable, Hashable {
    case today
    case yesterday
    case weekday(name: String)
    case older(monthDay: String)

    var id: String {
        switch self {
        case .today: return "today"
        case .yesterday: return "yesterday"
        case .weekday(let name): return "weekday:\(name)"
        case .older(let monthDay): return "older:\(monthDay)"
        }
    }

    var title: String {
        switch self {
        case .today: return "今天"
        case .yesterday: return "昨天"
        case .weekday(let name): return name
        case .older(let monthDay): return monthDay
        }
    }
}

/// One date-grouped section worth of recent items.
struct RecentSection: Identifiable {
    let group: DateGroup
    let items: [ClipboardItem]

    var id: DateGroup.ID { group.id }
}

/// ViewModel backing the "Recent Content Center" panel (US-023).
///
/// Data source = the same `clipboard_items` table everything else uses; no new
/// schema is introduced. Items are loaded once per refresh (capped at
/// `fetchLimit` to keep the panel responsive — older entries are still searchable
/// via the regular search mode) and then bucketed in-memory by `createdAt`.
@MainActor
final class RecentContentViewModel: ObservableObject {
    // MARK: - Published State

    @Published var sections: [RecentSection] = []
    @Published var filter: RecentFilter = .all
    @Published var isLoading: Bool = false
    @Published var toastMessage: String = ""
    @Published var showToast: Bool = false

    // MARK: - Private

    private let repository = ContentRepository()
    private let logger = Logger.ui
    private let fetchLimit = 500
    private var cancellables = Set<AnyCancellable>()
    private var savedObserver: NSObjectProtocol?

    // MARK: - Init

    init() {
        setupFilterSubscription()
        setupNewContentObserver()
    }

    deinit {
        if let observer = savedObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public API

    /// Reload recent items and rebuild the date-grouped sections.
    func loadGroups() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            // Fetch enough rows to cover "today / yesterday / this week / older"
            // for typical users without paging. ContentRepository orders by
            // pinned → favorite → createdAt; we re-sort strictly by createdAt
            // below so the section grouping is purely time-based.
            let rows = try repository.fetchHistory(
                page: 0,
                pageSize: fetchLimit,
                contentType: nil,
                pinnedOnly: false
            )

            let filtered = rows.filter { matches(filter: filter, $0) }

            // Strict time-descending ordering for date sections.
            let timeSorted = filtered.sorted { $0.createdAt > $1.createdAt }

            self.sections = Self.groupByDate(timeSorted)
            logger.debug("RecentContent loaded \(filtered.count) items in \(self.sections.count) sections (filter=\(self.filter.title, privacy: .public))")
        } catch {
            logger.error("RecentContent failed to load: \(error.localizedDescription, privacy: .public)")
            sections = []
        }
    }

    /// Delete a single item and update the in-memory sections.
    func deleteItem(_ item: ClipboardItem) async {
        guard let id = item.id else { return }
        do {
            try repository.delete(id: id)
            removeItemLocally(id: id)
            logger.debug("RecentContent deleted item id=\(id)")
        } catch {
            logger.error("RecentContent delete failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Toggle pin state and refresh sections (pin doesn't change date bucketing).
    func togglePin(_ item: ClipboardItem) async {
        guard let id = item.id else { return }
        do {
            try repository.togglePin(id: id)
            updateItemLocally(id: id) { $0.isPinned.toggle() }
            logger.debug("RecentContent toggled pin id=\(id)")
        } catch {
            logger.error("RecentContent toggle pin failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Toggle favorite state.
    func toggleFavorite(_ item: ClipboardItem) async {
        guard let id = item.id else { return }
        do {
            let newState = try repository.toggleFavorite(id: id)
            updateItemLocally(id: id) { $0.isFavorite = newState }
            logger.debug("RecentContent toggled favorite id=\(id), state=\(newState)")
        } catch {
            logger.error("RecentContent toggle favorite failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Copy an item back to the system clipboard.
    func copyToClipboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.contentType {
        case .text:
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }
        case .rtf:
            if let rtf = item.rtfContent, let data = rtf.data(using: .utf8) {
                pasteboard.setData(data, forType: .rtf)
            }
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }
        case .image:
            if let data = item.imageData {
                pasteboard.setData(data, forType: .tiff)
            }
        case .file:
            if let path = item.filePath {
                let url = URL(fileURLWithPath: path)
                pasteboard.clearContents()
                pasteboard.writeObjects([url as NSPasteboardWriting])
            }
        }

        showCopyToast()
        logger.debug("RecentContent copied item id=\(String(describing: item.id))")
    }

    // MARK: - Filter

    /// Match heuristic for each filter (see RecentFilter doc for screenshot rule).
    private func matches(filter: RecentFilter, _ item: ClipboardItem) -> Bool {
        switch filter {
        case .all:
            return true
        case .screenshot:
            // Image with OCR text recognised → almost always a screenshot.
            // ContentStore + ScreenshotService both populate ocr_text when text
            // is detected. A pure image with no OCR (logo, photo, etc.) is
            // excluded to keep this list focused on the screenshot workflow.
            return item.contentType == .image && (item.ocrText?.isEmpty == false)
        case .ocr:
            // Any record carrying OCR text, regardless of content type.
            return (item.ocrText?.isEmpty == false)
        case .clipboard:
            // Text-like records (plain or RTF) — the "what I copied" view.
            return item.contentType == .text || item.contentType == .rtf
        }
    }

    // MARK: - Local Mutation

    private func updateItemLocally(id: Int64, mutate: (inout ClipboardItem) -> Void) {
        sections = sections.map { section in
            var items = section.items
            if let idx = items.firstIndex(where: { $0.id == id }) {
                mutate(&items[idx])
            }
            return RecentSection(group: section.group, items: items)
        }
    }

    private func removeItemLocally(id: Int64) {
        sections = sections.compactMap { section in
            let filtered = section.items.filter { $0.id != id }
            if filtered.isEmpty { return nil }
            return RecentSection(group: section.group, items: filtered)
        }
    }

    private func showCopyToast() {
        toastMessage = "已复制"
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.showToast = false
        }
    }

    // MARK: - Subscriptions

    private func setupFilterSubscription() {
        $filter
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.loadGroups()
                }
            }
            .store(in: &cancellables)
    }

    private func setupNewContentObserver() {
        savedObserver = NotificationCenter.default.addObserver(
            forName: .clipboardItemSaved,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.loadGroups()
            }
        }
    }

    // MARK: - Grouping

    /// Bucket items into ordered DateGroup sections.
    ///
    /// Algorithm:
    /// - today: `Calendar.isDateInToday`
    /// - yesterday: `Calendar.isDateInYesterday`
    /// - earlier-this-week: same ISO week as today → weekday name
    /// - older: short month/day label ("M月d日")
    ///
    /// Section ordering follows insertion order (which mirrors timeSorted),
    /// so a SwiftUI ForEach over `sections` shows newest sections first.
    static func groupByDate(_ items: [ClipboardItem]) -> [RecentSection] {
        let calendar = Calendar.current
        let now = Date()
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = Locale(identifier: "zh_CN")
        weekdayFormatter.dateFormat = "EEEE" // 星期一
        let monthDayFormatter = DateFormatter()
        monthDayFormatter.locale = Locale(identifier: "zh_CN")
        monthDayFormatter.dateFormat = "M月d日"

        // Preserve first-seen group order using an ordered list + lookup map.
        var orderedGroups: [DateGroup] = []
        var buckets: [DateGroup: [ClipboardItem]] = [:]

        for item in items {
            let group = bucket(for: item.createdAt,
                               now: now,
                               calendar: calendar,
                               weekdayFormatter: weekdayFormatter,
                               monthDayFormatter: monthDayFormatter)
            if buckets[group] == nil {
                orderedGroups.append(group)
                buckets[group] = []
            }
            buckets[group]?.append(item)
        }

        return orderedGroups.map { RecentSection(group: $0, items: buckets[$0] ?? []) }
    }

    /// Compute the DateGroup bucket for a single timestamp.
    private static func bucket(
        for date: Date,
        now: Date,
        calendar: Calendar,
        weekdayFormatter: DateFormatter,
        monthDayFormatter: DateFormatter
    ) -> DateGroup {
        if calendar.isDateInToday(date) {
            return .today
        }
        if calendar.isDateInYesterday(date) {
            return .yesterday
        }
        // Earlier-this-week check: same ISO week + same year-for-week as `now`.
        let dateComps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let nowComps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        if dateComps.yearForWeekOfYear == nowComps.yearForWeekOfYear,
           dateComps.weekOfYear == nowComps.weekOfYear {
            return .weekday(name: weekdayFormatter.string(from: date))
        }
        return .older(monthDay: monthDayFormatter.string(from: date))
    }
}
