package com.praveenkonakanchi.pkremote.pairing

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.ByteArrayInputStream

class PairingProtocolCodecTest {
    @Test
    fun pairingRequestUsesDelimitedVersionTwoEnvelope() {
        val payload = PairingProtocolCodec.pairingRequest("PK Remote")
        val frame = PairingProtocolCodec.frame(payload)

        assertArrayEquals(payload, PairingProtocolCodec.readFrame(ByteArrayInputStream(frame)))
        assertArrayEquals(
            byteArrayOf(0x08, 0x02, 0x10, 0xC8.toByte(), 0x01),
            payload.copyOfRange(0, 5),
        )
    }

    @Test
    fun decoderRecognizesAcknowledgement() {
        val acknowledgement = byteArrayOf(
            0x08, 0x02, 0x10, 0xC8.toByte(), 0x01,
            0x5A, 0x00,
        )

        assertEquals(
            PairingMessageKind.PairingRequestAcknowledgement,
            PairingProtocolCodec.decodeKind(acknowledgement),
        )
    }

    @Test
    fun frameReaderHandlesFragmentedInput() {
        val payload = PairingProtocolCodec.configuration()
        val frame = PairingProtocolCodec.frame(payload)
        val input = object : ByteArrayInputStream(frame) {
            override fun read(bytes: ByteArray, offset: Int, length: Int): Int =
                super.read(bytes, offset, minOf(length, 1))
        }

        assertArrayEquals(payload, PairingProtocolCodec.readFrame(input))
    }
}
