@import XCTest;
@import integration_test;

@interface RunnerTests : XCTestCase
@end

@implementation RunnerTests

- (void)testGuestNative {
  // Read the Dart result in the host app, without waiting for the Flutter CLI
  // to discover the simulator's debug VM service.
  IntegrationTestPlugin *bridge = [IntegrationTestPlugin instance];
  NSTimeInterval deadline = NSProcessInfo.processInfo.systemUptime + 180;
  while (bridge.testResults == nil && NSProcessInfo.processInfo.systemUptime < deadline) {
    [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
  }

  NSDictionary<NSString *, NSString *> *results = bridge.testResults;
  XCTAssertNotNil(results, @"Timed out waiting for the Dart T40/T41 result.");
  if (results == nil) {
    return;
  }
  XCTAssertEqual(results.count, 1, @"Expected exactly one native guest scenario.");
  NSString *result = results[@"T40/T41: fresh native install enters and then resumes guest"];
  // Do not echo a raw Dart failure payload into CI.
  XCTAssertTrue([result isEqualToString:@"success"], @"Dart T40/T41 did not pass.");
}

@end
