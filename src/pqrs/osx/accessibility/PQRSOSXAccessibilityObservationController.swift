// (C) Copyright Takayama Fumihiko 2026.
// Distributed under the Boost Software License, Version 1.0.
// (See https://www.boost.org/LICENSE_1_0.txt)

import AppKit
import ApplicationServices

private let observedAccessibilityNotifications: [CFString] = [
  kAXFocusedUIElementChangedNotification as CFString,
  kAXFocusedWindowChangedNotification as CFString,
  kAXMainWindowChangedNotification as CFString,
  kAXWindowMovedNotification as CFString,
  kAXWindowResizedNotification as CFString,
]

private struct AccessibilityObserverRegistration {
  let observer: AXObserver
  var requestedTitleNotificationElements: [AXUIElement] = []
  var titleNotificationElements: [AXUIElement] = []
}

private func containsAXUIElement(_ elements: [AXUIElement], _ candidate: AXUIElement) -> Bool {
  elements.contains { CFEqual($0, candidate) }
}

private func containsSameAXUIElements(_ lhs: [AXUIElement], _ rhs: [AXUIElement]) -> Bool {
  lhs.count == rhs.count
    && lhs.allSatisfy { containsAXUIElement(rhs, $0) }
}

private let accessibilityObserverCallback: AXObserverCallback = { _, _, _, refcon in
  guard let refcon else {
    return
  }

  let callbackGeneration = Int(bitPattern: refcon)
  Task { @MainActor in
    PQRSOSXAccessibility.Monitor.shared.requestRefresh(
      force: false,
      callbackGeneration: callbackGeneration
    )
  }
}

extension PQRSOSXAccessibility {
  @MainActor
  final class ObservationController {
    private var activationObserver: NSObjectProtocol?
    private var terminationObserver: NSObjectProtocol?
    // PIDs that have been observed through NSWorkspace activation notifications.
    private var workspaceKnownPIDs: Set<pid_t> = []
    // PIDs discovered outside NSWorkspace that still need AXObserver-based tracking.
    private var observerManagedPIDs: Set<pid_t> = []
    private var observerRegistrationsByPID: [pid_t: AccessibilityObserverRegistration] = [:]
    // The current frontmost PID used to keep frontmost-app observation attached.
    private var frontmostProcessIdentifier: pid_t?
    private var frontmostTitleNotificationElements: [AXUIElement] = []
    private var callbackGeneration = 0

    func start(callbackGeneration: Int) {
      guard activationObserver == nil, terminationObserver == nil else {
        return
      }

      self.callbackGeneration = callbackGeneration

      activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
        forName: NSWorkspace.didActivateApplicationNotification,
        object: nil,
        queue: nil
      ) { [weak self] _ in
        guard let self else {
          return
        }

        Task { @MainActor in
          guard self.isCurrentCallbackGeneration(callbackGeneration) else {
            return
          }

          self.requestRefresh(callbackGeneration: callbackGeneration)
        }
      }

      terminationObserver = NSWorkspace.shared.notificationCenter.addObserver(
        forName: NSWorkspace.didTerminateApplicationNotification,
        object: nil,
        queue: nil
      ) { [weak self] notification in
        guard let self else {
          return
        }

        Task { @MainActor in
          guard self.isCurrentCallbackGeneration(callbackGeneration) else {
            return
          }

          let processIdentifier =
            (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?
            .processIdentifier

          self.pruneProcessIdentifier(processIdentifier)
          self.requestRefresh(callbackGeneration: callbackGeneration)
        }
      }

      requestRefresh(callbackGeneration: callbackGeneration)
    }

    func stop() {
      if let activationObserver {
        NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        self.activationObserver = nil
      }

      if let terminationObserver {
        NSWorkspace.shared.notificationCenter.removeObserver(terminationObserver)
        self.terminationObserver = nil
      }

      for processIdentifier in Array(observerRegistrationsByPID.keys) {
        detachObserver(processIdentifier: processIdentifier)
      }

      workspaceKnownPIDs.removeAll()
      observerManagedPIDs.removeAll()
      observerRegistrationsByPID.removeAll()
      frontmostProcessIdentifier = nil
      frontmostTitleNotificationElements.removeAll()
      callbackGeneration = 0
    }

    func registerProcessIdentifier(_ processIdentifier: pid_t?, detectionSource: DetectionSource) {
      guard let processIdentifier, processIdentifier != 0 else {
        return
      }

      switch detectionSource {
      case .workspace:
        workspaceKnownPIDs.insert(processIdentifier)
        observerManagedPIDs.remove(processIdentifier)

      case .axObserver:
        guard !workspaceKnownPIDs.contains(processIdentifier) else {
          return
        }

        observerManagedPIDs.insert(processIdentifier)

      case .none:
        break
      }
    }

    func pruneProcessIdentifier(_ processIdentifier: pid_t?) {
      guard let processIdentifier, processIdentifier != 0 else {
        return
      }

      workspaceKnownPIDs.remove(processIdentifier)
      observerManagedPIDs.remove(processIdentifier)

      if frontmostProcessIdentifier == processIdentifier {
        frontmostProcessIdentifier = nil
        frontmostTitleNotificationElements.removeAll()
      }

      detachObserver(processIdentifier: processIdentifier)
    }

