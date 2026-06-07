import Foundation
import Testing

@testable import BarMasterCore

@Suite("Update checker — version compare + URL resolution")
struct UpdateCheckerTests {

    @Test
    func equalVersionsAreNotNewer() {
        #expect(!UpdateChecker.isNewer("1.0.0", than: "1.0.0"))
        #expect(!UpdateChecker.isNewer("1.0", than: "1.0.0"))
    }

    @Test
    func patchBumpIsNewer() {
        #expect(UpdateChecker.isNewer("1.0.1", than: "1.0.0"))
        #expect(!UpdateChecker.isNewer("1.0.0", than: "1.0.1"))
    }

    @Test
    func minorBumpIsNewer() {
        #expect(UpdateChecker.isNewer("1.1.0", than: "1.0.99"))
    }

    @Test
    func numericCompareNotLexicographic() {
        #expect(UpdateChecker.isNewer("1.2.10", than: "1.2.9"))
    }

    @Test
    func malformedSegmentsTreatedAsZero() {
        #expect(!UpdateChecker.isNewer("1.0.beta", than: "1.0.0"))
        #expect(!UpdateChecker.isNewer("1.0.0", than: "1.0.beta"))
    }

    @Test
    func decodesSampleResponse() throws {
        let json = #"""
        {
          "app": "barmaster",
          "version": "1.2.3",
          "releasedAt": "2026-06-07T10:00:00Z",
          "notes": "Initial release.",
          "minOS": "macOS 26.0",
          "sha256": "deadbeef",
          "size": 12345678,
          "downloadUrl": "/api/download?app=barmaster"
        }
        """#
        let info = try JSONDecoder().decode(VersionInfo.self, from: Data(json.utf8))
        #expect(info.app == "barmaster")
        #expect(info.version == "1.2.3")
        #expect(info.size == 12345678)
        #expect(info.downloadUrl == "/api/download?app=barmaster")
    }

    @Test
    func decodesWithMissingOptionalFields() throws {
        let json = #"""
        { "app": "barmaster", "version": "1.0.0" }
        """#
        let info = try JSONDecoder().decode(VersionInfo.self, from: Data(json.utf8))
        #expect(info.notes == nil)
        #expect(info.size == nil)
        #expect(info.downloadUrl == nil)
    }

    @Test
    func relativeDownloadURLResolvesAgainstHost() throws {
        let info = try JSONDecoder().decode(VersionInfo.self, from: Data(#"""
        { "app": "barmaster", "version": "1.0.0", "downloadUrl": "/api/download?app=barmaster" }
        """#.utf8))
        let resolved = info.resolvedDownloadURL(
            relativeTo: URL(string: "https://anti.ltd/api1/version")!)
        #expect(resolved?.absoluteString == "https://anti.ltd/api/download?app=barmaster")
    }

    @Test
    func absoluteDownloadURLPassesThrough() throws {
        let info = try JSONDecoder().decode(VersionInfo.self, from: Data(#"""
        { "app": "barmaster", "version": "1.0.0", "downloadUrl": "https://cdn.example/barmaster.dmg" }
        """#.utf8))
        let resolved = info.resolvedDownloadURL()
        #expect(resolved?.absoluteString == "https://cdn.example/barmaster.dmg")
    }

    @Test
    func missingDownloadURLReturnsNil() throws {
        let info = try JSONDecoder().decode(VersionInfo.self, from: Data(#"""
        { "app": "barmaster", "version": "1.0.0" }
        """#.utf8))
        #expect(info.resolvedDownloadURL() == nil)
    }
}
