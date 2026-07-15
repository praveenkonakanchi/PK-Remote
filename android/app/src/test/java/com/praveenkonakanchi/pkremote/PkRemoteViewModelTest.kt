package com.praveenkonakanchi.pkremote

import com.praveenkonakanchi.pkremote.model.RemoteAppShortcut
import com.praveenkonakanchi.pkremote.model.RemoteCommand
import com.praveenkonakanchi.pkremote.ui.PkRemoteViewModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PkRemoteViewModelTest {
    @Test
    fun initialStateMatchesTheIosReferencePreview() {
        val state = PkRemoteViewModel().uiState.value

        assertEquals(listOf("My bedroom TV", "peekay TV"), state.devices.map { it.name })
        assertEquals("peekay TV", state.selectedDevice?.name)
        assertTrue(state.selectedDevice?.isPaired == true)
        assertEquals(listOf("YouTube", "Netflix", "Prime Video", "Aha"), state.shortcuts.map { it.displayName })
        assertNull(state.lastCommand)
    }

    @Test
    fun selectionAndCommandsAreHarmlessLocalStateInMilestoneOne() {
        val viewModel = PkRemoteViewModel()

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