    func pruneStaleProcessIdentifiers() {
      let knownProcessIdentifiers =
        workspaceKnownPIDs
        .union(observerManagedPIDs)
        .union(observerRegistrationsByPID.keys)

      for processIdentifier in knownProcessIdentifiers
      where NSRunningApplication(processIdentifier: processIdentifier) == nil {
        pruneProcessIdentifier(processIdentifier)
      }
    }

    private func requestRefresh(callbackGeneration: Int) {
      Task { @MainActor in
        PQRSOSXAccessibility.Monitor.shared.requestRefresh(
          force: false,
          callbackGeneration: callbackGeneration
        )
      }
    }

    private func isCurrentCallbackGeneration(_ callbackGeneration: Int) -> Bool {
      self.callbackGeneration == callbackGeneration
    }

    func syncObservers(
      frontmostProcessIdentifier: pid_t?,
      titleNotificationElements: [AXUIElement]
    ) {
      self.frontmostProcessIdentifier = frontmostProcessIdentifier
      frontmostTitleNotificationElements = titleNotificationElements

      var targetPIDs = observerManagedPIDs.subtracting(workspaceKnownPIDs)

      if let frontmostProcessIdentifier, frontmostProcessIdentifier != 0 {
        targetPIDs.insert(frontmostProcessIdentifier)
      }

      let stalePIDs = Set(observerRegistrationsByPID.keys).subtracting(targetPIDs)
      for processIdentifier in stalePIDs {
        detachObserver(processIdentifier: processIdentifier)
      }

      for processIdentifier in targetPIDs {
        attachObserver(processIdentifier: processIdentifier)
      }

      for processIdentifier in Array(observerRegistrationsByPID.keys) {
        syncTitleNotifications(
          processIdentifier: processIdentifier,
          elements: processIdentifier == frontmostProcessIdentifier
            ? titleNotificationElements : []
        )
      }
    }

    func windowTitleNeedsRefresh(currentWindowTitle: String?) -> Bool {
      guard !frontmostTitleNotificationElements.isEmpty else {
        return false
      }

      if let frontmostProcessIdentifier,
        let registration = observerRegistrationsByPID[frontmostProcessIdentifier],
        containsSameAXUIElements(
          registration.requestedTitleNotificationElements,
          registration.titleNotificationElements
        )
      {
        return false
      }

      var didReadTitle = false
      var latestWindowTitle: String?
      for element in frontmostTitleNotificationElements {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(
          element,
          kAXTitleAttribute as CFString,
          &value
        )
        guard error == .success else {
          continue
        }

        didReadTitle = true
        if let title = value as? String, !title.isEmpty {
          latestWindowTitle = title
          break
        }
      }

      // A transient AX failure is not evidence that the title was cleared.
      guard didReadTitle else {
        return false
      }

      return latestWindowTitle != currentWindowTitle
    }

    private func attachObserver(processIdentifier: pid_t) {
      guard processIdentifier != 0 else {
        return
      }

      guard observerRegistrationsByPID[processIdentifier] == nil else {
        return
      }

      var observer: AXObserver?
      let error = AXObserverCreate(processIdentifier, accessibilityObserverCallback, &observer)
      guard error == .success, let observer else {
        return
      }

      let applicationElement = AXUIElementCreateApplication(processIdentifier)
      var registered = false

      for notification in observedAccessibilityNotifications {
        let error = AXObserverAddNotification(
          observer,
          applicationElement,
          notification,
          UnsafeMutableRawPointer(bitPattern: callbackGeneration)
        )
        if error == .success {
          registered = true
        }
      }

      guard registered else {
        return
      }

      CFRunLoopAddSource(
        CFRunLoopGetMain(),
        AXObserverGetRunLoopSource(observer),
        .commonModes
      )

      observerRegistrationsByPID[processIdentifier] = AccessibilityObserverRegistration(
        observer: observer
      )
    }

    private func syncTitleNotifications(processIdentifier: pid_t, elements: [AXUIElement]) {
      guard var registration = observerRegistrationsByPID[processIdentifier] else {
        return
      }

      // Registration errors are generally a capability limitation of the target
      // application. Avoid retrying the same failed registrations on every
      // snapshot; lightweight title polling covers them instead.
      guard
        !containsSameAXUIElements(
          registration.requestedTitleNotificationElements,
          elements
        )
      else {
        return
      }

      for element in registration.titleNotificationElements
      where !containsAXUIElement(elements, element) {
        AXObserverRemoveNotification(
          registration.observer,
          element,
          kAXTitleChangedNotification as CFString
        )
      }

      var registeredElements = registration.titleNotificationElements.filter {
        containsAXUIElement(elements, $0)
      }

      for element in elements where !containsAXUIElement(registeredElements, element) {
        let error = AXObserverAddNotification(
          registration.observer,
          element,
          kAXTitleChangedNotification as CFString,
          UnsafeMutableRawPointer(bitPattern: callbackGeneration)
        )
        if error == .success || error == .notificationAlreadyRegistered {
          registeredElements.append(element)
        }
      }

      registration.requestedTitleNotificationElements = elements
      registration.titleNotificationElements = registeredElements
      observerRegistrationsByPID[processIdentifier] = registration
    }

    private func detachObserver(processIdentifier: pid_t) {
      if let registration = observerRegistrationsByPID.removeValue(forKey: processIdentifier) {
        CFRunLoopRemoveSource(
          CFRunLoopGetMain(),
          AXObserverGetRunLoopSource(registration.observer),
          .commonModes
        )
      }
    }
  }
}
