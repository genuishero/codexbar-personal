#!/usr/bin/env swift

import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

let label = ProcessInfo.processInfo.environment["HIDE_MY_EMAIL_LABEL"] ?? "Codex"
let bundleID = "com.apple.systempreferences"
let iCloudURL = "x-apple.systempreferences:com.apple.systempreferences.AppleIDSettings:icloud"
let iCloudWindowTitle = "iCloud"

let hideMyEmailDescriptions = ["隐藏邮件地址", "Hide My Email"]
let createButtonTitles = ["创建新地址", "Create New Address"]
let continueButtonTitles = ["继续", "Continue"]
let doneButtonTitles = ["完成", "Done"]
let launchTimeout: TimeInterval = 20
let transitionTimeout: TimeInterval = 20
let transitionAttempts = 3

func fail(_ message: String) -> Never {
    fputs("\(message)\n", stderr)
    exit(1)
}

func attr(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
        return nil
    }
    return value
}

func strAttr(_ element: AXUIElement, _ name: String) -> String? {
    attr(element, name) as? String
}

func children(of element: AXUIElement) -> [AXUIElement] {
    attr(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
}

func systemSettingsApp() -> NSRunningApplication? {
    NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
}

func systemSettingsElement() -> AXUIElement? {
    guard let app = systemSettingsApp() else {
        return nil
    }
    return AXUIElementCreateApplication(app.processIdentifier)
}

func iCloudWindow() -> AXUIElement? {
    guard let appElement = systemSettingsElement() else {
        return nil
    }

    let windows = attr(appElement, kAXWindowsAttribute) as? [AXUIElement] ?? []
    return windows.first { strAttr($0, kAXTitleAttribute) == iCloudWindowTitle }
}

func anySystemSettingsWindow() -> AXUIElement? {
    guard let appElement = systemSettingsElement() else {
        return nil
    }

    let windows = attr(appElement, kAXWindowsAttribute) as? [AXUIElement] ?? []
    return windows.first
}

@discardableResult
func waitUntil(timeout: TimeInterval = 15, interval: TimeInterval = 0.2, _ condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() {
            return true
        }
        RunLoop.current.run(until: Date().addingTimeInterval(interval))
    }
    return false
}

func activateSystemSettings() {
    guard let app = systemSettingsApp() else {
        return
    }
    _ = app.activate(options: [.activateAllWindows])
}

func ensureSystemSettingsWindow() {
    if anySystemSettingsWindow() != nil {
        activateSystemSettings()
        return
    }

    guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
        fail("failed to resolve System Settings.app")
    }

    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true

    var launchError: Error?
    let semaphore = DispatchSemaphore(value: 0)
    NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
        launchError = error
        semaphore.signal()
    }
    semaphore.wait()

    if let launchError {
        fail("failed to launch System Settings: \(launchError.localizedDescription)")
    }

    guard waitUntil(timeout: launchTimeout, {
        activateSystemSettings()
        return anySystemSettingsWindow() != nil
    }) else {
        fail("timed out waiting for a System Settings window")
    }
}

func ensureICloudPane() {
    ensureSystemSettingsWindow()

    if iCloudWindow() != nil {
        activateSystemSettings()
        return
    }

    guard let url = URL(string: iCloudURL) else {
        fail("invalid iCloud URL: \(iCloudURL)")
    }
    guard NSWorkspace.shared.open(url) else {
        fail("failed to open iCloud settings via URL")
    }

    guard waitUntil(timeout: launchTimeout, {
        activateSystemSettings()
        return iCloudWindow() != nil
    }) else {
        fail("timed out waiting for System Settings iCloud window")
    }
}

func findButton(
    in element: AXUIElement,
    titles: [String] = [],
    descriptions: [String] = []
) -> AXUIElement? {
    if (strAttr(element, kAXRoleAttribute) ?? "") == (kAXButtonRole as String) {
        let title = strAttr(element, kAXTitleAttribute) ?? ""
        let description = strAttr(element, kAXDescriptionAttribute) ?? ""

        if titles.contains(where: { !title.isEmpty && title.contains($0) }) {
            return element
        }

        if descriptions.contains(where: { !description.isEmpty && description.contains($0) }) {
            return element
        }
    }

    for child in children(of: element) {
        if let found = findButton(in: child, titles: titles, descriptions: descriptions) {
            return found
        }
    }

    return nil
}

