import Foundation
import Testing
@testable import PK_Remote

struct RemoteProtocolCodecTests {
    @Test func homeCommandUsesShortAndroidKeyInjection() throws {
        let payload = try RemoteProtocolCodec.key(.home)
        let frame = RemoteProtocolCodec.frame(payload)

        #expect(frame == Data([0x06, 0x52, 0x04, 0x08, 0x03, 0x10, 0x03]))
    }

    @Test func digitCommandUsesContiguousAndroidKeyCode() throws {
        let payload = try RemoteProtocolCodec.key(.digit(9))
        let frame = RemoteProtocolCodec.frame(payload)

        #expect(frame == Data([0x06, 0x52, 0x04, 0x08, 0x10, 0x10, 0x03]))
    }

    @Test func pingRequestIsDecodedAndAnswered() throws {
        var frame = Data([0x04, 0x42, 0x02, 0x08, 0x2a])
        let payload = try #require(try RemoteProtocolCodec.extractFrame(from: &frame))

        #expect(try RemoteProtocolCodec.decode(payload) == .ping(42))
        #expect(
            RemoteProtocolCodec.frame(RemoteProtocolCodec.pingResponse(42))
                == Data([0x04, 0x4a, 0x02, 0x08, 0x2a])
        )
    }

    @Test func frameExtractionRetainsPartialMessages() throws {
        let complete = RemoteProtocolCodec.frame(RemoteProtocolCodec.configure())
        var partial = Data(complete.dropLast())

        #expect(try RemoteProtocolCodec.extractFrame(from: &partial) == nil)
        #expect(partial == Data(complete.dropLast()))
    }

    @Test func unknownFixedWidthFieldsAreIgnored() throws {
        let fixed64 = Data([0x19, 0, 0, 0, 0, 0, 0, 0, 0])
        let fixed32 = Data([0x25, 0, 0, 0, 0])

        #expect(try RemoteProtocolCodec.decode(fixed64 + fixed32) == .other)
    }

    @Test func omittedSetActiveValueUsesProto3Default() throws {
        #expect(try RemoteProtocolCodec.decode(Data([0x12, 0x00])) == .setActive(0))
        #expect(RemoteProtocolCodec.setActive(0) == Data([0x12, 0x02, 0x08, 0x00]))
    }
}
