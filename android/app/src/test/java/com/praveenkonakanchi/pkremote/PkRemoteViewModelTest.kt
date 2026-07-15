package com.praveenkonakanchi.pkremote

import com.praveenkonakanchi.pkremote.discovery.DeviceDiscovery
import com.praveenkonakanchi.pkremote.discovery.DeviceDiscoveryEvent
import com.praveenkonakanchi.pkremote.model.RemoteAppShortcut
import com.praveenkonakanchi.pkremote.model.RemoteAppCatalogItem
import com.praveenkonakanchi.pkremote.model.RemoteCommand
import com.praveenkonakanchi.pkremote.model.RemoteDevice
import com.praveenkonakanchi.pkremote.remote.RemoteCommandService
import com.praveenkonakanchi.pkremote.remote.RemoteTransportException
import com.praveenkonakanchi.pkremote.ui.CommandSurface
import com.praveenkonakanchi.pkremote.ui.DiscoveryStatus
import com.praveenkonakanchi.pkremote.ui.PkRemoteUiState
import com.praveenkonakanchi.pkremote.ui.PkRemoteViewModel
import com.praveenkonakanchi.pkremote.shortcuts.AppShortcutStore
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class PkRemoteViewModelTest {
    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

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

    @Test
    fun restoresPersistedShortcutsInsteadOfDefaults() {
        val persisted = listOf(RemoteAppCatalogItem.verified.first { it.id == "max" }.makeShortcut("saved-max"))
        val store = FakeAppShortcutStore(persisted)

        val state = PkRemoteViewModel(FakeDeviceDiscovery(), shortcutStore = store).uiState.value

        assertEquals(listOf("Max"), state.shortcuts.map { it.displayName })
        assertEquals(0, store.saveCount)
    }

    @Test
    fun initializesAndPersistsDefaultShortcutsForNewInstall() {
        val store = FakeAppShortcutStore()

        PkRemoteViewModel(FakeDeviceDiscovery(), shortcutStore = store)

        assertEquals(1, store.saveCount)
        assertEquals(listOf("YouTube", "Netflix", "Prime Video", "Aha"), store.saved.map { it.displayName })
    }

    @Test
    fun shortcutMutationsPersistAndPreserveOrdering() {
        val store = FakeAppShortcutStore(RemoteAppShortcut.defaults)
        val viewModel = PkRemoteViewModel(FakeDeviceDiscovery(), shortcutStore = store)
        val max = RemoteAppCatalogItem.verified.first { it.id == "max" }.makeShortcut("max-shortcut")

        viewModel.addShortcut(max)
        viewModel.moveShortcut(max.id, -1)
        val replacement = RemoteAppCatalogItem.verified.first { it.id == "tubi" }.makeShortcut(max.id)
        viewModel.replaceShortcut(replacement)
        viewModel.removeShortcut("netflix")

        assertEquals(listOf("YouTube", "Prime Video", "Tubi", "Aha"), viewModel.uiState.value.shortcuts.map { it.displayName })
        assertEquals(viewModel.uiState.value.shortcuts, store.saved)
        assertEquals(4, store.saveCount)
    }

    @Test
    fun duplicateAndNinthShortcutsAreRejected() {
        val eight = RemoteAppCatalogItem.verified.take(RemoteAppShortcut.MaximumCount).map { it.makeShortcut(it.id) }
        val store = FakeAppShortcutStore(eight)
        val viewModel = PkRemoteViewModel(FakeDeviceDiscovery(), shortcutStore = store)

        viewModel.addShortcut(RemoteAppCatalogItem.verified[8].makeShortcut())
        viewModel.removeShortcut(eight.last().id)
        viewModel.addShortcut(RemoteAppCatalogItem.verified.first().makeShortcut("duplicate-youtube"))

        assertEquals(RemoteAppShortcut.MaximumCount - 1, viewModel.uiState.value.shortcuts.size)
        assertEquals(1, viewModel.uiState.value.shortcuts.count { it.catalogId == "youtube" })
    }

    @Test
    @OptIn(ExperimentalCoroutinesApi::class)
    fun rejectedShortcutShowsTemporaryStbOnlyInstallMessage() = runTest {
        val viewModel = PkRemoteViewModel(
            deviceDiscovery = FakeDeviceDiscovery(),
            remoteService = RejectingAppLaunchService(),
            initialState = PkRemoteUiState(
                devices = PkRemoteUiState.previewDevices,
                selectedDeviceId = "peekay-tv",
            ),
        )

        viewModel.handleCommand(
            RemoteCommand.LaunchApp(RemoteAppShortcut.defaults.first().launchIdentifier),
            CommandSurface.StbMode,
        )

        assertEquals(CommandSurface.StbMode, viewModel.uiState.value.commandFeedback?.surface)
        assertEquals(
            "Couldn’t open YouTube. Make sure the app is installed on your TV, then try again.",
            viewModel.uiState.value.commandFeedback?.message,
        )

        advanceTimeBy(4_001)
        assertNull(viewModel.uiState.value.commandFeedback)
    }
}

private class RejectingAppLaunchService : RemoteCommandService {
    override suspend fun send(command: RemoteCommand, device: RemoteDevice) {
        throw RemoteTransportException.AppLaunchRejected
    }

    override suspend fun stopSession(device: RemoteDevice) = Unit

    override fun close() = Unit
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

private class FakeAppShortcutStore(initial: List<RemoteAppShortcut>? = null) : AppShortcutStore {
    private val initialValue = initial
    var saved: List<RemoteAppShortcut> = emptyList()
        private set
    var saveCount = 0
        private set

    override fun load(): List<RemoteAppShortcut>? = initialValue

    override fun save(shortcuts: List<RemoteAppShortcut>) {
        saved = shortcuts
        saveCount += 1
    }
}
