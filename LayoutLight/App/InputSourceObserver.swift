import Carbon
import Foundation

final class InputSourceObserver: NSObject {
    var onInputSourceChanged: (() -> Void)?

    private var pollTimer: Timer?
    private var lastInputSourceID: String?

    func start() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourceChangedNotification),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourceChangedNotification),
            name: NSNotification.Name("AppleSelectedInputSourcesChangedNotification"),
            object: nil
        )

        lastInputSourceID = currentInputSourceID()
        startPolling()
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func inputSourceChangedNotification(_ notification: Notification) {
        handleInputSourceChangeIfNeeded(force: true)
    }

    private func startPolling() {
        pollTimer?.invalidate()
        let t = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.handleInputSourceChangeIfNeeded(force: false)
        }
        RunLoop.main.add(t, forMode: .common)
        pollTimer = t
    }

    private func handleInputSourceChangeIfNeeded(force: Bool) {
        let sourceID = currentInputSourceID()
        if !force, sourceID == lastInputSourceID {
            return
        }
        lastInputSourceID = sourceID
        onInputSourceChanged?()
    }

    private func currentInputSourceID() -> String? {
        InputSourceLanguage.currentInputSourceID()
    }
}
