package com.suamisihat.sscam.data.api

import android.content.Context

/**
 * ServerPreferences manages persistence of the Web Portal / Synology NAS API endpoint.
 * Allows switching between official production hosting (creative.suamisihat.myds.me),
 * local LAN development/power-outage server (e.g. http://192.168.1.100:4000),
 * and custom white-label client domains without recompilation.
 */
object ServerPreferences {
    private const val PREFS_NAME = "sscam_server_prefs"
    private const val KEY_CUSTOM_URL = "custom_server_base_url"

    val DEFAULT_BASE_URL = SscamApiService.DEFAULT_BASE_URL // "https://creative.suamisihat.myds.me/"
    val DEFAULT_SERVER_URL get() = DEFAULT_BASE_URL

    fun getServerUrl(context: Context): String {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val custom = prefs.getString(KEY_CUSTOM_URL, null)?.trim()
        return if (!custom.isNullOrBlank()) {
            if (!custom.endsWith("/")) "$custom/" else custom
        } else {
            DEFAULT_BASE_URL
        }
    }

    fun isCustomUrl(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val custom = prefs.getString(KEY_CUSTOM_URL, null)?.trim()
        return !custom.isNullOrBlank() && !custom.trimEnd('/').equals(DEFAULT_BASE_URL.trimEnd('/'), ignoreCase = true)
    }

    fun isCustomServer(context: Context): Boolean = isCustomUrl(context)

    fun saveServerUrl(context: Context, url: String) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val clean = url.trim()
        if (clean.isBlank() || clean.trimEnd('/').equals(DEFAULT_BASE_URL.trimEnd('/'), ignoreCase = true)) {
            prefs.edit().remove(KEY_CUSTOM_URL).apply()
            ApiConfig.setBaseUrl(DEFAULT_BASE_URL)
        } else {
            val formatted = if (!clean.endsWith("/")) "$clean/" else clean
            prefs.edit().putString(KEY_CUSTOM_URL, formatted).apply()
            ApiConfig.setBaseUrl(formatted)
        }
    }

    fun resetToDefault(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().remove(KEY_CUSTOM_URL).apply()
        ApiConfig.setBaseUrl(DEFAULT_BASE_URL)
    }
}
