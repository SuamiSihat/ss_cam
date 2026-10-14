package com.suamisihat.sscam.data.api

import com.google.gson.annotations.SerializedName
import com.suamisihat.sscam.data.models.*
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Response
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.*
import java.util.concurrent.TimeUnit

/** Sign-in request. The password is required; the server rejects password-less sign-in. */
data class LoginRequest(
    @SerializedName("username") val username: String,
    @SerializedName("password") val password: String
)

/** The signed-in user as returned by api/auth/login and api/auth/change-password. */
data class AuthUser(
    @SerializedName("username") val username: String? = null,
    @SerializedName("name") val name: String? = null,
    @SerializedName("staffId") val staffId: String? = null,
    @SerializedName("role") val role: String? = null
)

data class LoginResponse(
    @SerializedName("success") val success: Boolean,
    @SerializedName("token") val token: String? = null,
    @SerializedName("user") val user: AuthUser? = null,
    @SerializedName("mustChangePassword") val mustChangePassword: Boolean = false,
    @SerializedName("error") val error: String? = null
)

data class ChangePasswordRequest(
    @SerializedName("currentPassword") val currentPassword: String,
    @SerializedName("newPassword") val newPassword: String
)

data class ChangePasswordResponse(
    @SerializedName("success") val success: Boolean = false,
    @SerializedName("message") val message: String? = null,
    @SerializedName("token") val token: String? = null,
    @SerializedName("user") val user: AuthUser? = null,
    @SerializedName("error") val error: String? = null
)

/**
 * App-wide signal raised when the server rejects the saved session token
 * (401, or 403 with code SESSION_EXPIRED). The main screen listens for it and
 * returns the user to the sign-in screen.
 */
object AuthSession {
    private val _expired = kotlinx.coroutines.flow.MutableSharedFlow<Unit>(
        extraBufferCapacity = 1,
        onBufferOverflow = kotlinx.coroutines.channels.BufferOverflow.DROP_OLDEST
    )
    val expired: kotlinx.coroutines.flow.SharedFlow<Unit> = _expired

    fun notifyExpired() {
        _expired.tryEmit(Unit)
    }

    /** True when an authenticated response means the token is no longer accepted. */
    fun isSessionRejected(code: Int, body: String?): Boolean {
        if (code == 401) return true
        return code == 403 && body?.contains("SESSION_EXPIRED") == true
    }
}

data class NoteItemDto(
    @SerializedName("id") val id: String,
    @SerializedName("filename") val filename: String? = null,
    @SerializedName("title") val title: String,
    @SerializedName("body") val body: String,
    @SerializedName("isPinned") val isPinned: Boolean = false,
    @SerializedName("priority") val priority: String = "normal",
    @SerializedName("modified") val modified: Double = 0.0,
    @SerializedName("dateText") val dateText: String = ""
)

data class NotesResponse(
    @SerializedName("success") val success: Boolean,
    @SerializedName("notes") val notes: List<NoteItemDto> = emptyList()
)

data class CreateNoteRequest(
    @SerializedName("id") val id: String? = null,
    @SerializedName("title") val title: String,
    @SerializedName("body") val body: String,
    @SerializedName("isPinned") val isPinned: Boolean = false,
    @SerializedName("priority") val priority: String = "normal",
    @SerializedName("user") val user: String? = null
)

interface SscamApiService {

    @POST("api/auth/login")
    suspend fun login(@Body request: LoginRequest): Response<LoginResponse>

    /** Accepts the restricted token issued when mustChangePassword is true. */
    @POST("api/auth/change-password")
    suspend fun changePassword(@Body request: ChangePasswordRequest): Response<ChangePasswordResponse>

    @GET("api/dashboard")
    suspend fun getDashboardSummary(): Response<DashboardSummary>

    @GET("api/projects")
    suspend fun getProjects(
        @Query("brand") brand: String? = null,
        @Query("status") status: String? = null
    ): Response<ProjectsResponse>

    @POST("api/projects")
    suspend fun createProject(
        @Body request: CreateProjectRequest
    ): Response<ProjectItem>

