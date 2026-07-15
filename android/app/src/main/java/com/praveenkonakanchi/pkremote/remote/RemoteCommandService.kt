package com.praveenkonakanchi.pkremote.remote

import com.praveenkonakanchi.pkremote.model.RemoteCommand
import com.praveenkonakanchi.pkremote.model.RemoteDevice

internal interface RemoteCommandService : AutoCloseable {
    suspend fun send(command: RemoteCommand, device: RemoteDevice)
    suspend fun stopSession(device: RemoteDevice)
    override fun close()
}

internal sealed class RemoteTransportException(message: String) : Exception(message) {
    data object EndpointUnavailable : RemoteTransportException("Refresh Devices before using the remote.")
    data object NotPaired : RemoteTransportException("Pair this TV before sending remote commands.")
    data object CertificateChanged : RemoteTransportException("The TV identity changed. Pair the TV again.")
    data object PairingRejected : RemoteTransportException("The TV no longer accepts this pairing. Pair the TV again.")
    data object UnsupportedCommand : RemoteTransportException("This remote command is not supported yet.")
    data class ConnectionFailed(val detail: String) : RemoteTransportException("Could not connect to the TV: $detail")

    val invalidatesPairing: Boolean
        get() = this is CertificateChanged || this is PairingRejected || this is NotPaired
}
