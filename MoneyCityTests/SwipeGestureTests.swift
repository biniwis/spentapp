import XCTest
@testable import MoneyCity

final class SwipeGestureTests: XCTestCase {

    func testUnderMinimumThresholdIsUndecided() {
        XCTAssertEqual(SwipeGestureClassifier.classify(deltaX: 0, deltaY: 0), .undecided)
        XCTAssertEqual(SwipeGestureClassifier.classify(deltaX: 10, deltaY: 5), .undecided)
        XCTAssertEqual(SwipeGestureClassifier.classify(deltaX: -12, deltaY: -15), .undecided)
        XCTAssertEqual(SwipeGestureClassifier.classify(deltaX: 17, deltaY: 17), .undecided)
    }

    func testPureVerticalScrollIsClassifiedAsVertical() {
        XCTAssertEqual(SwipeGestureClassifier.classify(deltaX: 0, deltaY: 25), .vertical)
        XCTAssertEqual(SwipeGestureClassifier.classify(deltaX: 0, deltaY: -50), .vertical)
        XCTAssertEqual(SwipeGestureClassifier.classify(deltaX: 4, deltaY: 60), .vertical)
    }

    func testPureHorizontalSwipeIsClassifiedAsHorizontal() {
        XCTAssertEqual(SwipeGestureClassifier.classify(deltaX: 30, deltaY: 0), .horizontal)
        XCTAssertEqual(SwipeGestureClassifier.classify(deltaX: -45, deltaY: 0), .horizontal)
        XCTAssertEqual(SwipeGestureClassifier.classify(deltaX: 50, deltaY: 5), .horizontal)
    }

    func testDiagonalMovementsFavorVerticalScrolling() {
        // Natural thumb angle scrolling has slight horizontal jitter:
        // E.g. dx: 20, dy: 35 -> clearly vertical
        XCTAssertEqual(SwipeGestureClassifier.classify(deltaX: 20, deltaY: 35), .vertical)

        // Borderline diagonal: dx: 30, dy: 26 -> dx is only 1.15x dy (< 1.25x ratio)
        // Must favor vertical scrolling for history reading!
        XCTAssertEqual(SwipeGestureClassifier.classify(deltaX: 30, deltaY: 26), .vertical)

        // Intentional swipe: dx: 45, dy: 20 -> 45 > 20 * 1.25 = 25 -> horizontal
        XCTAssertEqual(SwipeGestureClassifier.classify(deltaX: 45, deltaY: 20), .horizontal)

        // Negative directions (RTL / LTR swipes)
        XCTAssertEqual(SwipeGestureClassifier.classify(deltaX: -50, deltaY: 15), .horizontal)
        XCTAssertEqual(SwipeGestureClassifier.classify(deltaX: -20, deltaY: -40), .vertical)
    }

    func testDominanceBoundaryCondition() {
        // Exactly at ratio 1.25 (e.g. dx: 25, dy: 20) -> absX is not strictly greater than absY * 1.25 -> vertical
        XCTAssertEqual(SwipeGestureClassifier.classify(deltaX: 25, deltaY: 20), .vertical)

        // Just above ratio 1.25 (e.g. dx: 26, dy: 20) -> strictly greater -> horizontal
        XCTAssertEqual(SwipeGestureClassifier.classify(deltaX: 26, deltaY: 20), .horizontal)

        // Below ratio 1.25 (e.g. dx: 24, dy: 20) -> vertical
        XCTAssertEqual(SwipeGestureClassifier.classify(deltaX: 24, deltaY: 20), .vertical)
    }

    func testConstantThresholdValues() {
        XCTAssertEqual(SwipeGestureClassifier.minimumThreshold, 18.0)
        XCTAssertEqual(SwipeGestureClassifier.horizontalDominanceRatio, 1.25)
    }
}

