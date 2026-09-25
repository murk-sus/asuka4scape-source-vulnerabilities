import Foundation
import Network

final class LocalNetworkAuthorization: @unchecked Sendable {
    private var browser: NWBrowser?
    private var listener: NWListener?
    private var continuation: CheckedContinuation<Bool, Never>?

    private let probeType = "_aircardprobe._tcp"

    func request(timeout: TimeInterval = 1.5) async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            self.continuation = cont

            let params = NWParameters.tcp
            params.includePeerToPeer = true

            let listener = try? NWListener(using: params)
            listener?.service = NWListener.Service(name: "natsuk1Probe", type: probeType)
            listener?.newConnectionHandler = { $0.cancel() }
            listener?.stateUpdateHandler = { [weak self] state in
                if case .failed = state {
                    DispatchQueue.main.async { self?.finish(true) }
                }
            }
            self.listener = listener

            let browser = NWBrowser(for: .bonjour(type: probeType, domain: nil), using: params)
            browser.stateUpdateHandler = { [weak self] state in
                if case .failed = state {
                    DispatchQueue.main.async { self?.finish(true) }
                }
            }
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                if !results.isEmpty {
                    DispatchQueue.main.async { self?.finish(true) }
                }
            }
            self.browser = browser

            listener?.start(queue: .main)
            browser.start(queue: .main)

            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                self?.finish(true)
            }
        }
    }

    private func finish(_ authorized: Bool) {
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume(returning: authorized)
        browser?.cancel(); browser = nil
        listener?.cancel(); listener = nil
    }
}
