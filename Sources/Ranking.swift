import Foundation

enum Ranking {
    static func order(parked: [Bool], mru: [Int], dwell: [TimeInterval]) -> [Int] {
        let n = parked.count
        return (0..<n).sorted { a, b in
            if parked[a] != parked[b] { return !parked[a] }
            if mru[a] != mru[b] { return mru[a] < mru[b] }
            return dwell[a] > dwell[b]
        }
    }

    static func runSelfCheck() {
        let parked = [false, true, false]
        let mru = [0, 1, 2]
        let dwell = [5.0, 0.0, 400.0]
        let got = order(parked: parked, mru: mru, dwell: dwell)
        guard got == [0, 2, 1] else {
            fputs("ranking self-check failed: \(got)\n", stderr)
            exit(1)
        }
        print("ok")
    }
}
