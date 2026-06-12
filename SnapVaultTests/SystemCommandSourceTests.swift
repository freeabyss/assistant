import XCTest
@testable import SnapVault

final class SystemCommandSourceTests: XCTestCase {
    func testSleepCommandMatchesPrimaryKeywordWithoutExecuting() async throws {
        let source = SystemCommandSource()

        let results = try await source.search(query: "sleep", limit: 5)

        XCTAssertEqual(results.first?.type, .systemCommand)
        if case .runSystemCommand(let command) = results.first?.action {
            XCTAssertEqual(command, .sleep)
            XCTAssertFalse(command.requiresConfirmation)
        } else {
            XCTFail("Sleep search result should carry a runSystemCommand action")
        }
    }

    func testChineseAliasMatchesRestartWithoutExecuting() async throws {
        let source = SystemCommandSource()

        let results = try await source.search(query: "重启", limit: 5)

        XCTAssertTrue(results.contains { result in
            if case .runSystemCommand(let command) = result.action {
                return command == .restart
            }
            return false
        })
    }

    func testDestructiveCommandsRequireConfirmation() async throws {
        let source = SystemCommandSource()

        let shutdownResults = try await source.search(query: "shutdown", limit: 5)
        let emptyTrashResults = try await source.search(query: "trash", limit: 5)

        XCTAssertTrue(shutdownResults.contains { result in
            if case .runSystemCommand(let command) = result.action {
                return command == .shutdown && command.requiresConfirmation
            }
            return false
        })
        XCTAssertTrue(emptyTrashResults.contains { result in
            if case .runSystemCommand(let command) = result.action {
                return command == .emptyTrash && command.requiresConfirmation
            }
            return false
        })
    }

    func testCommandChinesePinyinInitialsMatch() async throws {
        let source = SystemCommandSource()

        let results = try await source.search(query: "sm", limit: 5)

        XCTAssertTrue(results.contains { result in
            if case .runSystemCommand(let command) = result.action {
                return command == .sleep
            }
            return false
        })
    }

    func testCommandEnglishAndChineseAliasesAreBothSearchable() async throws {
        let source = SystemCommandSource()

        let english = try await source.search(query: "zzz", limit: 5)
        let chinese = try await source.search(query: "休眠", limit: 5)

        XCTAssertTrue(english.contains { result in
            if case .runSystemCommand(let command) = result.action { return command == .sleep }
            return false
        })
        XCTAssertTrue(chinese.contains { result in
            if case .runSystemCommand(let command) = result.action { return command == .sleep }
            return false
        })
    }

    func testUnknownCommandReturnsNoResults() async throws {
        let source = SystemCommandSource()

        let results = try await source.search(query: "definitely-not-a-command", limit: 5)

        XCTAssertTrue(results.isEmpty)
    }
}
