import XCTest
@testable import DavyWhisper

@MainActor
final class FileTranscriptionViewModelTests: XCTestCase {

    var container: TestServiceContainer!

    override func setUp() {
        super.setUp()
        container = try! TestServiceContainer()
    }

    override func tearDown() {
        container.tearDown()
        container = nil
        super.tearDown()
    }

    // MARK: - FileItem State Enum

    func testFileItemState_equatable() {
        XCTAssertEqual(FileTranscriptionViewModel.FileItemState.pending, .pending)
        XCTAssertEqual(FileTranscriptionViewModel.FileItemState.done, .done)
        XCTAssertNotEqual(FileTranscriptionViewModel.FileItemState.pending, .error)
    }

    func testFileItem_defaultStateIsPending() {
        let url = URL(fileURLWithPath: "/tmp/test.wav")
        let item = FileTranscriptionViewModel.FileItem(url: url)

        XCTAssertEqual(item.state, .pending)
        XCTAssertNil(item.result)
        XCTAssertNil(item.errorMessage)
        XCTAssertEqual(item.fileName, "test.wav")
    }

    // MARK: - BatchState Enum

    func testBatchState_equatable() {
        XCTAssertEqual(FileTranscriptionViewModel.BatchState.idle, .idle)
        XCTAssertEqual(FileTranscriptionViewModel.BatchState.processing, .processing)
        XCTAssertEqual(FileTranscriptionViewModel.BatchState.done, .done)
    }

    // MARK: - Initial State

    func testInit_filesIsEmpty() {
        XCTAssertNotNil(container.fileTranscriptionViewModel)
        XCTAssertTrue(container.fileTranscriptionViewModel.files.isEmpty)
        XCTAssertEqual(container.fileTranscriptionViewModel.batchState, .idle)
        XCTAssertEqual(container.fileTranscriptionViewModel.currentIndex, 0)
    }

    // MARK: - Computed Properties

    func testTotalFiles_reflectsArray() {
        let url = URL(fileURLWithPath: "/tmp/a.wav")
        container.fileTranscriptionViewModel.files = [
            FileTranscriptionViewModel.FileItem(url: url),
        ]
        XCTAssertEqual(container.fileTranscriptionViewModel.totalFiles, 1)
    }

    func testCompletedFiles_filtersDoneState() {
        let url1 = URL(fileURLWithPath: "/tmp/a.wav")
        let url2 = URL(fileURLWithPath: "/tmp/b.wav")
        var item1 = FileTranscriptionViewModel.FileItem(url: url1)
        var item2 = FileTranscriptionViewModel.FileItem(url: url2)
        item1.state = .done
        item2.state = .pending
        container.fileTranscriptionViewModel.files = [item1, item2]

        XCTAssertEqual(container.fileTranscriptionViewModel.completedFiles, 1)
    }

    func testHasResults_trueWhenAnyFileDone() {
        let url = URL(fileURLWithPath: "/tmp/a.wav")
        var item = FileTranscriptionViewModel.FileItem(url: url)
        item.state = .done
        container.fileTranscriptionViewModel.files = [item]

        XCTAssertTrue(container.fileTranscriptionViewModel.hasResults)
    }

    func testHasResults_falseWhenAllPending() {
        let url = URL(fileURLWithPath: "/tmp/a.wav")
        container.fileTranscriptionViewModel.files = [
            FileTranscriptionViewModel.FileItem(url: url)
        ]
        XCTAssertFalse(container.fileTranscriptionViewModel.hasResults)
    }

    func testCanTranscribe_falseWhenNoFiles() {
        XCTAssertFalse(container.fileTranscriptionViewModel.canTranscribe)
    }

    func testCanTranscribe_falseWhenBatchProcessing() {
        let url = URL(fileURLWithPath: "/tmp/a.wav")
        container.fileTranscriptionViewModel.files = [
            FileTranscriptionViewModel.FileItem(url: url)
        ]
        container.fileTranscriptionViewModel.batchState = .processing

        XCTAssertFalse(container.fileTranscriptionViewModel.canTranscribe)
    }

    // MARK: - addFiles

