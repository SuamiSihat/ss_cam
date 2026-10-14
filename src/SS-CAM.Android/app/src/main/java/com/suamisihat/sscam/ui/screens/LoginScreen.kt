package com.suamisihat.sscam.ui.screens

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.suamisihat.sscam.R
import androidx.compose.foundation.selection.toggleable
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import com.suamisihat.sscam.ui.components.UserProfileAvatar
import com.suamisihat.sscam.ui.theme.*
import kotlin.math.cos
import kotlin.math.sin

/**
 * SuamiSihat Hero Login Screen
 * Features the signature SuamiSihat Hero Mesh animated glowing backdrop with floating Logomarks
 * and Men's Symbols (Mars ♂), official SuamiSihat vector logomark header, a typed username
 * (or "Continue as" a remembered account) and password sign-in.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LoginScreen(
    savedUsername: String = "",
    savedDisplayName: String = "",
    isLoading: Boolean = false,
    errorMessage: String? = null,
    onLogin: (username: String, password: String, rememberMe: Boolean) -> Unit,
    onBiometricLogin: () -> Unit = {},
    onSwitchAccount: () -> Unit = {}
) {
    val haptic = LocalHapticFeedback.current
    val scrollState = rememberScrollState()

    // "Continue as" mode when a username is remembered on this device.
    val isContinueMode = savedUsername.isNotBlank()
    var typedUsername by remember(savedUsername) { mutableStateOf("") }
    var password by remember(savedUsername) { mutableStateOf("") }
    var showPassword by remember { mutableStateOf(false) }
    var rememberMe by remember { mutableStateOf(true) }

    val usernameToSubmit = if (isContinueMode) savedUsername else typedUsername.trim()
    val canSubmit = !isLoading && usernameToSubmit.isNotBlank() && password.isNotBlank()
    val continueName = savedDisplayName.ifBlank { savedUsername }

    val passwordFocusRequester = remember { FocusRequester() }

    fun submit() {
        if (canSubmit) onLogin(usernameToSubmit, password, rememberMe)
    }

    // Animated Hero Aura, Wave Phase & Particle Drift
    val infiniteTransition = rememberInfiniteTransition(label = "heroMeshPulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 0.92f,
        targetValue = 1.08f,
        animationSpec = infiniteRepeatable(
            animation = tween(4000, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulseScale"
    )

    val wavePhase by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = (2 * Math.PI).toFloat(),
        animationSpec = infiniteRepeatable(
            animation = tween(6000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "wavePhase"
    )

    val driftProgress by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(12000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "driftProgress"
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                brush = Brush.verticalGradient(
                    colors = listOf(
                        Color(0xFF022057), // Deep Cobalt Navy
                        Color(0xFF043388), // Royal Azure
                        Color(0xFF021233)  // Midnight Studio Abyss
                    )
                )
            )
    ) {
        // ── 1. Animated Hero Wave & Ambient Glowing Aura Canvas with Logomark & Men's Symbols ──
        Canvas(modifier = Modifier.fillMaxSize()) {
            val w = size.width
            val h = size.height

            // Ambient Radial Glow 1 (Azure Cyan at top center)
            drawCircle(
                brush = Brush.radialGradient(
                    colors = listOf(
                        Color(0xFF21A1F7).copy(alpha = 0.30f * pulseScale),
                        Color(0xFF0078D4).copy(alpha = 0.14f),
                        Color.Transparent
                    ),
                    center = Offset(w * 0.5f, h * 0.20f),
                    radius = w * 0.70f * pulseScale
                ),
                radius = w * 0.70f * pulseScale,
                center = Offset(w * 0.5f, h * 0.20f)
            )

            // Ambient Radial Glow 2 (Warm Gold hint at bottom right)
            drawCircle(
                brush = Brush.radialGradient(
                    colors = listOf(
                        Color(0xFFFCE53D).copy(alpha = 0.16f * pulseScale),
                        Color(0xFFD97706).copy(alpha = 0.06f),
                        Color.Transparent
                    ),
                    center = Offset(w * 0.88f, h * 0.80f),
                    radius = w * 0.50f
                ),
                radius = w * 0.50f,
                center = Offset(w * 0.88f, h * 0.80f)
            )

            // ── Floating Men's Symbols (Mars ♂) ──
            val mensSymbolsData = listOf(
                // xFraction, yBaseFraction, radius, speedMultiplier, xDriftAmp, alpha, rotationBase
                listOf(0.14f, 0.18f, 16f, 1.0f, 18f, 0.26f, -15f),
                listOf(0.86f, 0.24f, 22f, 0.8f, -22f, 0.22f, 20f),
                listOf(0.22f, 0.68f, 28f, 1.2f, 25f, 0.18f, -30f),
                listOf(0.80f, 0.72f, 18f, 0.9f, -15f, 0.24f, 10f),
                listOf(0.50f, 0.88f, 20f, 1.1f, 20f, 0.20f, -5f),
                listOf(0.08f, 0.45f, 24f, 0.7f, -18f, 0.16f, 35f),
                listOf(0.92f, 0.50f, 14f, 1.3f, 14f, 0.22f, -25f)
            )

            mensSymbolsData.forEach { data ->
                val xFrac = data[0]
                val yBaseFrac = data[1]
                val radius = data[2].dp.toPx()
                val speed = data[3]
                val xAmp = data[4].dp.toPx()
                val baseAlpha = data[5]
                val rotBase = data[6]

                // Dynamic vertical upward drift with wrapping
                val yPos = ((yBaseFrac - (driftProgress * speed)) % 1.0f).let { if (it < 0) it + 1.0f else it } * h
                val xPos = (xFrac * w) + (sin(wavePhase * speed + xFrac * 10f) * xAmp).toFloat()
                val dynamicAlpha = (baseAlpha * (0.8f + 0.4f * sin(wavePhase + xFrac * 5f))).toFloat().coerceIn(0.05f, 0.40f)
                val dynamicRot = rotBase + (sin(wavePhase * 0.5f + xFrac) * 12f).toFloat()

                // Draw Mars ♂ Glyph
                val strokeW = (radius * 0.18f).coerceAtLeast(1.8f.dp.toPx())
                val circleCenter = Offset(xPos - radius * 0.25f, yPos + radius * 0.25f)
                val circleRadius = radius * 0.55f

                // 1. Circle body
                drawCircle(
                    color = Color(0xFF38BDF8).copy(alpha = dynamicAlpha),
                    radius = circleRadius,
                    center = circleCenter,
                    style = Stroke(width = strokeW)
                )

                // 2. Diagonal Arrow shaft (45 degrees up-right + rotation)
                val arrowAngleRad = Math.toRadians((45.0 + dynamicRot)).toFloat()
                val startDist = circleRadius
                val endDist = radius * 1.05f
                val startX = circleCenter.x + (cos(arrowAngleRad) * startDist)
                val startY = circleCenter.y - (sin(arrowAngleRad) * startDist)
                val endX = circleCenter.x + (cos(arrowAngleRad) * endDist)
                val endY = circleCenter.y - (sin(arrowAngleRad) * endDist)

                drawLine(
                    color = Color(0xFF38BDF8).copy(alpha = dynamicAlpha),
                    start = Offset(startX, startY),
                    end = Offset(endX, endY),
                    strokeWidth = strokeW,
                    cap = StrokeCap.Round
                )

                // 3. Arrow head barbs
                val barbLen = radius * 0.42f
                val barbAngle1 = arrowAngleRad + Math.toRadians(140.0).toFloat()
                val barbAngle2 = arrowAngleRad - Math.toRadians(140.0).toFloat()

                drawLine(
                    color = Color(0xFF38BDF8).copy(alpha = dynamicAlpha),
                    start = Offset(endX, endY),
                    end = Offset(endX + cos(barbAngle1) * barbLen, endY - sin(barbAngle1) * barbLen),
                    strokeWidth = strokeW,
                    cap = StrokeCap.Round
                )
                drawLine(
                    color = Color(0xFF38BDF8).copy(alpha = dynamicAlpha),
                    start = Offset(endX, endY),
                    end = Offset(endX + cos(barbAngle2) * barbLen, endY - sin(barbAngle2) * barbLen),
                    strokeWidth = strokeW,
                    cap = StrokeCap.Round
                )
            }

            // ── Floating SuamiSihat Dual-S Logomark Wave Motifs ──
            val logomarkMotifs = listOf(
                // xFrac, yBaseFrac, scaleSize, speed, alpha, rot
                listOf(0.28f, 0.32f, 38f, 0.85f, 0.18f, 15f),
                listOf(0.72f, 0.15f, 48f, 0.70f, 0.14f, -20f),
                listOf(0.35f, 0.82f, 44f, 1.05f, 0.16f, -10f),
                listOf(0.82f, 0.42f, 32f, 0.95f, 0.20f, 25f)
            )

            logomarkMotifs.forEach { data ->
                val xFrac = data[0]
                val yBaseFrac = data[1]
                val sizePx = data[2].dp.toPx()
                val speed = data[3]
                val baseAlpha = data[4]
                val rot = data[5]

                val yPos = ((yBaseFrac - (driftProgress * speed)) % 1.0f).let { if (it < 0) it + 1.0f else it } * h
                val xPos = (xFrac * w) + (sin(wavePhase * speed + xFrac * 8f) * 16.dp.toPx()).toFloat()
                val dynAlpha = (baseAlpha * (0.85f + 0.35f * cos(wavePhase + xFrac * 6f))).toFloat().coerceIn(0.04f, 0.35f)

                rotate(degrees = rot + (sin(wavePhase * 0.4f) * 8f).toFloat(), pivot = Offset(xPos, yPos)) {
                    val sPath = Path()
                    val r = sizePx * 0.36f
                    val strokeW = 2.2.dp.toPx()

                    // Upper S-arc
                    sPath.reset()
                    sPath.moveTo(xPos, yPos - r)
                    sPath.cubicTo(
                        xPos + r * 1.2f, yPos - r,
                        xPos + r * 1.2f, yPos,
                        xPos, yPos
                    )
                    // Lower S-arc
                    sPath.cubicTo(
                        xPos - r * 1.2f, yPos,
                        xPos - r * 1.2f, yPos + r,
                        xPos, yPos + r
                    )

                    drawPath(
                        path = sPath,
                        color = Color(0xFF38BDF8).copy(alpha = dynAlpha),
                        style = Stroke(width = strokeW, cap = StrokeCap.Round)
                    )

                    // Interlocking Core Arc
                    val innerPath = Path()
                    innerPath.moveTo(xPos + r * 0.4f, yPos - r * 0.7f)
                    innerPath.cubicTo(
                        xPos - r * 0.6f, yPos - r * 0.4f,
                        xPos + r * 0.6f, yPos + r * 0.4f,
                        xPos - r * 0.4f, yPos + r * 0.7f
                    )
                    drawPath(
                        path = innerPath,
                        color = Color(0xFFFCE53D).copy(alpha = dynAlpha * 0.75f),
                        style = Stroke(width = strokeW * 0.75f, cap = StrokeCap.Round)
                    )
                }
            }

            // ── Animated Sine Wave Ribbons ──
            // Animated Sine Wave Ribbon 1 (Primary Cyan)
            val wavePath1 = Path()
            val baseLine1 = h * 0.26f
            wavePath1.moveTo(0f, baseLine1)
            for (x in 0..w.toInt() step 6) {
                val y = baseLine1 + (sin(x * 0.008f + wavePhase) * 22f).toFloat()
                wavePath1.lineTo(x.toFloat(), y)
            }
            drawPath(
                path = wavePath1,
                color = Color(0xFF38BDF8).copy(alpha = 0.45f),
                style = Stroke(width = 2.5.dp.toPx(), cap = StrokeCap.Round)
            )

            // Animated Sine Wave Ribbon 2 (Gold Accent)
            val wavePath2 = Path()
            val baseLine2 = h * 0.30f
            wavePath2.moveTo(0f, baseLine2)
            for (x in 0..w.toInt() step 6) {
                val y = baseLine2 + (sin(x * 0.006f - wavePhase * 0.8f) * 18f).toFloat()
                wavePath2.lineTo(x.toFloat(), y)
            }
            drawPath(
                path = wavePath2,
                color = Color(0xFFFCE53D).copy(alpha = 0.30f),
                style = Stroke(width = 1.5.dp.toPx(), cap = StrokeCap.Round)
            )
        }

        // ── 2. Foreground Login Content & Glassmorphism Card ──
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding()
                .verticalScroll(scrollState)
                .padding(horizontal = 24.dp, vertical = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Spacer(modifier = Modifier.height(12.dp))

            // Official SuamiSihat Logomark Header Emblem
            Box(
                modifier = Modifier
                    .size(80.dp)
                    .clip(CircleShape)
                    .background(
                        brush = Brush.radialGradient(
                            colors = listOf(
                                Color(0xFF043388),
                                Color(0xFF022057)
                            )
                        )
                    )
                    .border(
                        2.dp,
                        Brush.linearGradient(listOf(Color(0xFF38BDF8), Color(0xFF0078D4))),
                        CircleShape
                    ),
                contentAlignment = Alignment.Center
            ) {
                Image(
                    painter = painterResource(id = R.drawable.ic_suamisihat_logomark),
                    contentDescription = "SuamiSihat Logomark",
                    modifier = Modifier.size(62.dp)
                )
            }

            Spacer(modifier = Modifier.height(14.dp))

            Text(
                text = "Welcome to SS-CAM",
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                letterSpacing = 0.5.sp
            )

            Text(
                text = "SuamiSihat Creative Asset Management",
                fontSize = 12.sp,
                color = Color(0xFF94A3B8),
                fontWeight = FontWeight.Normal
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Glassmorphism Card Container
            Surface(
                color = Color(0xFF0B1528).copy(alpha = 0.88f),
                shape = RoundedCornerShape(24.dp),
                border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF38BDF8).copy(alpha = 0.30f)),
                shadowElevation = 8.dp,
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(22.dp)
                ) {
                    // Error message alert if present
                    if (!errorMessage.isNullOrBlank()) {
                        Surface(
                            color = Color(0xFFEF4444).copy(alpha = 0.15f),
                            shape = RoundedCornerShape(10.dp),
                            border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFFEF4444).copy(alpha = 0.5f)),
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(bottom = 14.dp)
                                .semantics { liveRegion = LiveRegionMode.Polite }
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    Icons.Default.ErrorOutline,
                                    contentDescription = null,
                                    tint = Color(0xFFF87171),
                                    modifier = Modifier.size(16.dp)
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = errorMessage,
                                    fontSize = 12.sp,
                                    color = Color(0xFFFCA5A5),
                                    fontWeight = FontWeight.Medium
                                )
                            }
                        }
                    }

                    if (isContinueMode) {
                        // Remembered account: "Continue as <name>"
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            UserProfileAvatar(
                                imageUrl = "",
                                initials = continueName,
                                avatarColorHex = "#0078D4",
                                size = 36.dp
                            )
                            Spacer(modifier = Modifier.width(12.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = "Continue as $continueName",
                                    fontSize = 15.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = Color.White,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis
                                )
                                if (savedDisplayName.isNotBlank() && !savedDisplayName.equals(savedUsername, ignoreCase = true)) {
                                    Text(
                                        text = savedUsername,
                                        fontSize = 12.sp,
                                        color = Color(0xFF94A3B8),
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                }
                            }
                        }

                        TextButton(
                            onClick = {
                                password = ""
                                onSwitchAccount()
                            },
                            enabled = !isLoading,
                            modifier = Modifier.heightIn(min = 48.dp)
                        ) {
                            Text(
                                text = "Not you? Switch account",
                                fontSize = 13.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = Color(0xFF38BDF8)
                            )
                        }

                        Spacer(modifier = Modifier.height(6.dp))
                    } else {
                        // Field 1: Username
                        Text(
                            text = "Username",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFF94A3B8)
                        )

                        Spacer(modifier = Modifier.height(6.dp))

                        Surface(
                            color = Color(0xFF132238),
                            shape = RoundedCornerShape(14.dp),
                            border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF334155)),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 12.dp, vertical = 2.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    Icons.Default.Person,
                                    contentDescription = null,
                                    tint = Color(0xFF94A3B8),
                                    modifier = Modifier.size(18.dp)
                                )
                                Spacer(modifier = Modifier.width(10.dp))
                                TextField(
                                    value = typedUsername,
                                    onValueChange = { typedUsername = it },
                                    placeholder = {
                                        Text(
                                            "Username",
                                            fontSize = 13.sp,
                                            color = Color(0xFF64748B)
                                        )
                                    },
                                    keyboardOptions = KeyboardOptions(
                                        capitalization = KeyboardCapitalization.None,
                                        autoCorrectEnabled = false,
                                        keyboardType = KeyboardType.Text,
                                        imeAction = ImeAction.Next
                                    ),
                                    keyboardActions = KeyboardActions(
                                        onNext = { passwordFocusRequester.requestFocus() }
                                    ),
                                    colors = loginFieldColors(),
                                    singleLine = true,
                                    enabled = !isLoading,
                                    modifier = Modifier
                                        .weight(1f)
                                        .semantics { contentDescription = "Username" }
                                )
                            }
                        }

                        Text(
                            text = "Your username, staff ID or email",
                            fontSize = 11.sp,
                            color = Color(0xFF94A3B8),
                            modifier = Modifier.padding(start = 4.dp, top = 4.dp)
                        )

                        Spacer(modifier = Modifier.height(14.dp))
                    }

                    // Field 2: Password Input
                    Text(
                        text = "Password",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFF94A3B8)
                    )

                    Spacer(modifier = Modifier.height(6.dp))

                    Surface(
                        color = Color(0xFF132238),
                        shape = RoundedCornerShape(14.dp),
                        border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF334155)),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 12.dp, vertical = 2.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                Icons.Default.Lock,
                                contentDescription = null,
                                tint = Color(0xFF94A3B8),
                                modifier = Modifier.size(18.dp)
                            )
                            Spacer(modifier = Modifier.width(10.dp))
                            TextField(
                                value = password,
                                onValueChange = { password = it },
                                placeholder = {
                                    Text(
                                        "Password",
                                        fontSize = 13.sp,
                                        color = Color(0xFF64748B)
                                    )
                                },
                                visualTransformation = if (showPassword) VisualTransformation.None else PasswordVisualTransformation(),
                                keyboardOptions = KeyboardOptions(
                                    autoCorrectEnabled = false,
                                    keyboardType = KeyboardType.Password,
                                    imeAction = ImeAction.Done
                                ),
                                keyboardActions = KeyboardActions(
                                    onDone = { submit() }
                                ),
                                colors = loginFieldColors(),
                                singleLine = true,
                                enabled = !isLoading,
                                modifier = Modifier
                                    .weight(1f)
                                    .focusRequester(passwordFocusRequester)
                                    .semantics { contentDescription = "Password" }
                            )
                            IconButton(
                                onClick = { showPassword = !showPassword },
                                modifier = Modifier.size(48.dp)
                            ) {
                                Icon(
                                    imageVector = if (showPassword) Icons.Default.Visibility else Icons.Default.VisibilityOff,
                                    contentDescription = if (showPassword) "Hide password" else "Show password",
                                    tint = Color(0xFF94A3B8),
                                    modifier = Modifier.size(18.dp)
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(14.dp))

                    // Keep me signed in
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(min = 48.dp)
                            .toggleable(
                                value = rememberMe,
                                onValueChange = { rememberMe = it },
                                role = Role.Checkbox
                            ),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Checkbox(
                            checked = rememberMe,
                            onCheckedChange = null,
                            colors = CheckboxDefaults.colors(
                                checkedColor = Color(0xFF0078D4),
                                uncheckedColor = Color(0xFF64748B),
                                checkmarkColor = Color.White
                            ),
                            modifier = Modifier.size(24.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = "Keep me signed in on this device",
                            fontSize = 12.sp,
                            color = Color(0xFFCBD5E1),
                            fontWeight = FontWeight.Medium
                        )
                    }

                    Spacer(modifier = Modifier.height(18.dp))

                    // Sign in primary button
                    Button(
                        onClick = {
                            try { haptic.performHapticFeedback(HapticFeedbackType.LongPress) } catch (e: Exception) {
                                android.util.Log.w("SSCAM", "Haptic feedback unavailable", e)
                            }
                            submit()
                        },
                        enabled = canSubmit,
                        shape = RoundedCornerShape(14.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = Color(0xFF0078D4),
                            disabledContainerColor = Color(0xFF0078D4).copy(alpha = 0.5f)
                        ),
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(48.dp)
                    ) {
                        if (isLoading) {
                            CircularProgressIndicator(
                                color = Color.White,
                                strokeWidth = 2.dp,
                                modifier = Modifier.size(20.dp)
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "Signing in…",
                                fontSize = 14.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color.White
                            )
                        } else {
                            Text(
                                text = "Sign in",
                                fontSize = 14.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color.White
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Icon(
                                Icons.AutoMirrored.Filled.ArrowForward,
                                contentDescription = null,
                                tint = Color.White,
                                modifier = Modifier.size(16.dp)
                            )
                        }
                    }

                    if (isContinueMode) {
                        Spacer(modifier = Modifier.height(12.dp))

                        // Biometric unlock: only reopens a saved, unexpired session on this device
                        OutlinedButton(
                            onClick = {
                                try { haptic.performHapticFeedback(HapticFeedbackType.LongPress) } catch (e: Exception) {
                                    android.util.Log.w("SSCAM", "Haptic feedback unavailable", e)
                                }
                                onBiometricLogin()
                            },
                            enabled = !isLoading,
                            shape = RoundedCornerShape(14.dp),
                            border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF38BDF8).copy(alpha = 0.5f)),
                            colors = ButtonDefaults.outlinedButtonColors(
                                contentColor = Color(0xFF38BDF8)
                            ),
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(48.dp)
                        ) {
                            Icon(
                                Icons.Default.Fingerprint,
                                contentDescription = null,
                                tint = Color(0xFF38BDF8),
                                modifier = Modifier.size(18.dp)
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "Unlock with fingerprint or face",
                                fontSize = 12.5.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = Color(0xFFE2E8F0)
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Official 2026 Brand Footer
            Text(
                text = "2026® SuamiSihat Holding Sdn Bhd • Creative-Team",
                fontSize = 11.sp,
                color = Color(0xFF64748B),
                fontWeight = FontWeight.Medium
            )

            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}

/** Shared transparent text-field colours for the sign-in card's dark input surfaces. */
@Composable
private fun loginFieldColors(): TextFieldColors = TextFieldDefaults.colors(
    focusedContainerColor = Color.Transparent,
    unfocusedContainerColor = Color.Transparent,
    disabledContainerColor = Color.Transparent,
    focusedIndicatorColor = Color.Transparent,
    unfocusedIndicatorColor = Color.Transparent,
    disabledIndicatorColor = Color.Transparent,
    focusedTextColor = Color.White,
    unfocusedTextColor = Color.White,
    disabledTextColor = Color(0xFFCBD5E1),
    cursorColor = Color(0xFF38BDF8)
)

