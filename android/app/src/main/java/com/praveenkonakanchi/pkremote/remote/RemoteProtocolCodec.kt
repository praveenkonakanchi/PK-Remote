package com.praveenkonakanchi.pkremote.remote

import com.praveenkonakanchi.pkremote.model.RemoteCommand
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.io.OutputStream

internal enum class RemoteKeyDirection(val value: Int) { StartLong(1), EndLong(2), Short(3) }

internal sealed interface RemoteProtocolMessage {
    data object Configure : RemoteProtocolMessage
    data class SetActive(val value: Int) : RemoteProtocolMessage
    data class RemoteError(val isError: Boolean, val originalField: Int?) : RemoteProtocolMessage
    data class Ping(val value: Int) : RemoteProtocolMessage
    data class ImeBatchEdit(val imeCounter: Int, val fieldCounter: Int) : RemoteProtocolMessage
    data object Other : RemoteProtocolMessage
}

internal class RemoteProtocolException(message: String) : Exception(message)

internal object RemoteProtocolCodec {
    private const val MaximumFrameLength = 1_048_576

    fun configure(): ByteArray {
        val deviceInfo = message(
            field(1, "Android"), field(2, "PK Remote"), field(3, 1),
            field(4, "1"), field(5, "com.praveenkonakanchi.pkremote"), field(6, "1.0.0"),
        )
        return envelope(1, message(field(1, 622), field(2, deviceInfo)))
    }

    fun setActive(value: Int): ByteArray = envelope(2, message(field(1, value)))
    fun pingResponse(value: Int): ByteArray = envelope(9, message(field(1, value)))

    fun key(command: RemoteCommand, direction: RemoteKeyDirection = RemoteKeyDirection.Short): ByteArray {
        val keyCode = command.androidKeyCode() ?: throw RemoteTransportException.UnsupportedCommand
        return envelope(10, message(field(1, keyCode), field(2, direction.value)))
    }

    fun appLink(identifier: String): ByteArray {
        val normalized = identifier.trim()
        if (normalized.isEmpty()) throw RemoteTransportException.UnsupportedCommand
        return envelope(90, message(field(1, normalized)))
    }

    fun text(text: String, imeCounter: Int, fieldCounter: Int): ByteArray {
        if (text.isEmpty()) throw RemoteTransportException.UnsupportedCommand
        val finalIndex = (text.codePointCount(0, text.length) - 1).coerceAtLeast(0)
        val imeObject = message(field(1, finalIndex), field(2, finalIndex), field(3, text))
        val editInfo = message(field(1, 1), field(2, imeObject))
        return envelope(21, message(field(1, imeCounter), field(2, fieldCounter), field(3, editInfo)))
    }

    fun decode(data: ByteArray): RemoteProtocolMessage {
        val reader = ProtobufReader(data)
        while (reader.hasRemaining) {
            val entry = reader.next()
            val payload = (entry.value as? ProtobufValue.Bytes)?.value ?: continue
            return when (entry.number) {
                1 -> RemoteProtocolMessage.Configure
                2 -> RemoteProtocolMessage.SetActive(firstVarint(payload))
                3 -> remoteError(payload)
                8 -> RemoteProtocolMessage.Ping(firstVarint(payload))
                21 -> imeCounters(payload)
                else -> continue
            }
        }
        return RemoteProtocolMessage.Other
    }

    fun frame(payload: ByteArray): ByteArray = varint(payload.size.toLong()) + payload

    fun writeFrame(output: OutputStream, payload: ByteArray) {
        output.write(frame(payload))
        output.flush()
    }

    fun readFrame(input: InputStream): ByteArray {
        val length = readVarint(input)
        if (length !in 0..MaximumFrameLength.toLong()) throw RemoteProtocolException("Invalid remote frame length.")
        val payload = ByteArray(length.toInt())
        var offset = 0
        while (offset < payload.size) {
            val count = input.read(payload, offset, payload.size - offset)
            if (count < 0) throw RemoteProtocolException("The TV closed the remote connection.")
            offset += count
        }
        return payload
    }

    private fun envelope(number: Int, payload: ByteArray): ByteArray = message(field(number, payload))

    private fun firstVarint(data: ByteArray): Int {
        val reader = ProtobufReader(data)
        while (reader.hasRemaining) {
            val entry = reader.next()
            if (entry.number == 1) return (entry.value as? ProtobufValue.Varint)?.value?.toInt() ?: 0
        }
        return 0
    }

    private fun imeCounters(data: ByteArray): RemoteProtocolMessage.ImeBatchEdit {
        var ime = 0
        var field = 0
        val reader = ProtobufReader(data)
        while (reader.hasRemaining) {
            val entry = reader.next()
            val value = (entry.value as? ProtobufValue.Varint)?.value?.toInt() ?: continue
            if (entry.number == 1) ime = value
            if (entry.number == 2) field = value
        }
        return RemoteProtocolMessage.ImeBatchEdit(ime, field)
    }

