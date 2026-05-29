import Foundation

// MARK: - Camelot Key

struct CamelotKey: Equatable, CustomStringConvertible {
    let number: Int   // 1–12
    let letter: String // "A" (minor) or "B" (major)

    var description: String { "\(number)\(letter)" }

    /// All keys directly compatible (same, ±1 number, same number different letter)
    func compatibleKeys() -> [CamelotKey] {
        var keys: [CamelotKey] = [self]
        // Adjacent numbers (wrap 12→1, 1→12)
        let prev = number == 1 ? 12 : number - 1
        let next = number == 12 ? 1 : number + 1
        keys.append(CamelotKey(number: prev, letter: letter))
        keys.append(CamelotKey(number: next, letter: letter))
        // Same number, relative major/minor
        let otherLetter = letter == "A" ? "B" : "A"
        keys.append(CamelotKey(number: number, letter: otherLetter))
        return keys
    }
}

// MARK: - Camelot Wheel

enum CamelotWheel {

    // MARK: - Mapping Table

    /// Returns the Camelot key for a Spotify key (0–11) + mode (0=minor, 1=major)
    static func camelotKey(spotifyKey: Int, mode: Int) -> CamelotKey? {
        guard spotifyKey >= 0, spotifyKey <= 11 else { return nil }
        let table: [Int: [Int: CamelotKey]] = [
            //       minor(0)                  major(1)
            0:  [0: CamelotKey(number: 5,  letter: "A"), 1: CamelotKey(number: 8,  letter: "B")],  // C
            1:  [0: CamelotKey(number: 12, letter: "A"), 1: CamelotKey(number: 3,  letter: "B")],  // C#/Db
            2:  [0: CamelotKey(number: 7,  letter: "A"), 1: CamelotKey(number: 10, letter: "B")],  // D
            3:  [0: CamelotKey(number: 2,  letter: "A"), 1: CamelotKey(number: 5,  letter: "B")],  // D#/Eb
            4:  [0: CamelotKey(number: 9,  letter: "A"), 1: CamelotKey(number: 12, letter: "B")],  // E
            5:  [0: CamelotKey(number: 4,  letter: "A"), 1: CamelotKey(number: 7,  letter: "B")],  // F
            6:  [0: CamelotKey(number: 11, letter: "A"), 1: CamelotKey(number: 2,  letter: "B")],  // F#/Gb
            7:  [0: CamelotKey(number: 6,  letter: "A"), 1: CamelotKey(number: 9,  letter: "B")],  // G
            8:  [0: CamelotKey(number: 1,  letter: "A"), 1: CamelotKey(number: 4,  letter: "B")],  // Ab/G#
            9:  [0: CamelotKey(number: 8,  letter: "A"), 1: CamelotKey(number: 11, letter: "B")],  // A
            10: [0: CamelotKey(number: 3,  letter: "A"), 1: CamelotKey(number: 6,  letter: "B")],  // Bb/A#
            11: [0: CamelotKey(number: 10, letter: "A"), 1: CamelotKey(number: 1,  letter: "B")],  // B
        ]
        return table[spotifyKey]?[mode]
    }

    // MARK: - Compatibility Scoring

    /// Returns a score 0–100 based on Camelot wheel proximity
    static func keyCompatibilityScore(from current: CamelotKey, to next: CamelotKey) -> Int {
        // Perfect match
        if current == next { return 100 }

        // Same letter, number distance
        if current.letter == next.letter {
            let distance = camelotDistance(current.number, next.number)
            switch distance {
            case 1: return 80  // adjacent, same letter (e.g. 8A→7A)
            case 2: return 40  // two steps
            default: return 0
            }
        }

        // Same number, different letter (relative major/minor)
        if current.number == next.number {
            return 70
        }

        // Different letter, different number
        let distance = camelotDistance(current.number, next.number)
        switch distance {
        case 1: return 30  // adjacent number, different letter
        case 2: return 10
        default: return 0
        }
    }

    /// Circular distance on the 12-position wheel
    private static func camelotDistance(_ a: Int, _ b: Int) -> Int {
        let diff = abs(a - b)
        return min(diff, 12 - diff)
    }

    // MARK: - Key Name

    static func keyName(spotifyKey: Int, mode: Int) -> String {
        let noteNames = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
        guard spotifyKey >= 0, spotifyKey < noteNames.count else { return "?" }
        let note = noteNames[spotifyKey]
        let modeName = mode == 1 ? "maj" : "min"
        return "\(note) \(modeName)"
    }
}
