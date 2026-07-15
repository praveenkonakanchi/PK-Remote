package com.praveenkonakanchi.pkremote.model

data class RemoteDevice(
    val id: String,
    val name: String,
    val kind: String = "Google TV",
    val isAvailable: Boolean = true,
    val isPaired: Boolean = false,
)
