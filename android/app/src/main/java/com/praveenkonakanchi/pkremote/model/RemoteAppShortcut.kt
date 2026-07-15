package com.praveenkonakanchi.pkremote.model

data class RemoteAppShortcut(
    val id: String,
    val displayName: String,
    val launchIdentifier: String,
    val initials: String,
) {
    companion object {
        const val MaximumCount = 8

        val defaults = listOf(
            RemoteAppShortcut("youtube", "YouTube", "https://www.youtube.com/", "Y"),
            RemoteAppShortcut("netflix", "Netflix", "https://www.netflix.com/home", "N"),
            RemoteAppShortcut("prime-video", "Prime Video", "https://app.primevideo.com", "P"),
            RemoteAppShortcut("aha", "Aha", "https://www.aha.video/tab/home", "A"),
        )
    }
}
