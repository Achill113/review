import Testing
import ReviewKit

@Suite
struct VisitHistoryTests {
    private func history(visiting items: String...) -> VisitHistory<String> {
        var history = VisitHistory<String>()
        for item in items { history.visit(item) }
        return history
    }

    @Test("Goes back and forward through visits")
    func backAndForward() {
        var history = history(visiting: "a", "b", "c")
        #expect(history.back == ["a", "b"])
        #expect(history.goBack() == "b")
        #expect(history.goBack() == "a")
        #expect(history.goBack() == nil)
        #expect(history.current == "a")
        #expect(history.goForward() == "b")
        #expect(history.current == "b")
        #expect(history.back == ["a"])
        #expect(history.forward == ["c"])
    }

    @Test("Visiting the current item records nothing")
    func revisitCurrent() {
        let history = history(visiting: "a", "a", "b", "b")
        #expect(history.back == ["a"])
        #expect(history.current == "b")
    }

    @Test("A new visit after going back drops what was ahead")
    func newVisitClearsForward() {
        var history = history(visiting: "a", "b", "c")
        _ = history.goBack()
        history.visit("d")
        #expect(history.back == ["a", "b"])
        #expect(!history.canGoForward)
    }

    @Test("A visit to nothing forgets the current item without recording it")
    func visitNothing() {
        var history = history(visiting: "a")
        history.visit(nil)
        history.visit("b")
        #expect(history.back.isEmpty)
    }

    @Test("Removing the current item returns to the one before it")
    func removeCurrent() {
        var history = history(visiting: "a", "b", "c")
        #expect(history.remove("c") == "b")
        #expect(history.back == ["a"])
        #expect(history.current == "b")
    }

    @Test("Removing the current item with nothing behind goes forward")
    func removeCurrentAtStart() {
        var history = history(visiting: "a", "b")
        _ = history.goBack()
        #expect(history.remove("a") == "b")
        #expect(!history.canGoBack)
        #expect(!history.canGoForward)
    }

    @Test("Removing an item leaves no step that goes nowhere")
    func removeCollapsesRepeats() {
        var history = history(visiting: "a", "x", "a", "x", "b")
        history.remove("x")
        #expect(history.back == ["a"])
        #expect(history.current == "b")

        var returning = self.history(visiting: "a", "x", "a")
        returning.remove("x")
        #expect(returning.back.isEmpty)
        #expect(returning.current == "a")
    }

    @Test("Removing the last item leaves nothing current")
    func removeOnly() {
        var history = history(visiting: "a")
        #expect(history.remove("a") == nil)
        #expect(history.current == nil)
    }

    @Test("Keeps only the most recent visits")
    func limit() {
        var history = VisitHistory<Int>(limit: 3)
        for item in 0..<10 { history.visit(item) }
        #expect(history.back == [6, 7, 8])
    }
}
