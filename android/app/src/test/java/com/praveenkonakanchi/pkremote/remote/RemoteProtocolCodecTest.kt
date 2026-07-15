package com.praveenkonakanchi.pkremote.remote

import com.praveenkonakanchi.pkremote.model.RemoteCommand
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.ByteArrayInputStream

class RemoteProtocolCodecTest {
    @Test fun homeUsesShortAndroidKeyInjection() {
        assertArrayEquals(byteArrayOf(6, 0x52, 4, 8, 3, 16, 3), RemoteProtocolCodec.frame(RemoteProtocolCodec.key(RemoteCommand.Home)))
    }

    @Test fun digitsAndPortalKeysMatchIosVectors() {
        assertArrayEquals(byteArrayOf(6, 0x52, 4, 8, 16, 16, 3), RemoteProtocolCodec.frame(RemoteProtocolCodec.key(RemoteCommand.Digit(9))))
        assertArrayEquals(byteArrayOf(7, 0x52, 5, 8, 0xb7.toByte(), 1, 16, 3), RemoteProtocolCodec.frame(RemoteProtocolCodec.key(RemoteCommand.View)))
    }

    @Test fun pingIsDecodedAndAnswered() {
        val payload = RemoteProtocolCodec.readFrame(ByteArrayInputStream(byteArrayOf(4, 0x42, 2, 8, 42)))
        assertEquals(RemoteProtocolMessage.Ping(42), RemoteProtocolCodec.decode(payload))
        assertArrayEquals(byteArrayOf(4, 0x4a, 2, 8, 42), RemoteProtocolCodec.frame(RemoteProtocolCodec.pingResponse(42)))
    }

    @Test fun textMatchesIosVector() {
        assertArrayEquals(
            byteArrayOf(21, 0xaa.toByte(), 1, 18, 8, 5, 16, 7, 26, 12, 8, 1, 18, 8, 8, 1, 16, 1, 26, 2, 0x48, 0x69),
            RemoteProtocolCodec.frame(RemoteProtocolCodec.text("Hi", 5, 7)),
        )
    }
}
