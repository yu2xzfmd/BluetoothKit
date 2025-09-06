import Combine
import Foundation

@MainActor
final class LogViewModel: ObservableObject {
    @Published var logs: [String] = []

    private let usecase: BLEUseCase
    private var bag = Set<AnyCancellable>()

    init(usecase: BLEUseCase) {
        self.usecase = usecase
        bind()
    }

    private func bind() {
        usecase.logsPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$logs)
    }

    // MARK: - Intents

    func writeDummy() {
        usecase.send(text: "Test")
    }

    func clear() {
        usecase.clearLogs()
    }
}
