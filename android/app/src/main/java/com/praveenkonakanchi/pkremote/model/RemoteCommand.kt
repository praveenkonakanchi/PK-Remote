package com.praveenkonakanchi.pkremote.model

sealed interface RemoteCommand {
    val accessibilityLabel: String

    data object Power : RemoteCommand { override val accessibilityLabel = "Power" }
    data object Home : RemoteCommand { override val accessibilityLabel = "Home" }
    data object Back : RemoteCommand { override val accessibilityLabel = "Back" }
    data object StbSettings : RemoteCommand { override val accessibilityLabel = "Open STB settings" }
    data object GoogleTvQuickSettings : RemoteCommand {
        override val accessibilityLabel = "Open Google TV Quick Settings"
    }
    data object Up : RemoteCommand { override val accessibilityLabel = "Navigate up" }
    data object Down : RemoteCommand { override val accessibilityLabel = "Navigate down" }
    data object Left : RemoteCommand { override val accessibilityLabel = "Navigate left" }
    data object Right : RemoteCommand { override val accessibilityLabel = "Navigate right" }
    data object Select : RemoteCommand { override val accessibilityLabel = "Select" }
    data object VolumeUp : RemoteCommand { override val accessibilityLabel = "Volume up" }
    data object VolumeDown : RemoteCommand { override val accessibilityLabel = "Volume down" }
    data object Mute : RemoteCommand { override val accessibilityLabel = "Mute" }
    data object Previous : RemoteCommand { override val accessibilityLabel = "Previous" }
    data object PlayPause : RemoteCommand { override val accessibilityLabel = "Play or pause" }
    data object Next : RemoteCommand { override val accessibilityLabel = "Next" }
    data object Rewind : RemoteCommand { override val accessibilityLabel = "Rewind" }
    data object FastForward : RemoteCommand { override val accessibilityLabel = "Fast forward" }
    data object View : RemoteCommand { override val accessibilityLabel = "View" }
    data object Sort : RemoteCommand { override val accessibilityLabel = "Sort" }
    data object Favorites : RemoteCommand { override val accessibilityLabel = "Favorites" }
    data object Find : RemoteCommand { override val accessibilityLabel = "Find" }
    data object Keyboard : RemoteCommand { override val accessibilityLabel = "Open keyboard" }

    data class Digit(val value: Int) : RemoteCommand {
        init { require(value in 0..9) }
        override val accessibilityLabel = "Number $value"
    }

    data class EnterText(val value: String) : RemoteCommand {
        override val accessibilityLabel = "Enter text"
    }

    data class LaunchApp(val launchIdentifier: String) : RemoteCommand {
        override val accessibilityLabel = "Open app"
    }
}
