import Foundation

enum Ranking {
    static func order(
        frontmost: [Bool],
        parked: [Bool],
        local: [Bool],
        dest: [Bool],
        mru: [Int],
        dwell: [TimeInterval]
    ) -> [Int] {
        let n = parked.count
        return (0..<n).sorted { a, b in
            if frontmost[a] != frontmost[b] { return frontmost[a] }
            if dest[a] != dest[b] { return dest[a] }
            if parked[a] != parked[b] { return !parked[a] }
            if local[a] != local[b] { return local[a] }
            if mru[a] != mru[b] { return mru[a] < mru[b] }
            return dwell[a] > dwell[b]
        }
    }

    static func runSelfCheck() {
        let none = [false, false, false]
        let parked = [false, true, false]
        let local = [true, true, true]
        let mru = [0, 1, 2]
        let dwell = [5.0, 0.0, 400.0]
        let got = order(
            frontmost: none,
            parked: parked,
            local: local,
            dest: none,
            mru: mru,
            dwell: dwell
        )
        guard got == [0, 2, 1] else {
            fputs("ranking self-check failed: \(got)\n", stderr)
            exit(1)
        }
        let screens = order(
            frontmost: none,
            parked: none,
            local: [true, false, true],
            dest: none,
            mru: mru,
            dwell: [0, 0, 0]
        )
        guard screens == [0, 2, 1] else {
            fputs("ranking screen self-check failed: \(screens)\n", stderr)
            exit(1)
        }
        let dest = order(
            frontmost: [true, false, false],
            parked: [false, false, true],
            local: [true, true, true],
            dest: [false, false, true],
            mru: mru,
            dwell: [0, 0, 0]
        )
        guard dest == [0, 2, 1] else {
            fputs("ranking dest self-check failed: \(dest)\n", stderr)
            exit(1)
        }
        print("ok")
    }
}
