import XCTest
@testable import DavyWhisper

#if canImport(Translation)
@available(macOS 15, *)
@MainActor
final class TranslationServiceExtendedTests: XCTestCase {

    // MARK: - normalizedLanguageIdentifier: Additional Language Codes

    func testNormalizedLanguageIdentifier_ja() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "ja"), "ja")
    }

    func testNormalizedLanguageIdentifier_ko() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "ko"), "ko")
    }

    func testNormalizedLanguageIdentifier_fr() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "fr"), "fr")
    }

    func testNormalizedLanguageIdentifier_es() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "es"), "es")
    }

    func testNormalizedLanguageIdentifier_pt() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "pt"), "pt")
    }

    func testNormalizedLanguageIdentifier_ru() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "ru"), "ru")
    }

    func testNormalizedLanguageIdentifier_ar() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "ar"), "ar")
    }

    func testNormalizedLanguageIdentifier_hi() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "hi"), "hi")
    }

    func testNormalizedLanguageIdentifier_vi() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "vi"), "vi")
    }

    func testNormalizedLanguageIdentifier_th() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "th"), "th")
    }

    func testNormalizedLanguageIdentifier_tr() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "tr"), "tr")
    }

    func testNormalizedLanguageIdentifier_uk() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "uk"), "uk")
    }

    func testNormalizedLanguageIdentifier_nl() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "nl"), "nl")
    }

    func testNormalizedLanguageIdentifier_pl() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "pl"), "pl")
    }

    func testNormalizedLanguageIdentifier_id() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "id"), "id")
    }

    func testNormalizedLanguageIdentifier_it() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "it"), "it")
    }

    // MARK: - normalizedLanguageIdentifier: Region Variants

    func testNormalizedLanguageIdentifier_enGB() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "en-GB"), "en")
    }

    func testNormalizedLanguageIdentifier_zhCN() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "zh-CN"), "zh")
    }

    func testNormalizedLanguageIdentifier_jaJP() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "ja-JP"), "ja")
    }

    func testNormalizedLanguageIdentifier_frFR() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "fr-FR"), "fr")
    }

    func testNormalizedLanguageIdentifier_ptBR() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "pt-BR"), "pt")
    }

    // MARK: - normalizedLanguageIdentifier: Additional Aliases

    func testNormalizedLanguageIdentifier_englisch() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "englisch"), "en")
    }

    func testNormalizedLanguageIdentifier_spanisch() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "spanisch"), "es")
    }

    func testNormalizedLanguageIdentifier_espanol() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "espanol"), "es")
    }

    func testNormalizedLanguageIdentifier_chineseTraditional() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "chinese traditional"), "zh-Hant")
    }

    func testNormalizedLanguageIdentifier_traditionalChinese() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "traditional chinese"), "zh-Hant")
    }

    // MARK: - normalizedLanguageIdentifier: Edge Cases

    func testNormalizedLanguageIdentifier_mixedCaseRegion() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "EN-us"), "en")
    }

    func testNormalizedLanguageIdentifier_multipleRegionParts() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "zh-Hans-CN"), "zh")
    }

    func testNormalizedLanguageIdentifier_tabsAndNewlines() {
        XCTAssertEqual(TranslationService.normalizedLanguageIdentifier(from: "\t\nen\n\t"), "en")
    }

    func testNormalizedLanguageIdentifier_numberString_returnsNil() {
        XCTAssertNil(TranslationService.normalizedLanguageIdentifier(from: "123"))
    }

    func testNormalizedLanguageIdentifier_specialCharacters_returnsNil() {
        XCTAssertNil(TranslationService.normalizedLanguageIdentifier(from: "@#$%"))
    }

    // MARK: - makeLanguage: Extended Tests

    func testMakeLanguage_french() {
        let lang = TranslationService.makeLanguage(from: "fr")
        XCTAssertNotNil(lang)
        XCTAssertEqual(lang, Locale.Language(identifier: "fr"))
    }

    func testMakeLanguage_japanese() {
        let lang = TranslationService.makeLanguage(from: "ja")
        XCTAssertNotNil(lang)
        XCTAssertEqual(lang, Locale.Language(identifier: "ja"))
    }

    func testMakeLanguage_korean() {
        let lang = TranslationService.makeLanguage(from: "ko")
        XCTAssertNotNil(lang)
        XCTAssertEqual(lang, Locale.Language(identifier: "ko"))
    }

    func testMakeLanguage_spanish() {
        let lang = TranslationService.makeLanguage(from: "spanish")
        XCTAssertNotNil(lang)
        XCTAssertEqual(lang, Locale.Language(identifier: "es"))
    }

    func testMakeLanguage_englishAlias() {
        let lang = TranslationService.makeLanguage(from: "english")
        XCTAssertNotNil(lang)
        XCTAssertEqual(lang, Locale.Language(identifier: "en"))
    }

    func testMakeLanguage_germanAlias() {
        let lang = TranslationService.makeLanguage(from: "deutsch")
        XCTAssertNotNil(lang)
        XCTAssertEqual(lang, Locale.Language(identifier: "de"))
    }

    func testMakeLanguage_regionVariant_jaJP() {
        let lang = TranslationService.makeLanguage(from: "ja-JP")
        XCTAssertNotNil(lang)
        XCTAssertEqual(lang, Locale.Language(identifier: "ja"))
    }

    func testMakeLanguage_auto_returnsNil() {
        XCTAssertNil(TranslationService.makeLanguage(from: "auto"))
    }

    func testMakeLanguage_emptyString_returnsNil() {
        XCTAssertNil(TranslationService.makeLanguage(from: ""))
    }

    // MARK: - availableTargetLanguages: Extended Tests

    func testAvailableTargetLanguages_containsJapanese() {
        XCTAssertTrue(TranslationService.availableTargetLanguages.contains { $0.code == "ja" })
    }

    func testAvailableTargetLanguages_containsKorean() {
        XCTAssertTrue(TranslationService.availableTargetLanguages.contains { $0.code == "ko" })
    }

    func testAvailableTargetLanguages_containsFrench() {
        XCTAssertTrue(TranslationService.availableTargetLanguages.contains { $0.code == "fr" })
    }

    func testAvailableTargetLanguages_containsGerman() {
        XCTAssertTrue(TranslationService.availableTargetLanguages.contains { $0.code == "de" })
    }

    func testAvailableTargetLanguages_containsSpanish() {
        XCTAssertTrue(TranslationService.availableTargetLanguages.contains { $0.code == "es" })
    }

    func testAvailableTargetLanguages_containsRussian() {
        XCTAssertTrue(TranslationService.availableTargetLanguages.contains { $0.code == "ru" })
    }

    func testAvailableTargetLanguages_containsArabic() {
        XCTAssertTrue(TranslationService.availableTargetLanguages.contains { $0.code == "ar" })
    }

    func testAvailableTargetLanguages_containsVietnamese() {
        XCTAssertTrue(TranslationService.availableTargetLanguages.contains { $0.code == "vi" })
    }

    func testAvailableTargetLanguages_containsChineseTraditional() {
        XCTAssertTrue(TranslationService.availableTargetLanguages.contains { $0.code == "zh-Hant" })
    }

    func testAvailableTargetLanguages_expectedCount() {
        // 20 languages defined in the static list
        XCTAssertEqual(TranslationService.availableTargetLanguages.count, 20)
    }

    func testAvailableTargetLanguages_noDuplicateCodes() {
        let codes = TranslationService.availableTargetLanguages.map(\.code)
        let uniqueCodes = Set(codes)
        XCTAssertEqual(codes.count, uniqueCodes.count, "Duplicate language codes found")
    }

    // MARK: - TranslationService initial state

    func testInitialState_configurationIsNil() {
        let service = TranslationService()
        XCTAssertNil(service.configuration)
    }

    func testInitialState_viewIdIsValid() {
        let service = TranslationService()
        XCTAssertNotNil(service.viewId)
    }

    func testSetInteractiveHostMode_callbackCanBeSet() {
        let service = TranslationService()
        var callbackFired = false
        service.setInteractiveHostMode = { _ in callbackFired = true }
        service.setInteractiveHostMode?(true)
        XCTAssertTrue(callbackFired)
    }

    func testSetInteractiveHostMode_callbackReceivesCorrectValue() {
        let service = TranslationService()
        var receivedValue: Bool?
        service.setInteractiveHostMode = { receivedValue = $0 }
        service.setInteractiveHostMode?(true)
        XCTAssertEqual(receivedValue, true)
        service.setInteractiveHostMode?(false)
        XCTAssertEqual(receivedValue, false)
    }
}
#endif
