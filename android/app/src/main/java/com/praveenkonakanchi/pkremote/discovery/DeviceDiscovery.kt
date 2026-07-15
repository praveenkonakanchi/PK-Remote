package com.praveenkonakanchi.pkremote.discovery

import com.praveenkonakanchi.pkremote.model.RemoteDevice

interface DeviceDiscovery {
    fun start(onEvent: (DeviceDiscoveryEvent) -> Unit)
    fun stop()
}

sealed interface DeviceDiscoveryEvent {
    data class Snapshot(val devices: List<RemoteDevice>) : DeviceDiscoveryEvent
    data class Failed(val message: String) : DeviceDiscoveryEvent
}
