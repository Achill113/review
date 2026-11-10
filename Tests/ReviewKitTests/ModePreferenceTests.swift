import Foundation
import Testing
import ReviewKit

@Suite
struct ModePreferenceTests {
    private func makeDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "ModePreferenceTests-\(UUID())"))
    }

    @Test("Starts in the diff when nothing has been chosen")
    func defaultsToDiff() throws {
        #expect(ModePreference(defaults: try makeDefaults()).mode == .diff)
    }

    @Test("Remembers split across launches")
    func remembersSplit() throws {
        let defaults = try makeDefaults()
        ModePreference(defaults: defaults).remember(.split)
        #expect(ModePreference(defaults: defaults).mode == .split)
    }

    @Test("Going back to diff replaces split")
    func remembersDiff() throws {
        let defaults = try makeDefaults()
        let preference = ModePreference(defaults: defaults)
        preference.remember(.split)
        preference.remember(.diff)
        #expect(ModePreference(defaults: defaults).mode == .diff)
    }

    @Test("Whole file is not remembered, so the last diff layout stays")
    func ignoresFile() throws {
        let defaults = try makeDefaults()
        let preference = ModePreference(defaults: defaults)
        preference.remember(.split)
        preference.remember(.file)
        #expect(ModePreference(defaults: defaults).mode == .split)
    }

    @Test("An unreadable stored value falls back to diff")
    func ignoresGarbage() throws {
        let defaults = try makeDefaults()
        defaults.set("file", forKey: ModePreference.key)
        #expect(ModePreference(defaults: defaults).mode == .diff)
    }
}
