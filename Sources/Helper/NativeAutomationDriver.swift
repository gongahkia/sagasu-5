import Foundation
import SagasuAutomationObjC

enum NativeAutomationError: LocalizedError {
    case actionFailed(String)

    var errorDescription: String? {
        switch self {
        case let .actionFailed(message):
            return message
        }
    }
}

final class NativeAutomationDriver {
    private let session = SagasuAutomationSession()

    func load(_ url: String, timeout: TimeInterval = 60) throws {
        var error: NSError?
        let success = session.loadURLString(url, timeout: timeout, error: &error)
        if !success {
            throw error ?? NativeAutomationError.actionFailed("Failed to load \(url).")
        }
    }

    func currentURL() -> String? {
        session.currentURLString()
    }

    func pageHTML() throws -> String? {
        try evaluate("document.documentElement ? document.documentElement.outerHTML : null") as? String
    }

    func snapshotPNGData() throws -> Data? {
        var error: NSError?
        let data = session.snapshotPNGDataWithError(&error)
        if let error {
            throw error
        }
        return data
    }

    func waitForURL(_ pattern: String, timeout: TimeInterval = 30) throws {
        var error: NSError?
        let success = session.waitForURLMatching(pattern, timeout: timeout, error: &error)
        if !success {
            throw error ?? NativeAutomationError.actionFailed("Timed out waiting for URL pattern \(pattern).")
        }
    }

    func waitFor(scriptCondition script: String, timeout: TimeInterval = 30, pollInterval: TimeInterval = 0.25) throws {
        var error: NSError?
        let success = session.waitForJavaScriptCondition(script, timeout: timeout, pollInterval: pollInterval, error: &error)
        if !success {
            throw error ?? NativeAutomationError.actionFailed("Timed out waiting for JavaScript condition.")
        }
    }

    func evaluate(_ script: String) throws -> Any? {
        var error: NSError?
        let result = session.evaluateJavaScriptSync(script, error: &error)
        if let error {
            throw error
        }
        return result
    }

    func click(selector: String) throws {
        try expectTrue(NativeScraperDefinitions.JavaScript.click(selector), message: "Could not click selector \(selector).")
    }

    func fill(selector: String, value: String) throws {
        try expectTrue(NativeScraperDefinitions.JavaScript.fill(selector, value: value), message: "Could not fill selector \(selector).")
    }

    func select(selector: String, value: String) throws {
        try expectTrue(NativeScraperDefinitions.JavaScript.select(selector, value: value), message: "Could not select value for \(selector).")
    }

    func clickText(_ text: String) throws {
        try expectTrue(NativeScraperDefinitions.JavaScript.clickText(text), message: "Could not click text \(text).")
    }

    func value(selector: String) throws -> String? {
        try evaluate(NativeScraperDefinitions.JavaScript.querySelectorValue(selector)) as? String
    }

    func attribute(selector: String, name: String) throws -> String? {
        try evaluate(NativeScraperDefinitions.JavaScript.querySelectorAttribute(selector, attribute: name)) as? String
    }

    func rowsMatrix(selector: String) throws -> [[String]] {
        guard let rows = try evaluate(NativeScraperDefinitions.JavaScript.rowsMatrix(selector)) as? [Any] else { return [] }
        return rows.compactMap { row in
            (row as? [Any])?.compactMap { $0 as? String }
        }
    }

    func roomNames(selector: String) throws -> [String] {
        (try evaluate(NativeScraperDefinitions.JavaScript.roomNames(selector)) as? [String]) ?? []
    }

    func titleAttributes(selector: String) throws -> [String] {
        (try evaluate(NativeScraperDefinitions.JavaScript.titleAttributes(selector)) as? [String]) ?? []
    }

    func waitForNestedFrameSelector(_ selector: String, timeout: TimeInterval = 20) throws {
        let script = NativeScraperDefinitions.JavaScript.nestedFrameExpression(
            "return Boolean(document.querySelector(\(quoted(selector))));"
        )
        try waitFor(scriptCondition: script, timeout: timeout)
    }

