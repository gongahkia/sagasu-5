import Foundation
import XCTest
@testable import SagasuShared

final class CredentialsStoreTests: XCTestCase {
    // MARK: - SharedCredentials model
    func testSharedCredentialsInitStoresValues() {
        let creds = SharedCredentials(email: "user@smu.edu.sg", password: "s3cret")
        XCTAssertEqual(creds.email, "user@smu.edu.sg")
        XCTAssertEqual(creds.password, "s3cret")
    }

    func testSharedCredentialsCodableRoundTrip() throws {
        let creds = SharedCredentials(email: "test@smu.edu.sg", password: "p@ss!")
        let data = try JSONEncoder().encode(creds)
        let decoded = try JSONDecoder().decode(SharedCredentials.self, from: data)
        XCTAssertEqual(decoded.email, creds.email)
        XCTAssertEqual(decoded.password, creds.password)
    }

    func testSharedCredentialsCodableProducesExpectedJSON() throws {
        let creds = SharedCredentials(email: "a@b.com", password: "pw")
        let data = try JSONEncoder().encode(creds)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["email"] as? String, "a@b.com")
        XCTAssertEqual(json?["password"] as? String, "pw")
    }

    func testSharedCredentialsDecodesFromJSON() throws {
        let jsonString = #"{"email":"x@y.com","password":"abc"}"#
        let data = Data(jsonString.utf8)
        let creds = try JSONDecoder().decode(SharedCredentials.self, from: data)
        XCTAssertEqual(creds.email, "x@y.com")
        XCTAssertEqual(creds.password, "abc")
    }

    func testSharedCredentialsMissingFieldThrows() {
        let jsonString = #"{"email":"x@y.com"}"#
        let data = Data(jsonString.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(SharedCredentials.self, from: data))
    }

    func testSharedCredentialsEmptyStrings() throws {
        let creds = SharedCredentials(email: "", password: "")
        let data = try JSONEncoder().encode(creds)
        let decoded = try JSONDecoder().decode(SharedCredentials.self, from: data)
        XCTAssertEqual(decoded.email, "")
        XCTAssertEqual(decoded.password, "")
    }

    func testSharedCredentialsSpecialCharacters() throws {
        let creds = SharedCredentials(email: "user+tag@smu.edu.sg", password: "p@$$w0rd!\"#%&")
        let data = try JSONEncoder().encode(creds)
        let decoded = try JSONDecoder().decode(SharedCredentials.self, from: data)
        XCTAssertEqual(decoded.email, creds.email)
        XCTAssertEqual(decoded.password, creds.password)
    }

    func testSharedCredentialsUnicodeCharacters() throws {
        let creds = SharedCredentials(email: "用户@smu.edu.sg", password: "密码🔑")
        let data = try JSONEncoder().encode(creds)
        let decoded = try JSONDecoder().decode(SharedCredentials.self, from: data)
        XCTAssertEqual(decoded.email, creds.email)
        XCTAssertEqual(decoded.password, creds.password)
    }
}