func findSheetContainingButton(in element: AXUIElement, titles: [String]) -> AXUIElement? {
    for child in children(of: element) {
        if let found = findSheetContainingButton(in: child, titles: titles) {
            return found
        }
    }

    guard (strAttr(element, kAXRoleAttribute) ?? "") == (kAXSheetRole as String) else {
        return nil
    }

    return findButton(in: element, titles: titles) != nil ? element : nil
}

func findEmailText(in element: AXUIElement) -> String? {
    let value = strAttr(element, kAXValueAttribute) ?? ""
    if value.contains("@icloud.com") {
        return value
    }

    for child in children(of: element) {
        if let found = findEmailText(in: child) {
            return found
        }
    }

    return nil
}

func findTextField(in element: AXUIElement) -> AXUIElement? {
    if (strAttr(element, kAXRoleAttribute) ?? "") == (kAXTextFieldRole as String) {
        return element
    }

    for child in children(of: element) {
        if let found = findTextField(in: child) {
            return found
        }
    }

    return nil
}

func hasProgressIndicator(in element: AXUIElement) -> Bool {
    if (strAttr(element, kAXRoleAttribute) ?? "") == (kAXProgressIndicatorRole as String) {
        return true
    }

    for child in children(of: element) {
        if hasProgressIndicator(in: child) {
            return true
        }
    }

    return false
}

func press(_ element: AXUIElement, context: String) {
    let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
    guard result == .success else {
        fail("AXPress failed for \(context): \(result.rawValue)")
    }
}

func setText(_ value: String, in element: AXUIElement, context: String) {
    let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, value as CFTypeRef)
    guard result == .success else {
        fail("failed to set \(context): \(result.rawValue)")
    }
}

func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags = []) {
    let source = CGEventSource(stateID: .hidSystemState)

    guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
          let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
        fail("failed to post key event for keyCode \(keyCode)")
    }

    keyDown.flags = flags
    keyDown.post(tap: .cghidEventTap)

    keyUp.flags = flags
    keyUp.post(tap: .cghidEventTap)
}

func typeUnicode(_ text: String) {
    let source = CGEventSource(stateID: .hidSystemState)

    for scalar in text.utf16 {
        var value = scalar

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
            fail("failed to post Unicode key events")
        }

        keyDown.keyboardSetUnicodeString(stringLength: 1, unicodeString: &value)
        keyDown.post(tap: .cghidEventTap)

        keyUp.keyboardSetUnicodeString(stringLength: 1, unicodeString: &value)
        keyUp.post(tap: .cghidEventTap)
    }
}

func fillTextField(_ value: String, in element: AXUIElement, context: String) {
    setText(value, in: element, context: context)
    if (strAttr(element, kAXValueAttribute) ?? "") == value {
        return
    }

    let focusResult = AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    guard focusResult == .success else {
        fail("failed to focus \(context): \(focusResult.rawValue)")
    }

    RunLoop.current.run(until: Date().addingTimeInterval(0.2))
    postKey(0, flags: .maskCommand)
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    postKey(51)
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    typeUnicode(value)

    guard waitUntil(timeout: 2, {
        (strAttr(element, kAXValueAttribute) ?? "") == value
    }) else {
        fail("typed \(context) but did not observe the expected value")
    }
}

func waitForICloudState(
    timeout: TimeInterval = transitionTimeout,
    ready: @escaping (AXUIElement) -> Bool
) -> AXUIElement? {
    var matchedWindow: AXUIElement?
    let succeeded = waitUntil(timeout: timeout) {
        guard let refreshed = iCloudWindow() else {
            return false
        }
        activateSystemSettings()

        if ready(refreshed) {
            matchedWindow = refreshed
            return true
        }

        _ = hasProgressIndicator(in: refreshed)
        return false
    }

    return succeeded ? matchedWindow : nil
}

