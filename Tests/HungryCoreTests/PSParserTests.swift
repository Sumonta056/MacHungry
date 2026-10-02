import Testing
@testable import HungryCore

struct PSParserTests {
    @Test(arguments: [
        ("0:05.04", 5.04),
        ("34:42.90", 2_082.90),
        ("2072:15.03", 124_335.03),
        ("1:02:03.50", 3_723.50),
        ("2-01:00:00.00", 176_400.0),
    ])
    func parsesTimeFormats(text: String, expected: Double) throws {
        let seconds = try #require(PSParser.parseTime(Substring(text)))
        #expect(abs(seconds - expected) < 0.000_1)
    }

    @Test(arguments: ["", "abc", "1:2:3:4", "5", "-1:00.00", "x-1:00.00", "1:inf", "1::00"])
    func rejectsMalformedTime(text: String) {
        #expect(PSParser.parseTime(Substring(text)) == nil)
    }

    @Test func parsesLineWithLeadingSpacesAndPathWithSpaces() throws {
        let sample = try #require(PSParser.parseLine("  412   1:30.00 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome"))
        #expect(sample == ProcessSample(pid: 412, cpuSeconds: 90, path: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"))
    }

    @Test(arguments: ["", "   ", "abc 0:01.00 /bin/x", "12 bad /bin/x", "12 0:01.00", "12 0:01.00   "])
    func rejectsMalformedLine(line: String) {
        #expect(PSParser.parseLine(Substring(line)) == nil)
    }

    @Test func parseSkipsBadLinesAndKeepsGoodLines() {
        let output = """
            1  34:42.90 /sbin/launchd
        garbage line
          287   0:05.04 /usr/libexec/textunderstandingd

        """
        let samples = PSParser.parse(output)
        #expect(samples.map(\.pid) == [1, 287])
    }
}