    @PUT("api/projects/{id}")
    suspend fun updateProject(
        @Path("id") projectId: String,
        @Body updates: Map<String, @JvmSuppressWildcards Any?>
    ): Response<Map<String, Any>>

    @GET("api/deliverables")
    suspend fun getDeliverables(
        @Query("projectId") projectId: String? = null
    ): Response<List<DeliverableItem>>

    @GET("api/team")
    suspend fun getTeam(): Response<TeamResponse>

    @GET("api/team/live-tasks")
    suspend fun getLiveTasks(): Response<LiveTasksResponse>

    @POST("api/projects/{id}/decision")
    suspend fun submitDecision(
        @Path("id") projectId: String,
        @Body request: DecisionRequest
    ): Response<Unit>

    @GET("api/projects/{id}/comments")
    suspend fun getProjectComments(
        @Path("id") projectId: String
    ): Response<CommentsResponse>

    @GET("api/notifications")
    suspend fun getNotifications(): Response<NotificationsResponse>

    @GET("api/notes")
    suspend fun getNotes(): Response<NotesResponse>

    @POST("api/notes")
    suspend fun createNote(
        @Body request: CreateNoteRequest
    ): Response<Unit>

    @DELETE("api/notes/{id}")
    suspend fun deleteNote(
        @Path("id") noteId: String
    ): Response<Unit>

    @GET("api/orders")
    suspend fun getOrders(
        @Query("status") status: String? = null,
        @Query("entity") entity: String? = null,
        @Query("priority") priority: String? = null
    ): Response<OrdersResponse>

    @POST("api/orders")
    suspend fun submitOrder(
        @Body request: CreateOrderRequest
    ): Response<Map<String, Any>>

    @PATCH("api/orders/{id}")
    suspend fun updateOrderStatus(
        @Path("id") orderId: String,
        @Body patch: Map<String, String>
    ): Response<Unit>

    companion object {
        const val DEFAULT_BASE_URL = "https://creative.suamisihat.myds.me/"

        fun create(
            baseUrl: String? = null,
            authToken: String? = null,
            context: android.content.Context? = null
        ): SscamApiService {
            val targetUrl = when {
                !baseUrl.isNullOrBlank() -> if (!baseUrl.endsWith("/")) "$baseUrl/" else baseUrl
                context != null -> ServerPreferences.getServerUrl(context)
                else -> ApiConfig.getBaseUrl()
            }

            val logging = HttpLoggingInterceptor().apply {
                level = HttpLoggingInterceptor.Level.BASIC
            }

            val client = OkHttpClient.Builder()
                .connectTimeout(15, TimeUnit.SECONDS)
                .readTimeout(20, TimeUnit.SECONDS)
                .addInterceptor(logging)
                .addInterceptor { chain ->
                    val requestBuilder = chain.request().newBuilder()
                    if (!authToken.isNullOrBlank()) {
                        requestBuilder.addHeader("Authorization", "Bearer $authToken")
                    }
                    val response = chain.proceed(requestBuilder.build())
                    if (!authToken.isNullOrBlank() && (response.code == 401 || response.code == 403)) {
                        val peek = try {
                            response.peekBody(4096).string()
                        } catch (e: java.io.IOException) {
                            android.util.Log.w("SSCAM", "Could not read auth error body", e)
                            null
                        }
                        if (AuthSession.isSessionRejected(response.code, peek)) {
                            AuthSession.notifyExpired()
                        }
                    }
                    response
                }
                .build()

            return Retrofit.Builder()
                .baseUrl(targetUrl)
                .client(client)
                .addConverterFactory(GsonConverterFactory.create())
                .build()
                .create(SscamApiService::class.java)
        }
    }
}

/**
 * In-memory global API configuration for dynamic server switching at runtime.
 */
object ApiConfig {
    @Volatile
    private var customBaseUrl: String? = null

    fun setBaseUrl(url: String?) {
        customBaseUrl = url?.trim()?.let { if (!it.endsWith("/")) "$it/" else it }
    }

    fun getBaseUrl(): String {
        return customBaseUrl ?: SscamApiService.DEFAULT_BASE_URL
    }
}
