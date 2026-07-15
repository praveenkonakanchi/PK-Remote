package com.praveenkonakanchi.pkremote

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import com.praveenkonakanchi.pkremote.ui.PkRemoteApp
import com.praveenkonakanchi.pkremote.ui.PkRemoteViewModel
import com.praveenkonakanchi.pkremote.ui.theme.PkRemoteTheme
import org.junit.Rule
import org.junit.Test

class PkRemoteAppTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun primaryNavigationExposesAllThreeReferenceScreens() {
        val viewModel = PkRemoteViewModel()
        composeRule.setContent {
            PkRemoteTheme { PkRemoteApp(viewModel = viewModel) }
        }

        composeRule.onNodeWithContentDescription("Refresh devices").assertIsDisplayed()
        composeRule.onNodeWithText("Remote").performClick()
        composeRule.onNodeWithContentDescription("Select").assertIsDisplayed()
        composeRule.onNodeWithText("STB Mode").performClick()
        composeRule.onNodeWithContentDescription("Open keyboard").assertIsDisplayed()
        composeRule.onNodeWithContentDescription("Open YouTube").assertIsDisplayed()
    }
}
