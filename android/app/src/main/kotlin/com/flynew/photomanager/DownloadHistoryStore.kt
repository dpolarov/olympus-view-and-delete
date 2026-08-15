package com.flynew.photomanager

import android.content.Context

class DownloadHistoryStore(context: Context) {
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun getKeys(): Set<String> = synchronized(lock) {
        prefs.getStringSet(KEY_DOWNLOADED, emptySet())?.toSet() ?: emptySet()
    }

    fun mark(key: String) {
        if (key.isBlank()) return
        synchronized(lock) {
            val updated = getKeys().toMutableSet()
            updated.add(key)
            prefs.edit().putStringSet(KEY_DOWNLOADED, updated).apply()
        }
    }

    companion object {
        private const val PREFS_NAME = "olympus_download_history"
        private const val KEY_DOWNLOADED = "downloaded_keys"
        private val lock = Any()
    }
}
