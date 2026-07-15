package com.praveenkonakanchi.pkremote.shortcuts

import android.content.Context
import com.praveenkonakanchi.pkremote.model.RemoteAppShortcut
import org.json.JSONArray
import org.json.JSONObject

interface AppShortcutStore {
    fun load(): List<RemoteAppShortcut>?
    fun save(shortcuts: List<RemoteAppShortcut>)
}

class SharedPreferencesAppShortcutStore(context: Context) : AppShortcutStore {
    private val preferences = context.getSharedPreferences(PreferencesName, Context.MODE_PRIVATE)

    override fun load(): List<RemoteAppShortcut>? {
        val encoded = preferences.getString(ShortcutsKey, null) ?: return null
        return runCatching {
            val array = JSONArray(encoded)
            buildList {
                for (index in 0 until array.length()) {
                    val item = array.getJSONObject(index)
                    add(
                        RemoteAppShortcut(
                            id = item.getString("id"),
                            displayName = item.getString("displayName"),
                            launchIdentifier = item.getString("launchIdentifier"),
                            initials = item.getString("initials"),
                            catalogId = item.optString("catalogId").takeIf { it.isNotEmpty() },
                        ),
                    )
                }
            }
        }.getOrNull()
    }

    override fun save(shortcuts: List<RemoteAppShortcut>) {
        val array = JSONArray()
        shortcuts.take(RemoteAppShortcut.MaximumCount).forEach { shortcut ->
            array.put(
                JSONObject()
                    .put("id", shortcut.id)
                    .put("displayName", shortcut.displayName)
                    .put("launchIdentifier", shortcut.launchIdentifier)
                    .put("initials", shortcut.initials)
                    .put("catalogId", shortcut.catalogId ?: ""),
            )
        }
        preferences.edit().putString(ShortcutsKey, array.toString()).apply()
    }

    private companion object {
        const val PreferencesName = "pk_remote_app_shortcuts"
        const val ShortcutsKey = "shortcuts.v1"
    }
}
