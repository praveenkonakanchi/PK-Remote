package com.praveenkonakanchi.pkremote

import com.praveenkonakanchi.pkremote.discovery.DeviceDiscovery
import com.praveenkonakanchi.pkremote.discovery.DeviceDiscoveryEvent
import com.praveenkonakanchi.pkremote.model.RemoteAppShortcut
import com.praveenkonakanchi.pkremote.model.RemoteCommand
import com.praveenkonakanchi.pkremote.model.RemoteDevice
import com.praveenkonakanchi.pkremote.ui.DiscoveryStatus
import com.praveenkonakanchi.pkremote.ui.PkRemoteUiState
import com.praveenkonakanchi.pkremote.ui.PkRemoteViewModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PkRemoteViewModelTest {
    @Test
    fun startsEmptyAndReadyForDiscovery() {
        val state = PkRemoteViewModel(FakeDeviceDiscovery()).uiState.value

        assertTrue(state.devices.isEmpty())
        assertNull(state.selectedDevice)
        assertEquals(DiscoveryStatus.Idle, state.discoveryStatus)
        assertEquals(listOf("YouTube", "Netflix", "Prime Video", "Aha"), state.shortcuts.map { it.displayName })
    }

    @Test
    fun discoveryUpdatesSortDeduplicateAndSelectDevices() {
        val discovery = FakeDeviceDiscovery()
        val viewModel = PkRemoteViewModel(discovery)
        val bedroom = RemoteDevice.discovered("Bedroom TV", "_androidtvremote2._tcp.")!!
        val livingRoom = RemoteDevice.discovered("living room", "_androidtvremote2._tcp.")!!

        viewModel.startDiscovery()
        assertEquals(DiscoveryStatus.Searching, viewModel.uiState.value.discoveryStatus)
        assertEquals(1, discovery.startCount)

        discovery.emit(DeviceDiscoveryEvent.Snapshot(listOf(livingRoom, bedroom, livingRoom)))

        assertEquals(listOf("Bedroom TV", "living room"), viewModel.uiState.value.devices.map { it.name })
        assertEquals(bedroom.id, viewModel.uiState.value.selectedDeviceId)
        assertEquals(DiscoveryStatus.Idle, viewModel.uiState.value.discoveryStatus)
    }

    @Test
    fun refreshPreservesSelectionAndFallsBackWhenSelectedTvDisappears() {
        val discovery = FakeDeviceDiscovery()
        val viewModel = PkRemoteViewModel(discovery)
        val bedroom = RemoteDevice.discovered("Bedroom TV", "_androidtvremote2._tcp.")!!
        val livingRoom = RemoteDevice.discovered("Living Room", "_androidtvremote2._tcp.")!!

        viewModel.startDiscovery()
        discovery.emit(DeviceDiscoveryEvent.Snapshot(listOf(bedroom, livingRoom)))
        viewModel.selectDevice(livingRoom.id)
        discovery.emit(DeviceDiscoveryEvent.Snapshot(listOf(livingRoom, bedroom)))
        assertEquals(livingRoom.id, viewModel.uiState.value.selectedDeviceId)

        discovery.emit(DeviceDiscoveryEvent.Snapshot(listOf(bedroom)))
        assertEquals(bedroom.id, viewModel.uiState.value.selectedDeviceId)
    }

    @Test
    fun discoveryFailureCanRetryAndStop() {
        val discovery = FakeDeviceDiscovery()
        val viewModel = PkRemoteViewModel(discovery)

        viewModel.startDiscovery()
        discovery.emit(DeviceDiscoveryEvent.Failed("Wi-Fi unavailable"))
        assertEquals(DiscoveryStatus.Failed("Wi-Fi unavailable"), viewModel.uiState.value.discoveryStatus)

        viewModel.startDiscovery()
        assertEquals(2, discovery.startCount)
        viewModel.stopDiscovery()
        assertEquals(1, discovery.stopCount)
        assertEquals(DiscoveryStatus.Idle, viewModel.uiState.value.discoveryStatus)
    }

    @Test
    fun commandsRemainHarmlessLocalStateInDiscoveryMilestone() {
        val viewModel = PkRemoteViewModel(
            deviceDiscovery = FakeDeviceDiscovery(),
            initialState = PkRemoteUiState(
                devices = PkRemoteUiState.previewDevices,
                selectedDeviceId = "peekay-tv",
            ),
        )

        viewModel.selectDevice("bedroom-tv")
        viewModel.handleCommand(RemoteCommand.VolumeUp)

        assertEquals("My bedroom TV", viewModel.uiState.value.selectedDevice?.name)
        assertEquals(RemoteCommand.VolumeUp, viewModel.uiState.value.lastCommand)
    }

    @Test
    fun defaultShortcutsAreUniqueAndRespectTheEightItemLimit() {
        val shortcuts = RemoteAppShortcut.defaults

        assertTrue(shortcuts.size <= RemoteAppShortcut.MaximumCount)
        assertEquals(shortcuts.size, shortcuts.map { it.launchIdentifier.lowercase() }.toSet().size)
    }
}

private class FakeDeviceDiscovery : DeviceDiscovery {
    private var onEvent: ((DeviceDiscoveryEvent) -> Unit)? = null
    var startCount = 0
        private set
    var stopCount = 0
        private set

    override fun start(onEvent: (DeviceDiscoveryEvent) -> Unit) {
        startCount += 1
        this.onEvent = onEvent
    }

    override fun stop() {
        stopCount += 1
    }

    fun emit(event: DeviceDiscoveryEvent) {
        onEvent?.invoke(event)
    }
}
