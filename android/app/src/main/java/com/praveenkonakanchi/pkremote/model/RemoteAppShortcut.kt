package com.praveenkonakanchi.pkremote.model

import java.util.UUID

data class RemoteAppShortcut(
    val id: String,
    val displayName: String,
    val launchIdentifier: String,
    val initials: String,
    val catalogId: String? = null,
) {
    companion object {
        const val MaximumCount = 8

        val defaults = listOf(
            RemoteAppCatalogItem.verified.first { it.id == "youtube" }.makeShortcut("youtube"),
            RemoteAppCatalogItem.verified.first { it.id == "netflix" }.makeShortcut("netflix"),
            RemoteAppCatalogItem.verified.first { it.id == "prime-video" }.makeShortcut("prime-video"),
            RemoteAppCatalogItem.verified.first { it.id == "aha" }.makeShortcut("aha"),
        )

        fun custom(
            id: String = UUID.randomUUID().toString(),
            displayName: String,
            launchIdentifier: String,
        ): RemoteAppShortcut {
            val trimmedName = displayName.trim()
            return RemoteAppShortcut(
                id = id,
                displayName = trimmedName,
                launchIdentifier = launchIdentifier.trim(),
                initials = trimmedName.take(1).uppercase().ifEmpty { "•" },
            )
        }
    }
}

data class RemoteAppCatalogItem(
    val id: String,
    val displayName: String,
    val launchIdentifier: String,
    val initials: String,
) {
    fun makeShortcut(shortcutId: String = UUID.randomUUID().toString()) = RemoteAppShortcut(
        id = shortcutId,
        displayName = displayName,
        launchIdentifier = launchIdentifier,
        initials = initials,
        catalogId = id,
    )

    companion object {
        val verified = listOf(
            item("youtube", "YouTube", "https://www.youtube.com/", "Y"),
            item("netflix", "Netflix", "https://www.netflix.com/home", "N"),
            item("prime-video", "Prime Video", "https://app.primevideo.com", "P"),
            item("hulu", "Hulu", "https://www.hulu.com/", "H"),
            item("peacock", "Peacock", "https://www.peacocktv.com/deeplink", "P"),
            item("pluto-tv", "Pluto TV", "https://pluto.tv/", "P"),
            item("apple-tv", "Apple TV", "https://tv.apple.com/", "A"),
            item("disney-plus", "Disney+", "https://www.disneyplus.com/", "D"),
            item("aha", "Aha", "https://www.aha.video/tab/home", "A"),
            item("max", "Max", "https://play.max.com/", "M"),
            item("tubi", "Tubi", "https://link.tubi.tv/", "T"),
            item("play-store", "Play Store", "https://play.google.com/store", "P"),
        )

        private fun item(id: String, name: String, identifier: String, initial: String) =
            RemoteAppCatalogItem(id, name, identifier, initial)
    }
}