    func nestedFrameValue(selector: String) throws -> String? {
        let script = NativeScraperDefinitions.JavaScript.nestedFrameExpression(
            "return (document.querySelector(\(quoted(selector))) || {}).value ?? null;"
        )
        return try evaluate(script) as? String
    }

    func clickInNestedFrame(selector: String) throws {
        let script = NativeScraperDefinitions.JavaScript.nestedFrameExpression(
            """
            const node = document.querySelector(\(quoted(selector)));
            if (!node) { return false; }
            node.click();
            return true;
            """
        )
        try expectTrue(script, message: "Could not click nested frame selector \(selector).")
    }

    func fillInNestedFrame(selector: String, value: String) throws {
        let script = NativeScraperDefinitions.JavaScript.nestedFrameExpression(
            """
            const node = document.querySelector(\(quoted(selector)));
            if (!node) { return false; }
            node.focus();
            node.value = \(quoted(value));
            node.dispatchEvent(new Event('input', { bubbles: true }));
            node.dispatchEvent(new Event('change', { bubbles: true }));
            return true;
            """
        )
        try expectTrue(script, message: "Could not fill nested frame selector \(selector).")
    }

    func selectInNestedFrame(selector: String, value: String) throws {
        let script = NativeScraperDefinitions.JavaScript.nestedFrameExpression(
            """
            const node = document.querySelector(\(quoted(selector)));
            if (!node) { return false; }
            node.value = \(quoted(value));
            node.dispatchEvent(new Event('change', { bubbles: true }));
            return true;
            """
        )
        try expectTrue(script, message: "Could not select nested frame selector \(selector).")
    }

    func clickTextInNestedFrame(_ text: String) throws {
        let script = NativeScraperDefinitions.JavaScript.nestedFrameExpression(
            """
            const wanted = \(quoted(text));
            const nodes = Array.from(document.querySelectorAll('*'));
            const match = nodes.find((node) => (node.textContent || '').trim() === wanted);
            if (!match) { return false; }
            match.click();
            return true;
            """
        )
        try expectTrue(script, message: "Could not click nested frame text \(text).")
    }

    func rowsMatrixInNestedFrame(selector: String) throws -> [[String]] {
        let script = NativeScraperDefinitions.JavaScript.nestedFrameExpression(
            """
            return Array.from(document.querySelectorAll(\(quoted(selector)))).map((row) =>
              Array.from(row.querySelectorAll('td')).map((cell) => (cell.innerText || '').trim())
            );
            """
        )
        guard let rows = try evaluate(script) as? [Any] else { return [] }
        return rows.compactMap { row in
            (row as? [Any])?.compactMap { $0 as? String }
        }
    }

    func roomNamesInNestedFrame(selector: String) throws -> [String] {
        let script = NativeScraperDefinitions.JavaScript.nestedFrameExpression(
            """
            return Array.from(document.querySelectorAll(\(quoted(selector)))).map((row) => {
              const cells = row.querySelectorAll('td');
              return cells.length > 1 ? (cells[1].innerText || '').trim() : '';
            }).filter(Boolean);
            """
        )
        return (try evaluate(script) as? [String]) ?? []
    }

    func titleAttributesInNestedFrame(selector: String) throws -> [String] {
        let script = NativeScraperDefinitions.JavaScript.nestedFrameExpression(
            """
            return Array.from(document.querySelectorAll(\(quoted(selector)))).map((node) => node.getAttribute('title') || '').filter(Boolean);
            """
        )
        return (try evaluate(script) as? [String]) ?? []
    }

    func nestedFrameValueOfSelector(_ selector: String) throws -> String? {
        let script = NativeScraperDefinitions.JavaScript.nestedFrameExpression(
            "return (document.querySelector(\(quoted(selector))) || {}).value ?? null;"
        )
        return try evaluate(script) as? String
    }

    func sleep(milliseconds: Int) {
        session.sleepForMilliseconds(milliseconds)
    }

    private func expectTrue(_ script: String, message: String) throws {
        let result = try evaluate(script)
        if let bool = result as? Bool, bool {
            return
        }

        if let number = result as? NSNumber, number.boolValue {
            return
        }

        throw NativeAutomationError.actionFailed(message)
    }

    private func quoted(_ string: String) -> String {
        let escaped = string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }
}
