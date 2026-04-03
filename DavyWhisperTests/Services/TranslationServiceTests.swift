import XCTest
@testable import DavyWhisper

#if canImport(Translation)
@available(macOS 15, *)
@MainActor
final class TranslationServiceTests: XCTestCase {

    // MARK: - availableTargetLanguages

    func testAvailableTargetLanguages_notEmpty() {
        let langs = TranslationService.availableTargetLanguages
        XCTAssertFalse(langs.isEmpty)
    }

    func testAvailableTargetLanguages_containsEnglish() {
        let langs = TranslationService.availableTargetLanguages
        XCTAssertTrue(langs.contains { $0.code == "en" })
    }

    func testAvailableTargetLanguages_containsChineseSimplified() {
        let langs = TranslationService.availableTargetLanguages
        XCTAssertTrue(langs.contains { $0.code == "zh-Hans" })
    }

    func testAvailableTargetLanguages_sortedByName() {
        let langs = TranslationService.availableTargetLanguages
        for i in 1..<langs.count {
            let cmp = langs[i - 1].name.localizedCaseInsensitiveCompare(langs[i].name)
            XCTAssertLessThanOrEqual(cmp.rawValue, 0,
                "\(langs[i - 1].name) should not sort after \(langs[i].name)")
        }
    }

    func testAvailableTargetLanguages_allHaveCodeAndName() {
        for lang in TranslationService.availableTargetLanguages {
            XCTAssertFalse(lang.code.isEmpty)
            XCTAssertFalse(lang.name.isEmpty)
        }
    }

    // MARK: - normalizedLanguageIdentifier

    func testNormalizedLanguageIdentifier_nil_returnsNil() {
        XCTAssertNil(TranslationService.normalizedLanguageIdentifier(from: nil))
    }

    func testNormalizedLanguageIdentifier_emptyString_returnsNil() {
        XCTAssertNil(TranslationService.normalizedLanguageIdentifier(from: ""))
    }

    func testNormalizedLanguageIdentifier_whitespaceOnly_returnsNil() {
        XCTAssertNil(TranslationService.normalizedLanguageIdentifier(from: "   "))
    }

    func testNormalizedLanguageIdentifier_auto_returnsNil() {
        XCTAssertNil(TranslationService.normalizedLanguageIdentifier(from: "auto"))
        XCTAssertNil(TranslationService.normalizedLanguageIdentifier(from: "Auto"))
        XCTAssertNil(TranslationService.normalizedLanguageIdentifier(from: "AUTO"))
    }

    func testNormalizedLanguageIdentifier_underscoreReplaced() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "en_US"), "en")
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "zh_Hans"), "zh-Hans")
    }

    func testNormalizedLanguageIdentifier_regionVariant() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "de-DE"), "de")
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "de_DE"), "de")
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "en-US"), "en")
    }

    func testNormalizedLanguageIdentifier_scriptSpecific() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "zh-Hans"), "zh-Hans")
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "zh-Hant"), "zh-Hant")
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "ZH-HANS"), "zh-Hans")
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "Zh-Hans"), "zh-Hans")
    }

    func testNormalizedLanguageIdentifier_nativeAliases() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "german"), "de")
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "deutsch"), "de")
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "english"), "en")
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "spanish"), "es")
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "chinese simplified"), "zh-Hans")
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "simplified chinese"), "zh-Hans")
    }

    func testNormalizedLanguageIdentifier_unknown_returnsNil() {
        XCTAssertNil(TranslationService.normalizedLanguageIdentifier(from: "notalanguage"))
        XCTAssertNil(TranslationService.normalizedLanguageIdentifier(from: "xyz"))
    }

    func testNormalizedLanguageIdentifier_diacriticFolding() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "español"), "es")
    }

    func testNormalizedLanguageIdentifier_trimsWhitespace() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "  en  "), "en")
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "\tde\n"), "de")
    }

    func testNormalizedLanguageIdentifier_caseInsensitive() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "EN"), "en")
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "De"), "de")
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "ZH-HANT"), "zh-Hant")
    }

    // MARK: - makeLanguage

    func testMakeLanguage_validIdentifier_returnsNonNil() {
        XCTAssertNotNil(TranslationService.makeLanguage(from: "en"))
    }

    func testMakeLanguage_nil_returnsNil() {
        XCTAssertNil(TranslationService.makeLanguage(from: nil))
    }

    func testMakeLanguage_invalid_returnsNil() {
        XCTAssertNil(TranslationService.makeLanguage(from: "notalanguage"))
    }

    func testMakeLanguage_chineseSimplified() {
        let lang = TranslationService.makeLanguage(from: "zh-Hans")
        XCTAssertNotNil(lang)
        XCTAssertEqual(lang, Locale.Language(identifier: "zh-Hans"))
    }

    func testMakeLanguage_german() {
        let lang = TranslationService.makeLanguage(from: "german")
        XCTAssertNotNil(lang)
        XCTAssertEqual(lang, Locale.Language(identifier: "de"))
    }

    func testMakeLanguage_regionVariant() {
        let lang = TranslationService.makeLanguage(from: "de-DE")
        XCTAssertNotNil(lang)
        XCTAssertEqual(lang, Locale.Language(identifier: "de"))
    }
}
#endif
