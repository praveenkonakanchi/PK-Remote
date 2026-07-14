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

    @Test func stbPortalActionsUseAndroidProgrammableColorKeys() throws {
        #expect(
            RemoteProtocolCodec.frame(try RemoteProtocolCodec.key(.view))
                == Data([0x07, 0x52, 0x05, 0x08, 0xb7, 0x01, 0x10, 0x03])
        )
        #expect(
            RemoteProtocolCodec.frame(try RemoteProtocolCodec.key(.sort))
                == Data([0x07, 0x52, 0x05, 0x08, 0xb8, 0x01, 0x10, 0x03])
        )
        #expect(
            RemoteProtocolCodec.frame(try RemoteProtocolCodec.key(.favorites))
                == Data([0x07, 0x52, 0x05, 0x08, 0xb9, 0x01, 0x10, 0x03])
        )
        #expect(
            RemoteProtocolCodec.frame(try RemoteProtocolCodec.key(.find))
                == Data([0x07, 0x52, 0x05, 0x08, 0xba, 0x01, 0x10, 0x03])
        )
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

    @Test func imeCountersAreDecoded() throws {
        let payload = Data([0xaa, 0x01, 0x04, 0x08, 0x05, 0x10, 0x07])

        #expect(
            try RemoteProtocolCodec.decode(payload)
                == .imeBatchEdit(imeCounter: 5, fieldCounter: 7)
        )
    }

    @Test func textUsesImeBatchEditWithCurrentCounters() throws {
        let payload = try RemoteProtocolCodec.text("Hi", imeCounter: 5, fieldCounter: 7)

        #expect(
            RemoteProtocolCodec.frame(payload)
                == Data([
                    0x15, 0xaa, 0x01, 0x12, 0x08, 0x05, 0x10, 0x07, 0x1a, 0x0c,
                    0x08, 0x01, 0x12, 0x08, 0x08, 0x01, 0x10, 0x01, 0x1a, 0x02,
                    0x48, 0x69
                ])
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
