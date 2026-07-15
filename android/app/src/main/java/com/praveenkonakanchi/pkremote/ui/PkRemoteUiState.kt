package com.praveenkonakanchi.pkremote.ui

import com.praveenkonakanchi.pkremote.model.RemoteAppShortcut
import com.praveenkonakanchi.pkremote.model.RemoteCommand
import com.praveenkonakanchi.pkremote.model.RemoteDevice

data class PkRemoteUiState(
    val devices: List<RemoteDevice> = emptyList(),
    val selectedDeviceId: String? = null,
    val discoveryStatus: DiscoveryStatus = DiscoveryStatus.Idle,
    val shortcuts: List<RemoteAppShortcut> = RemoteAppShortcut.defaults,
    val lastCommand: RemoteCommand? = null,
) {
    val selectedDevice: RemoteDevice?
        get() = devices.firstOrNull { it.id == selectedDeviceId }

    companion object {
        val previewDevices = listOf(
            RemoteDevice(id = "bedroom-tv", name = "My bedroom TV"),
            RemoteDevice(id = "peekay-tv", name = "peekay TV", isPaired = true),
        )
    }
}

sealed interface DiscoveryStatus {
    data object Idle : DiscoveryStatus
    data object Searching : DiscoveryStatus
    data class Failed(val message: String) : DiscoveryStatus
}
