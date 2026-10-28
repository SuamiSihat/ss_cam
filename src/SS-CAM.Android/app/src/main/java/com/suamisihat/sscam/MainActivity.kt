package com.suamisihat.sscam

import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Assignment
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.suamisihat.sscam.data.api.LoginRequest
import com.suamisihat.sscam.data.api.SscamApiService
import com.suamisihat.sscam.data.sync.SyncQueueManager
import com.suamisihat.sscam.data.models.CreateProjectRequest
import com.suamisihat.sscam.data.models.ProjectStatusConstants
import com.suamisihat.sscam.data.models.CreativeOrder
import com.suamisihat.sscam.data.models.CreateOrderRequest
import com.suamisihat.sscam.data.models.DecisionRequest
import com.suamisihat.sscam.data.models.NotificationItem
import com.suamisihat.sscam.data.models.ProjectItem
import com.suamisihat.sscam.data.models.StaffMember
import com.suamisihat.sscam.ui.components.*
import com.suamisihat.sscam.ui.screens.*
import com.suamisihat.sscam.ui.theme.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : androidx.fragment.app.FragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Initialize dynamic API configuration from saved preferences
        com.suamisihat.sscam.data.api.ApiConfig.setBaseUrl(
            com.suamisihat.sscam.data.api.ServerPreferences.getServerUrl(this)
        )

        // Initialize high-priority deliverable, solat and studio notification channels
        com.suamisihat.sscam.service.SscamNotificationService.initNotificationChannels(this)

        setContent {
            val context = LocalContext.current
            var currentTheme by remember { mutableStateOf(ThemePreferences.getSavedTheme(context)) }
            var showSplash by remember { mutableStateOf(true) }

            SscamTheme(themeMode = currentTheme) {
                if (showSplash) {
                    SsHeroSplashScreen(
                        onSplashFinished = { showSplash = false }
                    )
                } else {
                    CompanionAppScreen(
                        currentTheme = currentTheme,
                        onThemeChange = {
                            currentTheme = it
                            ThemePreferences.saveTheme(context, it)
                        }
                    )
                }
            }
        }
    }
}

object AuthPreferences {
    private const val PREFS_NAME = "sscam_auth_prefs"
    private const val KEY_IS_LOGGED_IN = "is_logged_in"
    private const val KEY_USERNAME = "saved_username"
    private const val KEY_DISPLAY_NAME = "saved_display_name"
    private const val KEY_TOKEN = "saved_token"

    private fun prefs(context: android.content.Context) =
        context.getSharedPreferences(PREFS_NAME, android.content.Context.MODE_PRIVATE)

    /** Fresh installs are signed out. */
    fun isLoggedIn(context: android.content.Context): Boolean {
        return prefs(context).getBoolean(KEY_IS_LOGGED_IN, false)
    }

    /** Last username used to sign in, or "" when none is remembered. */
    fun getSavedUsername(context: android.content.Context): String {
        return prefs(context).getString(KEY_USERNAME, "") ?: ""
    }

    fun getSavedDisplayName(context: android.content.Context): String {
        return prefs(context).getString(KEY_DISPLAY_NAME, "") ?: ""
    }

    /** Session token (JWT) issued by the server. The password is never stored. */
    fun getSavedToken(context: android.content.Context): String? {
        return prefs(context).getString(KEY_TOKEN, null)?.takeIf { it.isNotBlank() }
    }

    /** True when a saved token exists and its JWT "exp" claim is still in the future. */
    fun hasValidToken(context: android.content.Context): Boolean {
        val token = getSavedToken(context) ?: return false
        return isTokenUnexpired(token)
    }

    fun isTokenUnexpired(token: String): Boolean {
        return try {
            val parts = token.split(".")
            if (parts.size < 2) return false
            val payload = String(
                android.util.Base64.decode(parts[1], android.util.Base64.URL_SAFE or android.util.Base64.NO_WRAP or android.util.Base64.NO_PADDING),
                Charsets.UTF_8
            )
            val exp = org.json.JSONObject(payload).optLong("exp", 0L)
            exp > 0L && exp * 1000L > System.currentTimeMillis()
        } catch (e: Exception) {
            android.util.Log.w("SSCAM", "Saved session token could not be read", e)
            false
        }
    }

    fun saveAuth(
        context: android.content.Context,
        username: String,
        displayName: String,
        token: String,
        isLoggedIn: Boolean
    ) {
        prefs(context).edit()
            .putBoolean(KEY_IS_LOGGED_IN, isLoggedIn)
            .putString(KEY_USERNAME, username)
            .putString(KEY_DISPLAY_NAME, displayName)
            .putString(KEY_TOKEN, token)
            .apply()
    }

    fun setLoggedIn(context: android.content.Context, isLoggedIn: Boolean) {
        prefs(context).edit().putBoolean(KEY_IS_LOGGED_IN, isLoggedIn).apply()
    }

    /** "Not you? Switch account": forget the remembered username and any session. */
    fun forgetSavedAccount(context: android.content.Context) {
        prefs(context).edit()
            .putBoolean(KEY_IS_LOGGED_IN, false)
            .remove(KEY_TOKEN)
            .remove(KEY_USERNAME)
            .remove(KEY_DISPLAY_NAME)
            .apply()
    }

    private const val KEY_BIO = "saved_bio"
    private const val KEY_EMAIL = "saved_email"

    fun getSavedBio(context: android.content.Context): String {
        return prefs(context).getString(KEY_BIO, "") ?: ""
    }

    fun saveBio(context: android.content.Context, bio: String) {
        prefs(context).edit().putString(KEY_BIO, bio).apply()
    }

    fun getSavedEmail(context: android.content.Context): String {
        return prefs(context).getString(KEY_EMAIL, "") ?: ""
    }

    fun saveEmail(context: android.content.Context, email: String) {
        prefs(context).edit().putString(KEY_EMAIL, email).apply()
    }

