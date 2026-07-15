package com.praveenkonakanchi.pkremote.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val Indigo = Color(0xFF635BFF)

private val LightColors = lightColorScheme(
    primary = Indigo,
    secondary = Indigo,
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFF7C83FF),
    secondary = Color(0xFF7C83FF),
)

@Composable
fun PkRemoteTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        content = content,
    )
}
