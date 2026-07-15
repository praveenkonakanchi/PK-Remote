package com.praveenkonakanchi.pkremote.pairing

import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.io.OutputStream

internal enum class PairingMessageKind(val fieldNumber: Int) {
    PairingRequest(10),
    PairingRequestAcknowledgement(11),
    Options(20),
    Configuration(30),
    ConfigurationAcknowledgement(31),
    Secret(40),
    SecretAcknowledgement(41),
}

internal class PairingProtocolException(message: String) : Exception(message)

internal object PairingProtocolCodec {
    private const val MaximumFrameLength = 1_048_576

    fun pairingRequest(clientName: String): ByteArray = envelope(
        kind = PairingMessageKind.PairingRequest,
        payload = message(
            field(1, "atvremote"),
            field(2, clientName),
        ),
    )

    fun options(): ByteArray {
        val hexadecimalEncoding = message(field(1, 3), field(2, 6))
        return envelope(
            kind = PairingMessageKind.Options,
            payload = message(field(1, hexadecimalEncoding), field(3, 1)),
        )
    }

    fun configuration(): ByteArray {
        val hexadecimalEncoding = message(field(1, 3), field(2, 6))
        return envelope(
            kind = PairingMessageKind.Configuration,
            payload = message(field(1, hexadecimalEncoding), field(2, 1)),
        )
    }

    fun secret(secret: ByteArray): ByteArray = envelope(
        kind = PairingMessageKind.Secret,
        payload = message(field(1, secret)),
    )

    fun decodeKind(data: ByteArray): PairingMessageKind {
        val reader = ProtobufReader(data)
        var status: Long? = null
        var kind: PairingMessageKind? = null
        while (reader.hasRemaining) {
            val entry = reader.next()
            if (entry.number == 2 && entry.value is ProtobufValue.Varint) {
                status = entry.value.value
            } else {
                PairingMessageKind.entries.firstOrNull { it.fieldNumber == entry.number }?.let {
                    kind = it
                }
            }
        }
        if (status != 200L) throw PairingProtocolException("The TV rejected the pairing message.")
        return kind ?: throw PairingProtocolException("The TV returned an unexpected pairing message.")
    }

    fun writeFrame(output: OutputStream, payload: ByteArray) {
        output.write(varint(payload.size.toLong()))
        output.write(payload)
        output.flush()
    }

    fun readFrame(input: InputStream): ByteArray {
        val length = readVarint(input)
        if (length !in 0..MaximumFrameLength.toLong()) {
            throw PairingProtocolException("The TV returned an invalid pairing frame.")
        }
        val payload = ByteArray(length.toInt())
        var offset = 0
        while (offset < payload.size) {
            val count = input.read(payload, offset, payload.size - offset)
            if (count < 0) throw PairingProtocolException("The TV closed the pairing connection.")
            offset += count
        }
        return payload
    }

    fun frame(payload: ByteArray): ByteArray = varint(payload.size.toLong()) + payload

    private fun envelope(kind: PairingMessageKind, payload: ByteArray): ByteArray = message(
        field(1, 2),
        field(2, 200),
        field(kind.fieldNumber, payload),
    )

    private fun message(vararg fields: ByteArray): ByteArray = ByteArrayOutputStream().apply {
        fields.forEach(::write)
    }.toByteArray()

    private fun field(number: Int, value: Int): ByteArray =
        varint((number shl 3).toLong()) + varint(value.toLong())

    private fun field(number: Int, value: String): ByteArray = field(number, value.encodeToByteArray())

    private fun field(number: Int, value: ByteArray): ByteArray =
        varint(((number shl 3) or 2).toLong()) + varint(value.size.toLong()) + value

    private fun varint(initialValue: Long): ByteArray {
        var value = initialValue
        val output = ByteArrayOutputStream()
        do {
            var byte = (value and 0x7f).toInt()
            value = value ushr 7
            if (value != 0L) byte = byte or 0x80
            output.write(byte)
        } while (value != 0L)
        return output.toByteArray()
    }

    private fun readVarint(input: InputStream): Long {
        var value = 0L
        for (index in 0 until 10) {
            val byte = input.read()
            if (byte < 0) throw PairingProtocolException("The TV closed the pairing connection.")
            value = value or ((byte and 0x7f).toLong() shl (index * 7))
            if (byte and 0x80 == 0) return value
        }
        throw PairingProtocolException("The TV returned an invalid pairing frame.")
    }
}

private sealed interface ProtobufValue {
    data class Varint(val value: Long) : ProtobufValue
    data class Bytes(val value: ByteArray) : ProtobufValue
}

private data class ProtobufEntry(val number: Int, val value: ProtobufValue)

private class ProtobufReader(private val data: ByteArray) {
    private var index = 0
    val hasRemaining: Boolean get() = index < data.size

    fun next(): ProtobufEntry {
        val key = readVarint()
        val number = (key ushr 3).toInt()
        return when ((key and 0x07).toInt()) {
            0 -> ProtobufEntry(number, ProtobufValue.Varint(readVarint()))
            2 -> {
                val length = readVarint().toInt()
                if (length < 0 || index + length > data.size) {
                    throw PairingProtocolException("The TV returned malformed pairing data.")
                }
                val value = data.copyOfRange(index, index + length)
                index += length
                ProtobufEntry(number, ProtobufValue.Bytes(value))
            }
            else -> throw PairingProtocolException("The TV returned malformed pairing data.")
        }
    }

    private fun readVarint(): Long {
        var value = 0L
        for (shift in 0..63 step 7) {
            if (index >= data.size) throw PairingProtocolException("The TV returned malformed pairing data.")
            val byte = data[index++].toInt() and 0xff
            value = value or ((byte and 0x7f).toLong() shl shift)
            if (byte and 0x80 == 0) return value
        }
        throw PairingProtocolException("The TV returned malformed pairing data.")
    }
}
