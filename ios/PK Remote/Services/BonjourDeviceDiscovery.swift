import Foundation
import Network

@MainActor
final class BonjourDeviceDiscovery: DeviceDiscovering {
    static let serviceType = "_androidtvremote2._tcp"

    private var browser: NWBrowser?
    private let queue: DispatchQueue

    init(queue: DispatchQueue = DispatchQueue(label: "com.pk.PK-Remote.discovery")) {
        self.queue = queue
    }

    func start(onUpdate: @escaping UpdateHandler) {
        stop()

        let browser = NWBrowser(
            for: .bonjour(type: Self.serviceType, domain: nil),
            using: .tcp
        )

        browser.browseResultsChangedHandler = { results, _ in
            Task { @MainActor in
                let devices = results.compactMap(Self.device(from:)).sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                onUpdate(.success(devices))
            }
        }

        browser.stateUpdateHandler = { state in
            switch state {
            case .failed(let error):
                onUpdate(.failure(error))
            case .cancelled:
                break
            default:
                break
            }
        }

        self.browser = browser
        browser.start(queue: queue)
    }

    func stop() {
        browser?.cancel()
        browser = nil
    }

    static func device(from result: NWBrowser.Result) -> RemoteDevice? {
        guard case let .service(name, type, domain, _) = result.endpoint else {
            return nil
        }

        return RemoteDevice(
            name: name,
            serviceType: type,
            serviceDomain: domain
        )
    }
}
