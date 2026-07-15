package com.praveenkonakanchi.pkremote

import com.praveenkonakanchi.pkremote.model.RemoteCommand
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class RemoteCommandTest {
    @Test
    fun semanticCommandsExposeAccessibleLabels() {
        assertEquals("Open Google TV Quick Settings", RemoteCommand.GoogleTvQuickSettings.accessibilityLabel)
        assertEquals("Open STB settings", RemoteCommand.StbSettings.accessibilityLabel)
        assertEquals("Number 7", RemoteCommand.Digit(7).accessibilityLabel)
    }

    @Test
    fun digitCommandsRejectValuesOutsideTheRemoteNumberPad() {
        assertThrows(IllegalArgumentException::class.java) { RemoteCommand.Digit(10) }
    }
}