    private fun remoteError(data: ByteArray): RemoteProtocolMessage.RemoteError {
        var isError = false
        var originalField: Int? = null
        val reader = ProtobufReader(data)
        while (reader.hasRemaining) {
            val entry = reader.next()
            if (entry.number == 1) isError = (entry.value as? ProtobufValue.Varint)?.value != 0L
            if (entry.number == 2) {
                val nested = (entry.value as? ProtobufValue.Bytes)?.value ?: continue
                val nestedReader = ProtobufReader(nested)
                if (nestedReader.hasRemaining) originalField = nestedReader.next().number
            }
        }
        return RemoteProtocolMessage.RemoteError(isError, originalField)
    }

    private fun message(vararg fields: ByteArray): ByteArray = ByteArrayOutputStream().apply {
        fields.forEach { write(it) }
    }.toByteArray()

    private fun field(number: Int, value: Int): ByteArray = varint((number shl 3).toLong()) + varint(value.toLong())
    private fun field(number: Int, value: String): ByteArray = field(number, value.encodeToByteArray())
    private fun field(number: Int, value: ByteArray): ByteArray =
        varint(((number shl 3) or 2).toLong()) + varint(value.size.toLong()) + value

    private fun varint(initial: Long): ByteArray {
        var value = initial
        return ByteArrayOutputStream().apply {
            do {
                var byte = (value and 0x7f).toInt()
                value = value ushr 7
                if (value != 0L) byte = byte or 0x80
                write(byte)
            } while (value != 0L)
        }.toByteArray()
    }

    private fun readVarint(input: InputStream): Long {
        var value = 0L
        repeat(10) { index ->
            val byte = input.read()
            if (byte < 0) throw RemoteProtocolException("The TV closed the remote connection.")
            value = value or ((byte and 0x7f).toLong() shl (index * 7))
            if (byte and 0x80 == 0) return value
        }
        throw RemoteProtocolException("Invalid remote frame prefix.")
    }
}

private fun RemoteCommand.androidKeyCode(): Int? = when (this) {
    RemoteCommand.Home, RemoteCommand.GoogleTvQuickSettings -> 3
    RemoteCommand.Back -> 4
    is RemoteCommand.Digit -> 7 + value
    RemoteCommand.Up -> 19
    RemoteCommand.Down -> 20
    RemoteCommand.Left -> 21
    RemoteCommand.Right -> 22
    RemoteCommand.Select -> 23
    RemoteCommand.VolumeUp -> 24
    RemoteCommand.VolumeDown -> 25
    RemoteCommand.Power -> 26
    RemoteCommand.StbSettings -> 82
    RemoteCommand.PlayPause -> 85
    RemoteCommand.Next -> 87
    RemoteCommand.Previous -> 88
    RemoteCommand.Rewind -> 89
    RemoteCommand.FastForward -> 90
    RemoteCommand.Mute -> 91
    RemoteCommand.View -> 183
    RemoteCommand.Sort -> 184
    RemoteCommand.Favorites -> 185
    RemoteCommand.Find -> 186
    RemoteCommand.Keyboard, is RemoteCommand.EnterText, is RemoteCommand.LaunchApp -> null
}

private sealed interface ProtobufValue {
    data class Varint(val value: Long) : ProtobufValue
    data class Bytes(val value: ByteArray) : ProtobufValue
    data object Ignored : ProtobufValue
}

private data class ProtobufEntry(val number: Int, val value: ProtobufValue)

private class ProtobufReader(private val data: ByteArray) {
    private var index = 0
    val hasRemaining: Boolean get() = index < data.size

    fun next(): ProtobufEntry {
        val key = readVarint()
        val number = (key ushr 3).toInt()
        return when ((key and 7).toInt()) {
            0 -> ProtobufEntry(number, ProtobufValue.Varint(readVarint()))
            1 -> { skip(8); ProtobufEntry(number, ProtobufValue.Ignored) }
            2 -> {
                val length = readVarint().toInt()
                if (length < 0 || index + length > data.size) throw RemoteProtocolException("Malformed remote data.")
                val value = data.copyOfRange(index, index + length)
                index += length
                ProtobufEntry(number, ProtobufValue.Bytes(value))
            }
            5 -> { skip(4); ProtobufEntry(number, ProtobufValue.Ignored) }
            else -> throw RemoteProtocolException("Malformed remote data.")
        }
    }

    private fun skip(count: Int) {
        if (index + count > data.size) throw RemoteProtocolException("Malformed remote data.")
        index += count
    }

    private fun readVarint(): Long {
        var value = 0L
        for (shift in 0..63 step 7) {
            if (index >= data.size) throw RemoteProtocolException("Malformed remote data.")
            val byte = data[index++].toInt() and 0xff
            value = value or ((byte and 0x7f).toLong() shl shift)
            if (byte and 0x80 == 0) return value
        }
        throw RemoteProtocolException("Malformed remote data.")
    }
}