func ensureHideMyEmailManager(startingFrom window: AXUIElement) -> AXUIElement {
    if let readyWindow = waitForICloudState(timeout: 1, ready: { refreshed in
        findButton(in: refreshed, titles: createButtonTitles) != nil ||
        findSheetContainingButton(in: refreshed, titles: continueButtonTitles) != nil
    }) {
        return readyWindow
    }

    var currentWindow = window

    for attempt in 1...transitionAttempts {
        guard let hideButton = findButton(in: currentWindow, descriptions: hideMyEmailDescriptions) else {
            fail("failed to find Hide My Email entry in iCloud pane")
        }
        press(hideButton, context: "Hide My Email entry (attempt \(attempt))")

        if let readyWindow = waitForICloudState(ready: { refreshed in
            findButton(in: refreshed, titles: createButtonTitles) != nil ||
            findSheetContainingButton(in: refreshed, titles: continueButtonTitles) != nil
        }) {
            return readyWindow
        }

        guard let refreshed = iCloudWindow() else {
            break
        }
        currentWindow = refreshed
    }

    fail("timed out waiting for Hide My Email manager after \(transitionAttempts) attempts")
}

func ensureCreateSheet(startingFrom window: AXUIElement) -> AXUIElement {
    if let readyWindow = waitForICloudState(timeout: 1, ready: { refreshed in
        findSheetContainingButton(in: refreshed, titles: continueButtonTitles) != nil
    }) {
        return readyWindow
    }

    var currentWindow = window

    for attempt in 1...transitionAttempts {
        guard let createButton = findButton(in: currentWindow, titles: createButtonTitles) else {
            fail("failed to find create-address button")
        }
        press(createButton, context: "Create new Hide My Email address (attempt \(attempt))")

        if let readyWindow = waitForICloudState(ready: { refreshed in
            findSheetContainingButton(in: refreshed, titles: continueButtonTitles) != nil
        }) {
            return readyWindow
        }

        guard let refreshed = iCloudWindow() else {
            break
        }
        currentWindow = refreshed
    }

    fail("timed out waiting for create-address sheet after \(transitionAttempts) attempts")
}

ensureICloudPane()
activateSystemSettings()

guard let initialWindow = iCloudWindow() else {
    fail("missing iCloud window after opening pane")
}

let managerWindow = ensureHideMyEmailManager(startingFrom: initialWindow)
let createSheetWindow = ensureCreateSheet(startingFrom: managerWindow)

guard let createSheet = findSheetContainingButton(in: createSheetWindow, titles: continueButtonTitles) else {
    fail("failed to locate create-address sheet")
}

guard let relayEmail = findEmailText(in: createSheet) else {
    fail("failed to read the newly generated Hide My Email relay address")
}

guard let labelField = findTextField(in: createSheet) else {
    fail("failed to locate the Hide My Email label field")
}
fillTextField(label, in: labelField, context: "Hide My Email label")

var completedWindow: AXUIElement?
for attempt in 1...transitionAttempts {
    guard let refreshedWindow = iCloudWindow(),
          let refreshedCreateSheet = findSheetContainingButton(in: refreshedWindow, titles: continueButtonTitles),
          let continueButton = findButton(in: refreshedCreateSheet, titles: continueButtonTitles) else {
        fail("failed to locate the create-address continue button")
    }

    press(continueButton, context: "Create-address continue button (attempt \(attempt))")

    if let closedWindow = waitForICloudState(ready: { refreshed in
        findSheetContainingButton(in: refreshed, titles: continueButtonTitles) == nil
    }) {
        completedWindow = closedWindow
        break
    }
}

guard let completedWindow else {
    fail("timed out waiting for create-address sheet to close")
}

if let doneButton = findButton(in: completedWindow, titles: doneButtonTitles) {
    press(doneButton, context: "Hide My Email done button")
}

print(relayEmail)
