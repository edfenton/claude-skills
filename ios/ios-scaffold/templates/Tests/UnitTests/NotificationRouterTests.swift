@testable import AppName
import Testing

struct NotificationPayloadTests {
  // MARK: - Valid Payloads

  @Test func validType_succeeds() {
    // Given
    let userInfo: [AnyHashable: Any] = ["type": "newItem"]

    // When
    let payload = NotificationPayload(userInfo: userInfo)

    // Then
    #expect(payload != nil)
    #expect(payload?.type == .newItem)
    #expect(payload?.targetId == nil)
  }

  @Test func typeAndTargetId_succeeds() {
    // Given
    let userInfo: [AnyHashable: Any] = [
      "type": "newItem",
      "targetId": "abc-123"
    ]

    // When
    let payload = NotificationPayload(userInfo: userInfo)

    // Then
    #expect(payload != nil)
    #expect(payload?.type == .newItem)
    #expect(payload?.targetId == "abc-123")
  }

  @Test(arguments: ["newItem", "reminder", "update"])
  func allPayloadTypes_succeed(typeString: String) {
    let userInfo: [AnyHashable: Any] = ["type": typeString]
    let payload = NotificationPayload(userInfo: userInfo)
    #expect(payload != nil, "Failed for type: \(typeString)")
  }

  // MARK: - Invalid Payloads

  @Test func missingType_returnsNil() {
    // Given
    let userInfo: [AnyHashable: Any] = ["targetId": "123"]

    // When
    let payload = NotificationPayload(userInfo: userInfo)

    // Then
    #expect(payload == nil)
  }

  @Test func invalidType_returnsNil() {
    // Given
    let userInfo: [AnyHashable: Any] = ["type": "unknownType"]

    // When
    let payload = NotificationPayload(userInfo: userInfo)

    // Then
    #expect(payload == nil)
  }

  @Test func emptyUserInfo_returnsNil() {
    // Given
    let userInfo: [AnyHashable: Any] = [:]

    // When
    let payload = NotificationPayload(userInfo: userInfo)

    // Then
    #expect(payload == nil)
  }

  // MARK: - Target ID Validation

  @Test func invalidTargetId_stripsTargetId() {
    // Given - targetId with invalid characters
    let userInfo: [AnyHashable: Any] = [
      "type": "newItem",
      "targetId": "../../../etc/passwd"
    ]

    // When
    let payload = NotificationPayload(userInfo: userInfo)

    // Then - payload succeeds but targetId is nil (sanitized)
    #expect(payload != nil)
    #expect(payload?.targetId == nil)
  }

  @Test func tooLongTargetId_stripsTargetId() {
    // Given - targetId over 100 chars
    let longId = String(repeating: "a", count: 101)
    let userInfo: [AnyHashable: Any] = [
      "type": "newItem",
      "targetId": longId
    ]

    // When
    let payload = NotificationPayload(userInfo: userInfo)

    // Then
    #expect(payload != nil)
    #expect(payload?.targetId == nil)
  }

  @Test func validTargetId_preservesTargetId() {
    // Given - valid targetId with letters, numbers, hyphen
    let userInfo: [AnyHashable: Any] = [
      "type": "newItem",
      "targetId": "item-ABC123-xyz"
    ]

    // When
    let payload = NotificationPayload(userInfo: userInfo)

    // Then
    #expect(payload?.targetId == "item-ABC123-xyz")
  }
}
