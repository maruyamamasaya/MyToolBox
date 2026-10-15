import XCTest
@testable import MonitorKit

final class SQLToolsTests: XCTestCase {
    func testFormatterPreservesQuotedContentAndComments() throws {
        let source = "select 'FROM; -- hello', \"order\", `where`, [select], $$WHERE ' x$$, X'CAFE' from users -- keep WHERE\nwhere id=1;"
        let output = try SQLText.format(source)
        for literal in ["'FROM; -- hello'", "\"order\"", "`where`", "[select]", "$$WHERE ' x$$", "X'CAFE'", "-- keep WHERE\n"] {
            XCTAssertTrue(output.contains(literal), output)
        }
        XCTAssertTrue(output.contains("\nFROM"))
        XCTAssertTrue(output.contains("\nWHERE"))
        XCTAssertTrue(try SQLText.format("SELECT 'UPPER' FROM t", uppercase: false).contains("select 'UPPER'\nfrom t"))
        XCTAssertEqual(try SQLText.format("select :where, @from, $select"), "SELECT :where,\n  @from,\n  $select")
        XCTAssertThrowsError(try SQLText.format("SELECT 'unfinished"))
        XCTAssertThrowsError(try SQLText.format("SELECT (1"))
        XCTAssertThrowsError(try SQLText.format("SELECT /* unfinished"))
    }
    func testExplanationDoesNotReadQuotedKeywordsAsClauses() throws {
        let sections = try SQLText.explain("SELECT name, 'FROM WHERE' AS label FROM users LEFT JOIN roles ON roles.id = users.role_id WHERE active=1 GROUP BY name HAVING count(*)>1 ORDER BY name LIMIT 5;")
        XCTAssertEqual(sections.map(\.title), ["SELECT", "FROM", "LEFT JOIN", "ON", "WHERE", "GROUP BY", "HAVING", "ORDER BY", "LIMIT"])
        XCTAssertTrue(sections[0].source.contains("'FROM WHERE'"))
        XCTAssertThrowsError(try SQLText.explain("DELETE FROM users"))
        XCTAssertThrowsError(try SQLText.explain("SELECT * FROM (SELECT * FROM users)"))
        XCTAssertThrowsError(try SQLText.explain("SELECT 1; SELECT 2"))
        XCTAssertThrowsError(try SQLText.explain("SELECT 1 UNION SELECT 2"))
    }
    func testRealSQLiteJoinAndNullsAndMultipleStatements() throws {
        let db = try SQLMemoryDatabase()
        let result = try XCTUnwrap(db.execute("CREATE TABLE notes (id INTEGER, value TEXT); INSERT INTO notes VALUES (1, 'a;''b'),(2,NULL); SELECT * FROM notes ORDER BY id;").last)
        XCTAssertEqual(result.columns, ["id", "value"])
        XCTAssertEqual(result.rows, [["1", "a;'b"], ["2", nil]])
        let join = try XCTUnwrap(db.execute("SELECT e.name FROM employees e JOIN projects p ON p.employee_id=e.id ORDER BY e.id;").first)
        XCTAssertEqual(join.rows, [["田中"], ["鈴木"]])
        XCTAssertEqual(try db.execute(SQLMemoryDatabase.sampleQuery).first?.rows.count, 2)
    }
    func testFailedBatchRollsBackAndExternalOperationsAreDenied() throws {
        let db = try SQLMemoryDatabase()
        XCTAssertThrowsError(try db.execute("INSERT INTO employees VALUES(99,'test','test',1,1); SELECT missing FROM employees;"))
        XCTAssertEqual(try db.execute("SELECT count(*) FROM employees WHERE id=99;").first?.rows, [["0"]])
        for query in ["ATTACH DATABASE ':memory:' AS extra", "PRAGMA journal_mode", "BEGIN", "SAVEPOINT test", "VACUUM INTO '/tmp/should-not-exist-mytoolbox.sqlite'", "SELECT load_extension('invalid')"] {
            XCTAssertThrowsError(try db.execute(query), query)
        }
        XCTAssertEqual(try db.execute("SELECT count(*) FROM employees;").first?.rows, [["4"]])
    }
    func testLimitsAndTimeoutLeaveDatabaseUsable() throws {
        let db = try SQLMemoryDatabase()
        let limited = try XCTUnwrap(db.execute("WITH RECURSIVE n(x) AS (VALUES(1) UNION ALL SELECT x+1 FROM n WHERE x<600) SELECT x FROM n;").first)
        XCTAssertEqual(limited.rows.count, 500)
        XCTAssertTrue(limited.truncated)
        XCTAssertThrowsError(try db.execute(String(repeating: "SELECT 1;", count: 21)))
        XCTAssertThrowsError(try db.execute("SELECT 1\0; SELECT 2"))
        XCTAssertThrowsError(try db.execute("INSERT INTO employees VALUES(99,'test','test',1,1); WITH RECURSIVE n(x) AS (VALUES(1) UNION ALL SELECT x+1 FROM n) SELECT sum(x) FROM n;", seconds: 0.01))
        XCTAssertEqual(try db.execute("SELECT count(*) FROM employees WHERE id=99;").first?.rows, [["0"]])
        XCTAssertEqual(try db.execute("SELECT 42;").first?.rows, [["42"]])
    }
    func testFormatPreservesExecutionForCommonQueries() throws {
        let db = try SQLMemoryDatabase()
        for sql in ["select name, salary*2 as doubled from employees where salary>=460000 order by id;", "select 'a; FROM', X'CAFE', 1.5e-2, (1+2)*3;", "select count(*) from employees -- note\nwhere active=1;"] {
            XCTAssertEqual(try db.execute(sql).first?.rows, try db.execute(SQLText.format(sql)).first?.rows)
        }
    }
}
