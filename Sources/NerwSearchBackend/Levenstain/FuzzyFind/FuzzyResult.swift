//
// Copyright [2021] Tomás Ruiz López Licensed under the Apache License, Version 2.0 (the «License»);
//

import Foundation

public struct FuzzyResult {
    public let segments: [FuzzyResultSegment]

    public var asString: String {
        return segments.map(\.asString).joined()
    }

    static func match(_ a: Character) -> FuzzyResult {
        return FuzzyResult(segments: [.match([a])])
    }

    static func gap(_ a: Character) -> FuzzyResult {
        return FuzzyResult(segments: [.gap([a])])
    }

    static func gaps(_ str: String) -> FuzzyResult {
        return FuzzyResult(
            segments: str.reversed().map { char in
                FuzzyResultSegment.gap([char])
            })
    }

    static let empty: FuzzyResult = FuzzyResult(segments: [])

    func reversed() -> FuzzyResult {
        return FuzzyResult(
            segments: self.segments.map { segment in
                segment.reversed()
            }.reversed())
    }

    func combine(_ other: FuzzyResult) -> FuzzyResult {
        if let last = self.segments.last, let first = other.segments.first {
            if last.isEmpty {
                return FuzzyResult(segments: self.segments.lead).combine(other)
            } else if first.isEmpty {
                return self.combine(FuzzyResult(segments: other.segments.tail))
            } else if case .gap(let l) = last, case .gap(let h) = first {
                return FuzzyResult(
                    segments: self.segments.lead + [.gap(l + h)] + other.segments.tail)
            } else if case .match(let l) = last, case .match(let h) = first {
                return FuzzyResult(
                    segments: self.segments.lead + [.match(l + h)] + other.segments.tail)
            } else {
                return FuzzyResult(segments: self.segments + other.segments)
            }
        } else {
            return self.isEmpty ? other : self
        }
    }

    func merge(_ other: FuzzyResult) -> FuzzyResult {
        if self.isEmpty { return other }
        if other.isEmpty { return self }
        guard let xs = self.segments.first, let ys = other.segments.first else {
            return self.isEmpty ? other : self
        }
        switch (xs, ys) {
        case (.gap(let g1), .gap(let g2)):
            if g1.count <= g2.count {
                return FuzzyResult(segments: [.gap(g1)]).combine(
                    self.tail.merge(other.drop(g1.count))
                )
            } else {
                return FuzzyResult(segments: [.gap(g2)]).combine(
                    self.drop(g2.count).merge(other.tail)
                )
            }
        case (.match(let m1), .match(let m2)):
            if m1.count >= m2.count {
                return FuzzyResult(segments: [.match(m1)]).combine(
                    self.tail.merge(other.drop(m1.count))
                )
            } else {
                return FuzzyResult(segments: [.match(m2)]).combine(
                    self.drop(m2.count).merge(other.tail)
                )
            }
        case (.gap(_), .match(let m)):
            return FuzzyResult(segments: [.match(m)]).combine(
                self.drop(m.count).merge(other.tail)
            )
        case (.match(let m), .gap(_)):
            return FuzzyResult(segments: [.match(m)]).combine(
                self.tail.merge(other.drop(m.count))
            )
        }
    }

    private func drop(_ n: Int) -> FuzzyResult {
        guard n >= 1 else { return self }
        if let first = self.segments.first {
            switch first {
            case .gap(let array):
                if n >= array.count {
                    return self.tail.drop(n - array.count)
                } else {
                    return FuzzyResult(segments: [.gap(array.drop(n))]).combine(self.tail)
                }
            case .match(let array):
                if n >= array.count {
                    return self.tail.drop(n - array.count)
                } else {
                    return FuzzyResult(segments: [.match(array.drop(n))]).combine(self.tail)
                }
            }
        } else {
            return .empty
        }
    }

    private var isEmpty: Bool {
        return segments.isEmpty
    }

    private var tail: FuzzyResult {
        return FuzzyResult(segments: self.segments.tail)
    }

    private var lead: FuzzyResult {
        return FuzzyResult(segments: self.segments.lead)
    }
}

extension FuzzyResult: Equatable {}

extension Array {
    fileprivate func drop(_ n: Int) -> Array {
        return Array(self.dropFirst(n))
    }

    fileprivate var tail: Array {
        if isEmpty { return [] }
        return Array(self.dropFirst())
    }

    fileprivate var lead: Array {
        if isEmpty { return [] }
        return Array(self.dropLast())
    }
}