    func testAddFiles_appendsNewFiles() {
        let url1 = URL(fileURLWithPath: "/tmp/test.wav")
        container.fileTranscriptionViewModel.addFiles([url1])

        XCTAssertEqual(container.fileTranscriptionViewModel.files.count, 1)
        XCTAssertEqual(container.fileTranscriptionViewModel.files.first?.url, url1)
    }

    func testAddFiles_deduplicatesByURL() {
        let url1 = URL(fileURLWithPath: "/tmp/test.wav")
        container.fileTranscriptionViewModel.addFiles([url1])
        container.fileTranscriptionViewModel.addFiles([url1])

        XCTAssertEqual(container.fileTranscriptionViewModel.files.count, 1)
    }

    func testAddFiles_filtersUnsupportedExtensions() {
        let audioURL = URL(fileURLWithPath: "/tmp/test.wav")
        let txtURL = URL(fileURLWithPath: "/tmp/notes.txt")
        container.fileTranscriptionViewModel.addFiles([audioURL, txtURL])

        XCTAssertEqual(container.fileTranscriptionViewModel.files.count, 1)
        XCTAssertEqual(container.fileTranscriptionViewModel.files.first?.url, audioURL)
    }

    func testAddFiles_multipleFilesAtOnce() {
        let urls = [
            URL(fileURLWithPath: "/tmp/a.wav"),
            URL(fileURLWithPath: "/tmp/b.mp3"),
            URL(fileURLWithPath: "/tmp/c.m4a"),
        ]
        container.fileTranscriptionViewModel.addFiles(urls)

        XCTAssertEqual(container.fileTranscriptionViewModel.files.count, 3)
    }

    // MARK: - removeFile

    func testRemoveFile_decrementsArray() {
        let url = URL(fileURLWithPath: "/tmp/test.wav")
        container.fileTranscriptionViewModel.files = [
            FileTranscriptionViewModel.FileItem(url: url)
        ]
        let item = container.fileTranscriptionViewModel.files.first!

        container.fileTranscriptionViewModel.removeFile(item)

        XCTAssertTrue(container.fileTranscriptionViewModel.files.isEmpty)
    }

    func testRemoveFile_resetsBatchStateWhenEmpty() {
        let url = URL(fileURLWithPath: "/tmp/test.wav")
        container.fileTranscriptionViewModel.files = [
            FileTranscriptionViewModel.FileItem(url: url)
        ]
        let item = container.fileTranscriptionViewModel.files.first!
        container.fileTranscriptionViewModel.batchState = .done

        container.fileTranscriptionViewModel.removeFile(item)

        XCTAssertEqual(container.fileTranscriptionViewModel.batchState, .idle)
    }

    func testRemoveFile_keepsBatchStateWhenNotEmpty() {
        let url1 = URL(fileURLWithPath: "/tmp/a.wav")
        let url2 = URL(fileURLWithPath: "/tmp/b.wav")
        container.fileTranscriptionViewModel.files = [
            FileTranscriptionViewModel.FileItem(url: url1),
            FileTranscriptionViewModel.FileItem(url: url2),
        ]
        container.fileTranscriptionViewModel.batchState = .processing
        let item = container.fileTranscriptionViewModel.files.first!

        container.fileTranscriptionViewModel.removeFile(item)

        XCTAssertEqual(container.fileTranscriptionViewModel.batchState, .processing)
    }

    // MARK: - reset

    func testReset_clearsFilesAndState() {
        let url = URL(fileURLWithPath: "/tmp/test.wav")
        container.fileTranscriptionViewModel.files = [
            FileTranscriptionViewModel.FileItem(url: url)
        ]
        container.fileTranscriptionViewModel.batchState = .done
        container.fileTranscriptionViewModel.currentIndex = 5

        container.fileTranscriptionViewModel.reset()

        XCTAssertTrue(container.fileTranscriptionViewModel.files.isEmpty)
        XCTAssertEqual(container.fileTranscriptionViewModel.batchState, .idle)
        XCTAssertEqual(container.fileTranscriptionViewModel.currentIndex, 0)
    }
}
