package com.praveenkonakanchi.pkremote.pairing

import org.junit.Assert.assertEquals
import org.junit.Test
import java.security.KeyPairGenerator
import java.security.MessageDigest
import java.security.interfaces.RSAPublicKey

class PairingSecretTest {
    @Test
    fun validCodeProducesExpectedDigest() {
        val generator = KeyPairGenerator.getInstance("RSA").apply { initialize(2048) }
        val client = generator.generateKeyPair().public as RSAPublicKey
        val server = generator.generateKeyPair().public as RSAPublicKey
        val suffix = byteArrayOf(0xC2.toByte(), 0xC9.toByte())
        val expected = MessageDigest.getInstance("SHA-256").digest(
            client.modulus.unsignedBytes() + client.publicExponent.unsignedBytes() +
                server.modulus.unsignedBytes() + server.publicExponent.unsignedBytes() + suffix,
        )
        val code = "%02X%02X%02X".format(expected.first().toInt() and 0xff, 0xC2, 0xC9)

        val result = PairingSecret.make(code, client, server)

        assertEquals(expected.toList(), result.toList())
    }

    private fun java.math.BigInteger.unsignedBytes(): ByteArray {
        val bytes = toByteArray().dropWhile { it == 0.toByte() }.toByteArray()
        return if (bytes.isEmpty()) byteArrayOf(0) else bytes
    }
}
