package com.praveenkonakanchi.pkremote.ui

import com.praveenkonakanchi.pkremote.model.RemoteAppShortcut
import com.praveenkonakanchi.pkremote.model.RemoteCommand
import com.praveenkonakanchi.pkremote.model.RemoteDevice

data class PkRemoteUiState(
    val devices: List<RemoteDevice> = emptyList(),
    val selectedDeviceId: String? = null,
    val discoveryStatus: DiscoveryStatus = DiscoveryStatus.Idle,
    val pairingStatuses: Map<String, PairingStatus> = emptyMap(),
    val commandFeedback: CommandFeedback? = null,
    val shortcuts: List<RemoteAppShortcut> = RemoteAppShortcut.defaults,
    val lastCommand: RemoteCommand? = null,
) {
    val selectedDevice: RemoteDevice?
        get() = devices.firstOrNull { it.id == selectedDeviceId }

    fun pairingStatus(deviceId: String): PairingStatus = pairingStatuses[deviceId]
        ?: if (devices.firstOrNull { it.id == deviceId }?.isPaired == true) PairingStatus.Paired else PairingStatus.Unpaired

    companion object {
        val previewDevices = listOf(
            RemoteDevice(id = "bedroom-tv", name = "My bedroom TV"),
            RemoteDevice(id = "peekay-tv", name = "peekay TV", isPaired = true),
        )
    }
}

enum class CommandSurface { Remote, StbMode }

data class CommandFeedback(val surface: CommandSurface, val message: String)

sealed interface PairingStatus {
    data object Unpaired : PairingStatus
    data object RequestingCode : PairingStatus
    data object AwaitingCode : PairingStatus
    data object Pairing : PairingStatus
    data object Paired : PairingStatus
    data class Failed(val message: String) : PairingStatus
}

sealed interface DiscoveryStatus {
    data object Idle : DiscoveryStatus
    data object Searching : DiscoveryStatus
    data class Failed(val message: String) : DiscoveryStatus
}
