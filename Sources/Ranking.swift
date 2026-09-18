import Foundation

enum Ranking {
    static func order(parked: [Bool], local: [Bool], mru: [Int], dwell: [TimeInterval]) -> [Int] {
        let n = parked.count
        return (0..<n).sorted { a, b in
            if parked[a] != parked[b] { return !parked[a] }
            if local[a] != local[b] { return local[a] }
            if mru[a] != mru[b] { return mru[a] < mru[b] }
            return dwell[a] > dwell[b]
        }
    }

    static func runSelfCheck() {
        let parked = [false, true, false]
        let local = [true, true, true]
        let mru = [0, 1, 2]
        let dwell = [5.0, 0.0, 400.0]
        let got = order(parked: parked, local: local, mru: mru, dwell: dwell)
        guard got == [0, 2, 1] else {
            fputs("ranking self-check failed: \(got)\n", stderr)
            exit(1)
        }
        let screens = order(
            parked: [false, false, false],
            local: [true, false, true],
            mru: [0, 1, 2],
            dwell: [0, 0, 0]
        )
        guard screens == [0, 2, 1] else {
            fputs("ranking screen self-check failed: \(screens)\n", stderr)
            exit(1)
        }
        print("ok")
    }
}