    /** Sign out: clears the token and the signed-in flag; the username is kept for next time. */
    fun clearAuth(context: android.content.Context) {
        prefs(context).edit()
            .putBoolean(KEY_IS_LOGGED_IN, false)
            .remove(KEY_TOKEN)
            .apply()
    }
}

object ProjectCacheManager {
    private const val PREFS_NAME = "sscam_data_cache"
    private const val KEY_PROJECTS_JSON = "cached_projects_json"
    private const val KEY_STAFF_JSON = "cached_staff_json"
    private const val KEY_ORDERS_JSON = "cached_orders_json"
    private val gson = com.google.gson.Gson()

    fun getCachedProjects(context: android.content.Context): List<ProjectItem> {
        val prefs = context.getSharedPreferences(PREFS_NAME, android.content.Context.MODE_PRIVATE)
        val json = prefs.getString(KEY_PROJECTS_JSON, null) ?: return emptyList()
        return try {
            val type = object : com.google.gson.reflect.TypeToken<List<ProjectItem>>() {}.type
            gson.fromJson(json, type) ?: emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }

    fun saveProjects(context: android.content.Context, projects: List<ProjectItem>) {
        val prefs = context.getSharedPreferences(PREFS_NAME, android.content.Context.MODE_PRIVATE)
        val json = gson.toJson(projects)
        prefs.edit().putString(KEY_PROJECTS_JSON, json).apply()
    }

    fun getCachedStaff(context: android.content.Context): List<StaffMember> {
        val prefs = context.getSharedPreferences(PREFS_NAME, android.content.Context.MODE_PRIVATE)
        val json = prefs.getString(KEY_STAFF_JSON, null) ?: return emptyList()
        return try {
            val type = object : com.google.gson.reflect.TypeToken<List<StaffMember>>() {}.type
            gson.fromJson(json, type) ?: emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }

    fun saveStaff(context: android.content.Context, staff: List<StaffMember>) {
        val prefs = context.getSharedPreferences(PREFS_NAME, android.content.Context.MODE_PRIVATE)
        val json = gson.toJson(staff)
        prefs.edit().putString(KEY_STAFF_JSON, json).apply()
    }

    fun getCachedOrders(context: android.content.Context): List<CreativeOrder> {
        val prefs = context.getSharedPreferences(PREFS_NAME, android.content.Context.MODE_PRIVATE)
        val json = prefs.getString(KEY_ORDERS_JSON, null)
        if (json != null) {
            try {
                val type = object : com.google.gson.reflect.TypeToken<List<CreativeOrder>>() {}.type
                val list: List<CreativeOrder>? = gson.fromJson(json, type)
                if (list != null && list.isNotEmpty()) return list
            } catch (e: Exception) { }
        }
        return emptyList()
    }

    fun saveOrders(context: android.content.Context, orders: List<CreativeOrder>) {
        val prefs = context.getSharedPreferences(PREFS_NAME, android.content.Context.MODE_PRIVATE)
        val json = gson.toJson(orders)
        prefs.edit().putString(KEY_ORDERS_JSON, json).apply()
    }

    private const val KEY_LIVETASKS_JSON = "cached_livetasks_json"

    fun getCachedLiveTasks(context: android.content.Context): List<com.suamisihat.sscam.data.models.LiveTaskDto> {
        val prefs = context.getSharedPreferences(PREFS_NAME, android.content.Context.MODE_PRIVATE)
        val json = prefs.getString(KEY_LIVETASKS_JSON, null) ?: return emptyList()
        return try {
            val type = object : com.google.gson.reflect.TypeToken<List<com.suamisihat.sscam.data.models.LiveTaskDto>>() {}.type
            gson.fromJson(json, type) ?: emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }

    fun saveLiveTasks(context: android.content.Context, tasks: List<com.suamisihat.sscam.data.models.LiveTaskDto>) {
        val prefs = context.getSharedPreferences(PREFS_NAME, android.content.Context.MODE_PRIVATE)
        val json = gson.toJson(tasks)
        prefs.edit().putString(KEY_LIVETASKS_JSON, json).apply()
    }

    private fun getSeedOrders(): List<CreativeOrder> {
        return emptyList()
    }
}

enum class CompanionScreen(val title: String, val icon: ImageVector) {
    Dashboard("Dashboard", Icons.Default.Home),
    Tasks("Tasks", Icons.AutoMirrored.Filled.Assignment),
    Catalog("Projects", Icons.Default.FolderOpen),
    Copy("Copy", Icons.Default.EditNote),
    Team("Team", Icons.Default.Group),
    Wellbeing("Wellbeing", Icons.Default.Spa)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CompanionAppScreen(
    currentTheme: AppThemeMode = AppThemeMode.SS_LIGHT,
    onThemeChange: (AppThemeMode) -> Unit = {}
) {
    val context = LocalContext.current
    val colors = LocalSscamColors.current
    val haptic = LocalHapticFeedback.current
    val coroutineScope = rememberCoroutineScope()

    // A session is only restored when the saved token is still valid; otherwise the user signs in again.
    val sessionExpiredMessage = "Your session has expired. Please sign in again."
    val startedWithExpiredSession = remember {
        AuthPreferences.isLoggedIn(context) && !AuthPreferences.hasValidToken(context)
    }
    var isLoggedIn by remember {
        mutableStateOf(AuthPreferences.isLoggedIn(context) && AuthPreferences.hasValidToken(context))
    }
    var activeUsername by remember { mutableStateOf(AuthPreferences.getSavedUsername(context)) }
    var savedDisplayName by remember { mutableStateOf(AuthPreferences.getSavedDisplayName(context)) }
    var isAuthenticating by remember { mutableStateOf(false) }
    var loginErrorMessage by remember {
        mutableStateOf<String?>(if (startedWithExpiredSession) sessionExpiredMessage else null)
    }

    // Held in memory only while the "Choose a new password" step is open; never persisted.
    data class PendingPasswordChange(
        val username: String,
        val displayName: String,
        val restrictedToken: String,
        val currentPassword: String,
        val rememberMe: Boolean
    )
    var pendingPasswordChange by remember { mutableStateOf<PendingPasswordChange?>(null) }
    var isChangingPassword by remember { mutableStateOf(false) }
    var passwordChangeError by remember { mutableStateOf<String?>(null) }

    var selectedScreen by remember { mutableStateOf(CompanionScreen.Dashboard) }
    var isSettingsOpen by remember { mutableStateOf(false) }
    var isNotificationsOpen by remember { mutableStateOf(false) }
    var isNowPlayingSheetOpen by remember { mutableStateOf(false) }
    var isDeskModeActive by remember { mutableStateOf(false) }

    var teamSubTab by remember { mutableStateOf(0) }
    var wellbeingSubTab by remember { mutableStateOf(0) }

    var isLiveSync by remember { mutableStateOf(false) }
    var syncMessage by remember { mutableStateOf("Connecting to Synology NAS...") }
    var isLoading by remember { mutableStateOf(true) }

    var projects by remember {
        mutableStateOf<List<ProjectItem>>(ProjectCacheManager.getCachedProjects(context))
    }
    var staffList by remember {
        mutableStateOf<List<StaffMember>>(ProjectCacheManager.getCachedStaff(context))
    }
    var orders by remember {
        mutableStateOf<List<CreativeOrder>>(ProjectCacheManager.getCachedOrders(context))
    }
    var liveTasks by remember {
        mutableStateOf<List<com.suamisihat.sscam.data.models.LiveTaskDto>>(ProjectCacheManager.getCachedLiveTasks(context))
    }
    var authToken by remember { mutableStateOf<String?>(AuthPreferences.getSavedToken(context)) }

    var notifications by remember {
        mutableStateOf<List<NotificationItem>>(emptyList())
    }

    val unreadNotifCount = remember(notifications) {
        notifications.count { !it.read }
    }

    // Ends the session locally and returns to the sign-in screen. The username is kept.
    fun endSession(message: String?) {
        AuthPreferences.clearAuth(context)
        authToken = null
        isLoggedIn = false
        isSettingsOpen = false
        loginErrorMessage = message
    }

    // Any API call that gets 401 / 403 SESSION_EXPIRED raises AuthSession.expired.
    LaunchedEffect(Unit) {
        com.suamisihat.sscam.data.api.AuthSession.expired.collect {
            if (isLoggedIn) {
                endSession(sessionExpiredMessage)
            }
        }
    }

    fun refreshLiveData() {
        // Uses the token saved at sign-in. There is no silent re-login: without a token the user must sign in.
        val token = authToken
        if (!isLoggedIn || token.isNullOrBlank()) return
        coroutineScope.launch {
            isLoading = true
            val activeServer = com.suamisihat.sscam.data.api.ServerPreferences.getServerUrl(context)
            val serverHost = try { java.net.URI(activeServer).host ?: activeServer } catch (_: Exception) { activeServer }
            syncMessage = "Syncing with $serverHost..."
            try {
                withContext(Dispatchers.IO) {
                    val api = SscamApiService.create(authToken = token)
                    try {
                        SyncQueueManager.flushQueue(context, api)
                    } catch (e: Exception) {
                        android.util.Log.w("SSCAM", "Offline queue flush failed", e)
                    }
                    val projRes = api.getProjects()
                    val teamRes = api.getTeam()
                    val liveTaskRes = try { api.getLiveTasks() } catch (e: Exception) {
                        android.util.Log.w("SSCAM", "Live tasks refresh failed", e); null
                    }
                    val orderRes = try { api.getOrders() } catch (e: Exception) {
                        android.util.Log.w("SSCAM", "Orders refresh failed", e); null
                    }
                    val notifRes = try { api.getNotifications() } catch (e: Exception) {
                        android.util.Log.w("SSCAM", "Notifications refresh failed", e); null
                    }

                    val fetchedProjects = if (projRes.isSuccessful && projRes.body() != null) {
                        projRes.body()!!.projects
                    } else emptyList()

                    val fetchedStaff = if (teamRes.isSuccessful && teamRes.body() != null) {
                        teamRes.body()!!.allStaff
                    } else emptyList()

                    val fetchedLiveTasks = if (liveTaskRes?.isSuccessful == true && liveTaskRes.body() != null) {
                        liveTaskRes.body()!!.liveTasks
                    } else emptyList()

                    val fetchedOrders = if (orderRes?.isSuccessful == true && orderRes.body() != null) {
                        orderRes.body()!!.orders
                    } else emptyList()

                    val fetchedNotifs = if (notifRes?.isSuccessful == true && notifRes.body()?.notifications?.isNotEmpty() == true) {
                        notifRes.body()!!.notifications
                    } else null

                    withContext(Dispatchers.Main) {
                        if (fetchedProjects.isNotEmpty() || fetchedStaff.isNotEmpty() || fetchedOrders.isNotEmpty() || fetchedLiveTasks.isNotEmpty()) {
                            if (fetchedProjects.isNotEmpty()) {
                                projects = fetchedProjects
                                ProjectCacheManager.saveProjects(context, fetchedProjects)
                            }
                            if (fetchedStaff.isNotEmpty()) {
                                staffList = fetchedStaff
                                ProjectCacheManager.saveStaff(context, fetchedStaff)
                            }
                            if (fetchedLiveTasks.isNotEmpty()) {
                                liveTasks = fetchedLiveTasks
                                ProjectCacheManager.saveLiveTasks(context, fetchedLiveTasks)
                            }
                            if (fetchedOrders.isNotEmpty()) {
                                orders = fetchedOrders
                                ProjectCacheManager.saveOrders(context, fetchedOrders)
                            }
                            if (fetchedNotifs != null) {
                                notifications = fetchedNotifs
                            }
                            isLiveSync = true
                            val activeLiveCount = liveTasks.count { it.isRunning }
                            val livePart = if (activeLiveCount > 0) " • $activeLiveCount active" else ""
                            syncMessage = "Live NAS Synced (${projects.size} deliverables • ${orders.size} orders$livePart)"
                        } else {
                            syncMessage = "NAS Live API: HTTP ${projRes.code()}"
                        }
                    }
                }
            } catch (e: Exception) {
                android.util.Log.w("SSCAM", "Live data refresh failed", e)
                withContext(Dispatchers.Main) {
                    syncMessage = "Synology NAS: Offline Mode"
                }
            } finally {
                withContext(Dispatchers.Main) {
                    isLoading = false
                }
            }
        }
    }

    // Poll only while signed in; restarts when the sign-in state changes.
    LaunchedEffect(isLoggedIn) {
        if (!isLoggedIn) return@LaunchedEffect
        refreshLiveData()
        while (true) {
            kotlinx.coroutines.delay(30_000)
            refreshLiveData()
        }
    }

    val currentUserProfile = remember(staffList, activeUsername) {
        staffList.find {
            it.username.equals(activeUsername, ignoreCase = true) ||
            it.name.equals(activeUsername, ignoreCase = true) ||
            it.staffId.equals(activeUsername, ignoreCase = true)
        }
    }

    val userSubsidiary = remember(currentUserProfile) {
        currentUserProfile?.defaultBrand ?: "SSH"
    }

    val userSubsidiaryName = remember(userSubsidiary) {
        when (userSubsidiary.uppercase()) {
            "SSH", "SS" -> "SuamiSihat HQ"
            "SSC" -> "SuamiSihat Clinic"
            "SSW" -> "SuamiSihat Wellness"
            "SSE" -> "SuamiSihat Enterprise"
            "SST" -> "SuamiSihat Tech"
            else -> "SuamiSihat"
        }
    }

    val currentLogoRes = remember(userSubsidiary, colors.isDark) {
        when (userSubsidiary.uppercase()) {
            "SSH", "SS" -> if (colors.isDark) R.drawable.logo_ssh_dark else R.drawable.logo_ssh_light
            "SSC" -> if (colors.isDark) R.drawable.logo_ssc_dark else R.drawable.logo_ssc_light
            "SSW" -> if (colors.isDark) R.drawable.logo_ssw_dark else R.drawable.logo_ssw_light
            "SSE" -> if (colors.isDark) R.drawable.logo_sse_dark else R.drawable.logo_sse_light
            "SST" -> if (colors.isDark) R.drawable.logo_sst_dark else R.drawable.logo_sst_light
            else -> if (colors.isDark) R.drawable.logo_ssh_dark else R.drawable.logo_ssh_light
        }
    }

    if (isDeskModeActive) {
        // High-legibility Swiss Desk Companion OLED Standby Mode
        DeskCompanionMode(
            activeProjects = projects,
            onExit = { isDeskModeActive = false }
        )
    } else if (!isLoggedIn) {
        // Saves the full session token and enters the app. rememberMe controls whether the
        // session is restored on the next app launch; the password is never stored.
        fun completeSignIn(username: String, displayName: String, token: String, rememberMe: Boolean) {
            AuthPreferences.saveAuth(context, username, displayName, token, isLoggedIn = rememberMe)
            activeUsername = username
            savedDisplayName = displayName
            authToken = token
            loginErrorMessage = null
            isLoggedIn = true
        }

        LoginScreen(
            savedUsername = activeUsername,
            savedDisplayName = savedDisplayName,
            isLoading = isAuthenticating,
            errorMessage = loginErrorMessage,
            onSwitchAccount = {
                AuthPreferences.forgetSavedAccount(context)
                activeUsername = ""
                savedDisplayName = ""
                authToken = null
                loginErrorMessage = null
            },
            onBiometricLogin = {
                // Biometrics can only unlock an existing, unexpired session saved on this device.
                val savedToken = AuthPreferences.getSavedToken(context)
                val savedUser = AuthPreferences.getSavedUsername(context)
                val activity = context as? androidx.fragment.app.FragmentActivity
                if (savedToken == null || savedUser.isBlank() || !AuthPreferences.isTokenUnexpired(savedToken)) {
                    loginErrorMessage = "Sign in with your password first."
                } else if (activity == null || !com.suamisihat.sscam.util.BiometricAuthManager.isBiometricAvailable(context)) {
                    loginErrorMessage = "Fingerprint or face unlock isn't set up on this device. Sign in with your password."
                } else {
                    com.suamisihat.sscam.util.BiometricAuthManager.promptBiometric(
                        activity = activity,
                        onSuccess = {
                            AuthPreferences.setLoggedIn(context, true)
                            activeUsername = savedUser
                            authToken = savedToken
                            loginErrorMessage = null
                            isLoggedIn = true
                        },
                        onError = { err ->
                            loginErrorMessage = err
                        }
                    )
                }
            },
            onLogin = { username, password, rememberMe ->
                coroutineScope.launch {
                    isAuthenticating = true
                    loginErrorMessage = null
                    try {
                        val res = withContext(Dispatchers.IO) {
                            SscamApiService.create().login(LoginRequest(username = username, password = password))
                        }
                        val body = res.body()
                        val token = body?.token
                        if (res.isSuccessful && body != null && body.success && !token.isNullOrBlank()) {
                            val canonicalUsername = body.user?.username?.takeIf { it.isNotBlank() } ?: username
                            val displayName = body.user?.name?.takeIf { it.isNotBlank() } ?: canonicalUsername
                            if (body.mustChangePassword) {
                                passwordChangeError = null
                                pendingPasswordChange = PendingPasswordChange(
                                    username = canonicalUsername,
                                    displayName = displayName,
                                    restrictedToken = token,
                                    currentPassword = password,
                                    rememberMe = rememberMe
                                )
                            } else {
                                completeSignIn(canonicalUsername, displayName, token, rememberMe)
                            }
                        } else {
                            android.util.Log.w("SSCAM", "Sign in failed: HTTP ${res.code()}")
                            loginErrorMessage = when (res.code()) {
                                401 -> "Username or password is incorrect."
                                429 -> "Too many attempts. Wait a minute and try again."
                                else -> "Sign in isn't available right now. Try again later."
                            }
                        }
                    } catch (e: java.io.IOException) {
                        android.util.Log.w("SSCAM", "Sign in failed: server unreachable", e)
                        loginErrorMessage = "Can't reach the server. Check your connection."
                    } catch (e: Exception) {
                        android.util.Log.w("SSCAM", "Sign in failed", e)
                        loginErrorMessage = "Something went wrong. Try again."
                    } finally {
                        isAuthenticating = false
                    }
                }
            }
        )

        pendingPasswordChange?.let { pending ->
            ChangePasswordDialog(
                isSaving = isChangingPassword,
                errorMessage = passwordChangeError,
                onDismiss = {
                    if (!isChangingPassword) {
                        pendingPasswordChange = null
                        passwordChangeError = null
                    }
                },
                onSubmit = { newPassword ->
                    coroutineScope.launch {
                        isChangingPassword = true
                        passwordChangeError = null
                        try {
                            val res = withContext(Dispatchers.IO) {
                                SscamApiService.create(authToken = pending.restrictedToken).changePassword(
                                    com.suamisihat.sscam.data.api.ChangePasswordRequest(
                                        currentPassword = pending.currentPassword,
                                        newPassword = newPassword
                                    )
                                )
                            }
                            val body = res.body()
                            val fullToken = body?.token
                            if (res.isSuccessful && body != null && !fullToken.isNullOrBlank()) {
                                val username = body.user?.username?.takeIf { it.isNotBlank() } ?: pending.username
                                val displayName = body.user?.name?.takeIf { it.isNotBlank() } ?: pending.displayName
                                pendingPasswordChange = null
                                completeSignIn(username, displayName, fullToken, pending.rememberMe)
                                Toast.makeText(context, "Password changed.", Toast.LENGTH_SHORT).show()
                            } else {
                                android.util.Log.w("SSCAM", "Change password failed: HTTP ${res.code()}")
                                val serverMessage = withContext(Dispatchers.IO) {
                                    try {
                                        res.errorBody()?.string()?.let { org.json.JSONObject(it).optString("error", "") }
                                    } catch (e: Exception) {
                                        android.util.Log.w("SSCAM", "Could not read change-password error", e)
                                        null
                                    }
                                }
                                when (res.code()) {
                                    400 -> passwordChangeError = if (!serverMessage.isNullOrBlank()) serverMessage
                                        else "That password can't be used. Choose a different one."
                                    429 -> passwordChangeError = "Too many attempts. Wait a minute and try again."
                                    401, 403 -> {
                                        // The temporary sign-in has lapsed; start again from the sign-in screen.
                                        pendingPasswordChange = null
                                        loginErrorMessage = sessionExpiredMessage
                                    }
                                    else -> passwordChangeError = "Couldn't change your password right now. Try again later."
                                }
                            }
                        } catch (e: java.io.IOException) {
                            android.util.Log.w("SSCAM", "Change password failed: server unreachable", e)
                            passwordChangeError = "Can't reach the server. Check your connection."
                        } catch (e: Exception) {
                            android.util.Log.w("SSCAM", "Change password failed", e)
                            passwordChangeError = "Something went wrong. Try again."
                        } finally {
                            isChangingPassword = false
                        }
                    }
                }
            )
        }
    } else if (isDeskModeActive) {
        DeskCompanionMode(
            activeProjects = projects,
            liveTasks = liveTasks,
            onExit = { isDeskModeActive = false }
        )
    } else {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = {
                        if (isSettingsOpen) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(
                                    text = "Settings & Preferences",
                                    fontSize = 18.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = colors.textPrimary
                                )
                            }
                        } else {
                            // Official SuamiSihat Dual-S Logomark (Theme Adaptive)
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier.padding(vertical = 2.dp)
                            ) {
                                androidx.compose.foundation.Image(
                                    painter = androidx.compose.ui.res.painterResource(
                                        id = if (colors.isDark) R.drawable.ic_suamisihat_mark_dark else R.drawable.ic_suamisihat_mark_light
                                    ),
                                    contentDescription = "SuamiSihat Logomark",
                                    colorFilter = if (colors.isMonochrome) androidx.compose.ui.graphics.ColorFilter.colorMatrix(androidx.compose.ui.graphics.ColorMatrix().apply { setToSaturation(0f) }) else null,
                                    modifier = Modifier
                                        .size(30.dp)
                                        .clickable(
                                            interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() },
                                            indication = null
                                        ) {
                                            selectedScreen = CompanionScreen.Dashboard
                                            isSettingsOpen = false
                                        },
                                    contentScale = androidx.compose.ui.layout.ContentScale.Fit
                                )

                                // Header: Now Playing Radio (if active) OR Official Brand Title
                                if (StudioRadioManager.isPlaying) {
                                    Surface(
                                        onClick = { isNowPlayingSheetOpen = true },
                                        shape = RoundedCornerShape(14.dp),
                                        color = if (colors.isDark) Color(0xFF1E293B) else Color(0xFFEFF6FF),
                                        border = androidx.compose.foundation.BorderStroke(
                                            1.dp,
                                            if (colors.isDark) SshWarmGoldBright.copy(alpha = 0.5f) else SshAzure.copy(alpha = 0.5f)
                                        ),
                                        modifier = Modifier.padding(start = 8.dp)
                                    ) {
                                        Row(
                                            verticalAlignment = Alignment.CenterVertically,
                                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 5.dp)
                                        ) {
                                            AnimatedEqualizerBars(
                                                isAnimating = true,
                                                color = if (colors.isDark) SshWarmGoldBright else SshAzure
                                            )
                                            Text(
                                                text = StudioRadioManager.currentTrackTitle,
                                                fontSize = 11.5.sp,
                                                fontWeight = FontWeight.Bold,
                                                color = if (colors.isDark) SshWarmGoldBright else SshAzure,
                                                maxLines = 1,
                                                overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
                                                modifier = Modifier.widthIn(max = 180.dp)
                                            )
                                        }
                                    }
                                } else {
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text(
                                        text = "SuamiSihat",
                                        fontSize = 16.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = colors.textPrimary,
                                        maxLines = 1,
                                        overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis
                                    )
                                }
                            }
                        }
                    },
                    navigationIcon = {
                        if (isSettingsOpen) {
                            IconButton(onClick = { isSettingsOpen = false }) {
                                Icon(
                                    Icons.AutoMirrored.Filled.ArrowBack,
                                    contentDescription = "Back",
                                    tint = colors.textPrimary
                                )
                            }
                        }
                    },
                    actions = {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp),
                            modifier = Modifier.padding(end = 12.dp)
                        ) {

                            // Notification Bell with Badge
                            Box(
                                contentAlignment = Alignment.TopEnd,
                                modifier = Modifier.size(36.dp)
                            ) {
                                IconButton(
                                    onClick = { isNotificationsOpen = true },
                                    modifier = Modifier.size(36.dp)
                                ) {
                                    Icon(
                                        Icons.Default.Notifications,
                                        contentDescription = "Notifications",
                                        tint = colors.textPrimary,
                                        modifier = Modifier.size(18.dp)
                                    )
                                }
                                if (unreadNotifCount > 0) {
                                    Box(
                                        modifier = Modifier
                                            .size(8.dp)
                                            .clip(CircleShape)
                                            .background(if (colors.isMonochrome) Color(0xFF18181B) else colors.accent)
                                    )
                                }
                            }

                            Spacer(modifier = Modifier.width(2.dp))

                            // Profile Avatar -> Toggles Swiss Editorial Profile
                            UserProfileAvatar(
                                imageUrl = currentUserProfile?.profileImageUrl,
                                initials = currentUserProfile?.name ?: savedDisplayName.ifBlank { activeUsername },
                                avatarColorHex = currentUserProfile?.avatarColor ?: "#0078D4",
                                size = 36.dp,
                                onClick = { isSettingsOpen = !isSettingsOpen }
                            )
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(containerColor = colors.surface)
                )
            },
            bottomBar = {
                // Tactile Skeuomorphic Console Dock with Spring Pill Physics
                Surface(
                    color = colors.surface,
                    border = BorderStroke(1.2.dp, colors.border),
                    shadowElevation = if (colors.isMonochrome) 0.dp else 10.dp,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Box(modifier = Modifier.fillMaxWidth()) {
                        // Top Specular Highlight Bevel
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(2.dp)
                                .background(TactileBevelLight)
                        )

                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .navigationBarsPadding()
                                .padding(horizontal = 8.dp, vertical = 6.dp),
                            horizontalArrangement = Arrangement.SpaceAround,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            CompanionScreen.entries.forEach { screen ->
                                val isSelected = !isSettingsOpen && selectedScreen == screen

                                if (isSelected) {
                                    // Active Item: Tactile Extruded Pill with Label
                                    Box(
                                        modifier = Modifier
                                            .clip(RoundedCornerShape(20.dp))
                                            .background(colors.activePillBg)
                                            .border(1.dp, if (colors.isMonochrome) Color(0xFF27272A) else Color.White.copy(alpha = 0.25f), RoundedCornerShape(20.dp))
                                            .animateContentSize(
                                                animationSpec = spring(
                                                    dampingRatio = Spring.DampingRatioLowBouncy,
                                                    stiffness = Spring.StiffnessMediumLow
                                                )
                                            )
                                            .padding(horizontal = 12.dp, vertical = 7.dp)
                                    ) {
                                        Row(
                                            verticalAlignment = Alignment.CenterVertically,
                                            horizontalArrangement = Arrangement.spacedBy(5.dp)
                                        ) {
                                            Icon(
                                                screen.icon,
                                                contentDescription = screen.title,
                                                tint = colors.activePillTint,
                                                modifier = Modifier.size(17.dp)
                                            )
                                            Text(
                                                text = screen.title,
                                                fontSize = 11.sp,
                                                fontWeight = FontWeight.Bold,
                                                color = colors.activePillTint
                                            )
                                        }
                                    }
                                } else {
                                    // Inactive Item: Tactile Sunken Touch Well
                                    Box(
                                        modifier = Modifier
                                            .clip(CircleShape)
                                            .clickable {
                                                haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                                isSettingsOpen = false
                                                selectedScreen = screen
                                            }
                                            .padding(horizontal = 8.dp, vertical = 8.dp),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Icon(
                                            screen.icon,
                                            contentDescription = screen.title,
                                            tint = if (colors.isDark) Color(0xFF94A3B8) else Color(0xFF0F172A),
                                            modifier = Modifier.size(20.dp)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            },
            containerColor = colors.background
        ) { padding ->
            Box(modifier = Modifier.padding(padding)) {
                if (isSettingsOpen) {
                    SettingsProfileScreen(
                        currentTheme = currentTheme,
                        currentUserProfile = currentUserProfile,
                        projects = projects,
                        onThemeSelected = onThemeChange,
                        onSignOut = {
                            // Clears the token and the signed-in flag; the username is remembered.
                            endSession(null)
                            Toast.makeText(context, "You're signed out.", Toast.LENGTH_SHORT).show()
                        }
                    )
                } else {
                    FluentPullToRefresh(
                        isRefreshing = isLoading,
                        onRefresh = { refreshLiveData() }
                    ) {
                        when (selectedScreen) {
                            CompanionScreen.Dashboard -> DashboardCompanionScreen(
                                projects = projects,
                                syncMessage = syncMessage,
                                isLiveSync = isLiveSync,
                                onNavigateDestination = { destination, subTab ->
                                    when (destination) {
                                        "Tasks" -> {
                                            selectedScreen = CompanionScreen.Tasks
                                        }
                                        "Team" -> {
                                            teamSubTab = subTab
                                            selectedScreen = CompanionScreen.Team
                                        }
                                        "Wellbeing" -> {
                                            wellbeingSubTab = subTab
                                            selectedScreen = CompanionScreen.Wellbeing
                                        }
                                    }
                                },
                                onSignOff = { item ->
                                    // Optimistic local state update (0ms instant response)
                                    projects = projects.map {
                                        if (it.id == item.id) it.copy(status = ProjectStatusConstants.APPROVED) else it
                                    }
                                    coroutineScope.launch {
                                        val req = DecisionRequest("approved", "1-tap companion signoff", activeUsername)
                                        try {
                                            val api = SscamApiService.create(authToken = authToken)
                                            api.submitDecision(item.id, req)
                                            Toast.makeText(context, "Signed off ${item.title}!", Toast.LENGTH_SHORT).show()
                                            refreshLiveData()
                                        } catch (e: Exception) {
                                            SyncQueueManager.queueDecision(context, item.id, req)
                                            Toast.makeText(context, "Queued offline: Sign-off recorded for ${item.title}", Toast.LENGTH_SHORT).show()
                                        }
                                    }
                                },
                                orders = orders,
                                onUpdateOrderStatus = { orderId, newStatus ->
                                    orders = orders.map { if (it.id == orderId) it.copy(status = newStatus) else it }
                                    ProjectCacheManager.saveOrders(context, orders)
                                    Toast.makeText(context, "Status updated to ${newStatus.replace('_', ' ').replaceFirstChar { it.uppercase() }}", Toast.LENGTH_SHORT).show()
                                    coroutineScope.launch {
                                        try {
                                            withContext(Dispatchers.IO) {
                                                val api = SscamApiService.create(authToken = authToken)
                                                api.updateOrderStatus(orderId, mapOf("status" to newStatus))
                                            }
                                        } catch (e: Exception) { }
                                    }
                                },
                                onSubmitNewOrder = { req ->
                                    val now = java.util.Date()
                                    val localId = "ORD-" + java.text.SimpleDateFormat("yyMMdd", java.util.Locale.US).format(now) + "-" + (1000..9999).random()
                                    val newOrder = CreativeOrder(
                                        id = localId,
                                        title = req.title,
                                        entity = req.entity,
                                        priority = req.priority,
                                        format = req.format,
                                        copy = req.copy,
                                        targetDate = req.targetDate,
                                        attachmentNote = req.attachmentNote,
                                        requester = req.requester,
                                        requesterRole = req.requesterRole,
                                        status = "pending",
                                        submittedAt = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", java.util.Locale.US).format(now),
                                        createdDate = req.createdDate,
                                        startDate = req.startDate,
                                        deadline = req.deadline,
                                        duration = req.duration
                                    )
                                    orders = listOf(newOrder) + orders
                                    ProjectCacheManager.saveOrders(context, orders)
                                    Toast.makeText(context, "Creative request queued: ${req.title}", Toast.LENGTH_SHORT).show()
                                    coroutineScope.launch {
                                        try {
                                            withContext(Dispatchers.IO) {
                                                val api = SscamApiService.create(authToken = authToken)
                                                api.submitOrder(req)
                                            }
                                            refreshLiveData()
                                        } catch (e: Exception) { }
                                    }
                                }
                            )
                            CompanionScreen.Tasks -> TaskManagerScreen(
                                projects = projects,
                                onSignOff = { item ->
                                    // Optimistic local state update (0ms instant response)
                                    projects = projects.map {
                                        if (it.id == item.id) it.copy(status = ProjectStatusConstants.APPROVED) else it
                                    }
                                    coroutineScope.launch {
                                        val req = DecisionRequest("approved", "1-tap companion signoff", activeUsername)
                                        try {
                                            val api = SscamApiService.create(authToken = authToken)
                                            api.submitDecision(item.id, req)
                                            Toast.makeText(context, "Signed off ${item.title}!", Toast.LENGTH_SHORT).show()
                                            refreshLiveData()
                                        } catch (e: Exception) {
                                            SyncQueueManager.queueDecision(context, item.id, req)
                                            Toast.makeText(context, "Queued offline: Sign-off recorded for ${item.title}", Toast.LENGTH_SHORT).show()
                                        }
                                    }
                                },
                                onRevise = { item ->
                                    // Optimistic local state update
                                    projects = projects.map {
                                        if (it.id == item.id) it.copy(status = "revision_requested") else it
                                    }
                                    coroutineScope.launch {
                                        val req = DecisionRequest("revision_requested", "Companion revision request", activeUsername)
                                        try {
                                            val api = SscamApiService.create(authToken = authToken)
                                            api.submitDecision(item.id, req)
                                            Toast.makeText(context, "Revision requested for ${item.title}", Toast.LENGTH_SHORT).show()
                                            refreshLiveData()
                                        } catch (e: Exception) {
                                            SyncQueueManager.queueDecision(context, item.id, req)
                                            Toast.makeText(context, "Queued offline: Revision requested for ${item.title}", Toast.LENGTH_SHORT).show()
                                        }
                                    }
                                },
                                onUpdateProjectStatus = { projectId, newStatus ->
                                    val apiStatus = ProjectStatusConstants.toCanonical(newStatus)
                                    projects = projects.map {
                                        if (it.id == projectId) it.copy(status = apiStatus) else it
                                    }
                                    coroutineScope.launch {
                                        try {
                                            val api = SscamApiService.create(authToken = authToken)
                                            api.updateProject(projectId, mapOf("status" to apiStatus))
                                            Toast.makeText(context, "Status updated to $apiStatus", Toast.LENGTH_SHORT).show()
                                            refreshLiveData()
                                        } catch (e: Exception) {
                                            android.util.Log.w("SSCAM", "Status update failed", e)
                                            Toast.makeText(context, "Couldn't update the status. Please try again.", Toast.LENGTH_SHORT).show()
                                        }
                                    }
                                },
                                onSaveReadme = { projectId, newReadme ->
                                    coroutineScope.launch {
                                        try {
                                            val api = SscamApiService.create(authToken = authToken)
                                            api.updateProject(projectId, mapOf("body" to newReadme))
                                            Toast.makeText(context, "README synced with NAS storage", Toast.LENGTH_SHORT).show()
                                            refreshLiveData()
                                        } catch (e: Exception) {
                                            android.util.Log.w("SSCAM", "README sync failed", e)
                                            Toast.makeText(context, "Couldn't save the brief. Please try again.", Toast.LENGTH_SHORT).show()
                                        }
                                    }
                                },
                                onUpdateSubtasks = { projectId, newSubtasks ->
                                    projects = projects.map {
                                        if (it.id == projectId) it.copy(subtasks = newSubtasks) else it
                                    }
                                    coroutineScope.launch {
                                        try {
                                            val api = SscamApiService.create(authToken = authToken)
                                            val subtasksPayload = newSubtasks.map { st ->
                                                mapOf(
                                                    "id" to st.id,
                                                    "name" to st.name,
                                                    "type" to st.type,
                                                    "weight" to st.weight,
                                                    "status" to st.status,
                                                    "specs" to st.specs,
                                                    "designer" to st.designer
                                                )
                                            }
                                            api.updateProject(projectId, mapOf("subtasks" to subtasksPayload))
                                            Toast.makeText(context, "Deliverables updated", Toast.LENGTH_SHORT).show()
                                            refreshLiveData()
                                        } catch (e: Exception) {
                                            android.util.Log.w("SSCAM", "Subtask sync failed", e)
                                            Toast.makeText(context, "Couldn't save the subtask. Please try again.", Toast.LENGTH_SHORT).show()
                                        }
                                    }
                                },
                                onCreateNewTask = { title, desc, brand, priority ->
                                    // Same default as the web portal: deadline one week from today.
                                    val defaultDeadline = java.time.LocalDate.now().plusDays(7).toString()
                                    coroutineScope.launch {
                                        try {
                                            val api = SscamApiService.create(authToken = authToken)
                                            val res = api.createProject(
                                                CreateProjectRequest(
                                                    title = title,
                                                    brand = brand,
                                                    designer = currentUserProfile?.name ?: "Unassigned",
                                                    priority = priority,
                                                    department = "Creative Production",
                                                    deadline = defaultDeadline
                                                )
                                            )
                                            if (res.isSuccessful && res.body() != null) {
                                                projects = listOf(res.body()!!) + projects
                                            } else {
                                                val newProj = ProjectItem(
                                                    id = "proj_" + System.currentTimeMillis(),
                                                    title = title,
                                                    brand = brand,
                                                    status = ProjectStatusConstants.BACKLOG,
                                                    priority = priority,
                                                    designer = currentUserProfile?.name ?: "Unassigned",
                                                    deadline = defaultDeadline
                                                )
                                                projects = listOf(newProj) + projects
                                            }
                                            Toast.makeText(context, "Project created: $title", Toast.LENGTH_SHORT).show()
                                            refreshLiveData()
                                        } catch (e: Exception) {
                                            val newProj = ProjectItem(
                                                id = "proj_" + System.currentTimeMillis(),
                                                title = title,
                                                brand = brand,
                                                status = ProjectStatusConstants.BACKLOG,
                                                priority = priority,
                                                designer = currentUserProfile?.name ?: "Unassigned",
                                                deadline = defaultDeadline
                                            )
                                            projects = listOf(newProj) + projects
                                            Toast.makeText(context, "You're offline. \"$title\" isn't saved to the server yet.", Toast.LENGTH_LONG).show()
                                        }
                                    }
                                }
                            )
                            CompanionScreen.Catalog -> ProjectCatalogScreen(
                                projects = projects,
                                onSelectProject = { /* inspected */ }
                            )
                            CompanionScreen.Copy -> CopywritingStudioScreen()
                            CompanionScreen.Team -> TeamHubScreen(
                                staffList = staffList,
                                projects = projects,
                                liveTasks = liveTasks,
                                initialSubTab = teamSubTab
                            )
                            CompanionScreen.Wellbeing -> WellbeingHubScreen(
                                initialSubTab = wellbeingSubTab,
                                onLaunchDeskMode = { isDeskModeActive = true }
                            )
                        }
                    }
                }

                // Notifications Bottom Sheet
                if (isNotificationsOpen) {
                    NotificationsBottomSheet(
                        notifications = notifications,
                        onDismiss = { isNotificationsOpen = false },
                        onNotificationClick = { notif ->
                            isNotificationsOpen = false
                            // Mark as read
                            notifications = notifications.map { if (it.id == notif.id) it.copy(read = true) else it }
                            // Navigate to Tasks if related
                            if (notif.type == "approval" || notif.type == "revision" || notif.type == "brief") {
                                selectedScreen = CompanionScreen.Tasks
                            }
                        },
                        onMarkAllAsRead = {
                            notifications = notifications.map { it.copy(read = true) }
                            Toast.makeText(context, "All notifications marked as read", Toast.LENGTH_SHORT).show()
                        }
                    )
                }

                // Now Playing Radio Bottom Sheet & Station Playlist
                if (isNowPlayingSheetOpen) {
                    NowPlayingRadioBottomSheet(
                        onDismiss = { isNowPlayingSheetOpen = false },
                        onOpenFullRadio = {
                            isNowPlayingSheetOpen = false
                            selectedScreen = CompanionScreen.Wellbeing
                            wellbeingSubTab = 2 // Radio tab
                        }
                    )
                }
            }
        }
    }
}
