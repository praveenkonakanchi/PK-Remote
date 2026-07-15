package com.praveenkonakanchi.pkremote

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import com.praveenkonakanchi.pkremote.discovery.DeviceDiscovery
import com.praveenkonakanchi.pkremote.discovery.DeviceDiscoveryEvent
import com.praveenkonakanchi.pkremote.ui.PkRemoteApp
import com.praveenkonakanchi.pkremote.ui.PkRemoteViewModel
import com.praveenkonakanchi.pkremote.ui.theme.PkRemoteTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class PkRemoteAppTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun primaryNavigationExposesAllThreeReferenceScreens() {
        val discovery = RecordingDeviceDiscovery()
        val viewModel = PkRemoteViewModel(discovery)
        composeRule.setContent {
            PkRemoteTheme { PkRemoteApp(viewModel = viewModel) }
        }

        composeRule.onNodeWithContentDescription("Refresh devices").assertIsDisplayed()
        composeRule.waitForIdle()
        assertEquals(1, discovery.startCount)
        composeRule.onNodeWithText("Remote").performClick()
        composeRule.waitForIdle()
        assertEquals(1, discovery.stopCount)
        composeRule.onNodeWithContentDescription("Select").assertIsDisplayed()
        composeRule.onNodeWithText("STB Mode").performClick()
        composeRule.onNodeWithContentDescription("Open keyboard").assertIsDisplayed()
        composeRule.onNodeWithContentDescription("Open YouTube").assertIsDisplayed()
        composeRule.onNodeWithContentDescription("Add app shortcut").performClick()
        composeRule.onNodeWithText("Popular Apps").assertIsDisplayed()
        composeRule.onNodeWithText("Hulu").assertIsDisplayed()
        composeRule.onNodeWithText("Advanced / Custom Shortcut").performScrollTo().assertIsDisplayed()
        assertTrue(composeRule.onAllNodesWithText("https://www.hulu.com/").fetchSemanticsNodes().isEmpty())
    }
}

private class RecordingDeviceDiscovery : DeviceDiscovery {
    var startCount = 0
    var stopCount = 0

    override fun start(onEvent: (DeviceDiscoveryEvent) -> Unit) {
        startCount += 1
    }

    override fun stop() {
        stopCount += 1
    }
}
