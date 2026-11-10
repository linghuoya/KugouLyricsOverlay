import Foundation

struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw TestFailure(description: message) }
}

func expectTrue(_ value: Bool) throws {
    try expect(value, "Expected true")
}

func expectFalse(_ value: Bool) throws {
    try expect(!value, "Expected false")
}

func expectNil(_ value: Any?) throws {
    try expect(value == nil, "Expected nil, got \(String(describing: value))")
}

func expectEqual<T: Equatable>(_ actual: @autoclosure () throws -> T, _ expected: @autoclosure () throws -> T) throws {
    let actualValue = try actual()
    let expectedValue = try expected()
    guard actualValue == expectedValue else {
        throw TestFailure(description: "Expected \(expectedValue), got \(actualValue)")
    }
}

func expectEqual(_ actual: Double?, _ expected: Double, accuracy: Double) throws {
    guard let actual else { throw TestFailure(description: "Expected \(expected), got nil") }
    guard abs(actual - expected) <= accuracy else {
        throw TestFailure(description: "Expected \(expected) ± \(accuracy), got \(actual)")
    }
}

func expectGreaterThan<T: Comparable>(_ actual: T, _ lowerBound: T) throws {
    try expect(actual > lowerBound, "Expected \(actual) > \(lowerBound)")
}

func expectLessThanOrEqual<T: Comparable>(_ actual: T, _ upperBound: T) throws {
    try expect(actual <= upperBound, "Expected \(actual) <= \(upperBound)")
}

func expectThrows(_ body: () throws -> Void, verify: (Error) throws -> Void) throws {
    do {
        try body()
        throw TestFailure(description: "Expected an error")
    } catch let failure as TestFailure {
        throw failure
    } catch {
        try verify(error)
    }
}