/** Minimum password length required by the server. */
private const val MIN_PASSWORD_LENGTH = 10

/**
 * "Choose a new password" step shown after signing in with the default password.
 * Validates locally (length and match) before [onSubmit] is called with the new password.
 */
@Composable
fun ChangePasswordDialog(
    isSaving: Boolean,
    errorMessage: String?,
    onDismiss: () -> Unit,
    onSubmit: (newPassword: String) -> Unit
) {
    val colors = LocalSscamColors.current
    var newPassword by remember { mutableStateOf("") }
    var confirmPassword by remember { mutableStateOf("") }
    var showPasswords by remember { mutableStateOf(false) }
    var attempted by remember { mutableStateOf(false) }
    val confirmFocusRequester = remember { FocusRequester() }

    val tooShort = newPassword.length < MIN_PASSWORD_LENGTH
    val mismatch = confirmPassword != newPassword
    val localError = when {
        !attempted -> null
        tooShort -> "Use at least $MIN_PASSWORD_LENGTH characters."
        mismatch -> "The passwords don't match."
        else -> null
    }
    val shownError = localError ?: errorMessage

    fun trySubmit() {
        attempted = true
        if (!isSaving && !tooShort && !mismatch) onSubmit(newPassword)
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                "Choose a new password",
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                color = colors.textPrimary
            )
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    "You're using the default password. Please choose your own to continue.",
                    fontSize = 13.sp,
                    color = colors.textSecondary
                )
                OutlinedTextField(
                    value = newPassword,
                    onValueChange = { newPassword = it },
                    label = { Text("New password") },
                    supportingText = { Text("At least $MIN_PASSWORD_LENGTH characters") },
                    singleLine = true,
                    enabled = !isSaving,
                    visualTransformation = if (showPasswords) VisualTransformation.None else PasswordVisualTransformation(),
                    keyboardOptions = KeyboardOptions(
                        autoCorrectEnabled = false,
                        keyboardType = KeyboardType.Password,
                        imeAction = ImeAction.Next
                    ),
                    keyboardActions = KeyboardActions(onNext = { confirmFocusRequester.requestFocus() }),
                    trailingIcon = {
                        IconButton(
                            onClick = { showPasswords = !showPasswords },
                            modifier = Modifier.size(48.dp)
                        ) {
                            Icon(
                                imageVector = if (showPasswords) Icons.Default.Visibility else Icons.Default.VisibilityOff,
                                contentDescription = if (showPasswords) "Hide passwords" else "Show passwords"
                            )
                        }
                    },
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = confirmPassword,
                    onValueChange = { confirmPassword = it },
                    label = { Text("Confirm password") },
                    singleLine = true,
                    enabled = !isSaving,
                    visualTransformation = if (showPasswords) VisualTransformation.None else PasswordVisualTransformation(),
                    keyboardOptions = KeyboardOptions(
                        autoCorrectEnabled = false,
                        keyboardType = KeyboardType.Password,
                        imeAction = ImeAction.Done
                    ),
                    keyboardActions = KeyboardActions(onDone = { trySubmit() }),
                    modifier = Modifier
                        .fillMaxWidth()
                        .focusRequester(confirmFocusRequester)
                )
                if (!shownError.isNullOrBlank()) {
                    Text(
                        text = shownError,
                        fontSize = 12.sp,
                        color = Color(0xFFEF4444),
                        fontWeight = FontWeight.Medium,
                        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite }
                    )
                }
            }
        },
        confirmButton = {
            Button(
                onClick = { trySubmit() },
                enabled = !isSaving && newPassword.isNotEmpty() && confirmPassword.isNotEmpty(),
                colors = ButtonDefaults.buttonColors(containerColor = colors.primary),
                modifier = Modifier.heightIn(min = 48.dp)
            ) {
                if (isSaving) {
                    CircularProgressIndicator(
                        color = Color.White,
                        strokeWidth = 2.dp,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Saving…", fontSize = 13.sp, fontWeight = FontWeight.Bold)
                } else {
                    Text("Save and continue", fontSize = 13.sp, fontWeight = FontWeight.Bold)
                }
            }
        },
        dismissButton = {
            TextButton(
                onClick = onDismiss,
                enabled = !isSaving,
                modifier = Modifier.heightIn(min = 48.dp)
            ) {
                Text("Cancel", fontSize = 13.sp, color = colors.textSecondary)
            }
        }
    )
}
