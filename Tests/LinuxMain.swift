import XCTest
@testable import CursorPaginationTests

XCTMain([
	testCase(CursorPaginationTests.allTests),
	testCase(CursorPaginationRequestTests.allTests)
])

