package com.suamisihat.sscam.ui.screens

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.EditNote
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.suamisihat.sscam.ui.components.FluentCard
import com.suamisihat.sscam.ui.theme.*

data class MarketingAngle(
    val id: String,
    val title: String,
    val symptomTag: String,
    val hooks: List<HookItem>
)

data class HookItem(
    val formula: String,
    val headline: String,
    val explanation: String
)

val CLINICAL_MARKETING_ANGLES = listOf(
    MarketingAngle(
        id = "eswt",
        title = "ESWT Acoustic Wave",
        symptomTag = "Vascular Performance",
        hooks = listOf(
            HookItem(
                formula = "Problem - Agitation - Solution (PAS)",
                headline = "Mengapa rawatan gelombang kejutan akustik lebih pantas pulihkan prestasi berbanding ubat berpanjangan?",
                explanation = "Menyentuh keresahan kebergantungan ubat, menawarkan sains regenerasi saluran darah vaskular mikro."
            ),
            HookItem(
                formula = "Curiosity Gap",
                headline = "3 Tanda peredaran darah mikro anda mula perlahan sebelum umur 40 tahun.",
                explanation = "Menarik minat pembaca untuk mendiagnosis diri dan menempah sesi imbasan perubatan."
            ),
            HookItem(
                formula = "Medical Authority",
                headline = "Protokol klinikal EAU membuktikan 82% pesakit pulih secara semulajadi dengan terapi gelombang berfokus.",
                explanation = "Bukti autoriti garis panduan persatuan urologi antarabangsa membina kepercayaan segera."
            )
        )
    ),
    MarketingAngle(
        id = "trt",
        title = "TRT Hormone Recovery",
        symptomTag = "Fatigue & Libido",
        hooks = listOf(
            HookItem(
                formula = "Relatable Reality",
                headline = "Bangun pagi rasa letih walaupun tidur cukup 8 jam? Ini mungkin bukan faktor penuaan biasa.",
                explanation = "Mendedahkan gejala penurunan hormon androgen lelaki dengan nada perbualan empati."
            ),
            HookItem(
                formula = "Before - After - Bridge",
                headline = "Dari lesu di pejabat ke fokus bertenaga dalam 3 minggu: Protokol pemulihan hormon lelaki SuamiSihat.",
                explanation = "Menunjukkan transformasi nyata tenaga harian dan keyakinan diri bersama pasangan."
            )
        )
    ),
    MarketingAngle(
        id = "pelvic",
        title = "Pelvic Biomechanics",
        symptomTag = "Core & Control",
        hooks = listOf(
            HookItem(
                formula = "Science Breakdown",
                headline = "Otot lantai pelvis lelaki: Otot tersembunyi yang mengawal ketahanan dan kelancaran.",
                explanation = "Penerangan anatomi ringkas yang mendidik tanpa unsur lucah atau sensitif."
            ),
            HookItem(
                formula = "Actionable Steps",
                headline = "Teknik senaman kegel klinikal yang betul: 5 minit sehari dengan bimbingan fisioterapi bertauliah.",
                explanation = "Menggalakkan amalan harian berasaskan bimbingan profesional cawangan klinik."
            )
        )
    ),
    MarketingAngle(
        id = "clinic",
        title = "Branch Grand Launch",
        symptomTag = "Accessibility & Privacy",
        hooks = listOf(
            HookItem(
                formula = "Exclusive Invitation",
                headline = "Kini Dibuka di Johor Bahru: Sesi konsultasi peribadi 1-ke-1 bersama doktor pakar kesihatan lelaki.",
                explanation = "Menekankan privasi tinggi, bilik rundingan berasingan, dan keselesaan penuh."
            ),
            HookItem(
                formula = "Community Trust",
                headline = "Lebih 15,000 lelaki Malaysia telah mendapatkan konsultasi beretika di SuamiSihat.",
                explanation = "Bukti sosial skala besar yang meruntuhkan stigma masyarakat untuk mendapatkan rawatan."
            )
        )
    )
)

@Composable
fun CopywritingStudioScreen() {
    val context = LocalContext.current
    val colors = LocalSscamColors.current
    var selectedAngleIndex by remember { mutableStateOf(0) }
    val currentAngle = CLINICAL_MARKETING_ANGLES[selectedAngleIndex]

    // Generator inputs
    var selectedAudience by remember { mutableStateOf("Executive (35-50 y/o)") }
    val audienceOptions = listOf("Young Active (25-35 y/o)", "Executive (35-50 y/o)", "Senior Health (50+ y/o)")

    fun copyToClipboard(text: String, label: String) {
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText(label, text)
        clipboard.setPrimaryClip(clip)
        Toast.makeText(context, "Copied $label to clipboard", Toast.LENGTH_SHORT).show()
    }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // ── Header Banner ─────────────────────────────────────────────────
        item {
            Column {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Icon(
                        Icons.Default.EditNote,
                        contentDescription = "Copy Studio",
                        tint = if (colors.isDark) Color(0xFF60A5FA) else Color(0xFF022057),
                        modifier = Modifier.size(24.dp)
                    )
                    Text(
                        text = "Copywriting Studio Companion",
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold,
                        color = colors.textPrimary
                    )
                }
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = "Clinical advertising angles, proven headline formulas, and 1-tap copy dispatch for social ads and video scripts.",
                    fontSize = 12.sp,
                    color = colors.textSecondary
                )
            }
        }

        // ── Marketing Angle Selector Pills ────────────────────────────────
        item {
            LazyRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                items(CLINICAL_MARKETING_ANGLES.indices.toList()) { index ->
                    val angle = CLINICAL_MARKETING_ANGLES[index]
                    val isSelected = selectedAngleIndex == index
                    Surface(
                        color = if (isSelected) colors.activePillBg else colors.surface,
                        shape = RoundedCornerShape(16.dp),
                        border = androidx.compose.foundation.BorderStroke(
                            1.dp,
                            if (isSelected) colors.activePillBg else colors.border
                        ),
                        modifier = Modifier.clickable { selectedAngleIndex = index }
                    ) {
                        Text(
                            text = angle.title,
                            fontSize = 12.sp,
                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                            color = if (isSelected) colors.activePillTint else colors.textSecondary,
                            modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp)
                        )
                    }
                }
            }
        }

        // ── Angle Overview Card ───────────────────────────────────────────
        item {
            Surface(
                color = colors.surface,
                shape = RoundedCornerShape(12.dp),
                border = androidx.compose.foundation.BorderStroke(1.dp, colors.border),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier.padding(14.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(
                            text = "Target Focus: ${currentAngle.title}",
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Bold,
                            color = colors.textPrimary
                        )
                        Text(
                            text = "Clinical Pillar: ${currentAngle.symptomTag}",
                            fontSize = 11.sp,
                            color = colors.textSecondary
                        )
                    }
                    Surface(
                        color = (if (colors.isDark) Color(0xFF60A5FA) else Color(0xFF022057)).copy(alpha = 0.12f),
                        shape = RoundedCornerShape(6.dp)
                    ) {
                        Text(
                            text = "${currentAngle.hooks.size} Verified Hooks",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = if (colors.isDark) Color(0xFF60A5FA) else Color(0xFF022057),
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                        )
                    }
                }
            }
        }

        // ── Hook Cards ────────────────────────────────────────────────────
        item {
            Text(
                text = "Proven Hook Formulas",
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold,
                color = colors.textPrimary
            )
        }

        items(currentAngle.hooks) { hook ->
            Surface(
                color = colors.surface,
                shape = RoundedCornerShape(12.dp),
                border = androidx.compose.foundation.BorderStroke(1.dp, colors.border),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(
                    modifier = Modifier.padding(14.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Surface(
                            color = Color(0xFFFCE53D).copy(alpha = 0.2f),
                            shape = RoundedCornerShape(4.dp)
                        ) {
                            Text(
                                text = hook.formula,
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                color = if (colors.isDark) Color(0xFFFCE53D) else Color(0xFF78350F),
                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                            )
                        }

                        IconButton(
                            onClick = { copyToClipboard(hook.headline, "Hook") },
                            modifier = Modifier.size(28.dp)
                        ) {
                            Icon(
                                Icons.Default.ContentCopy,
                                contentDescription = "Copy Hook",
                                tint = colors.textSecondary,
                                modifier = Modifier.size(15.dp)
                            )
                        }
                    }

                    Text(
                        text = "\"${hook.headline}\"",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                        color = colors.textPrimary,
                        lineHeight = 18.sp
                    )

                    Text(
                        text = hook.explanation,
                        fontSize = 11.sp,
                        color = colors.textSecondary,
                        lineHeight = 15.sp
                    )
                }
            }
        }

        // ── Full Ad Script Builder ────────────────────────────────────────
        item {
            Spacer(modifier = Modifier.height(4.dp))
            Surface(
                color = if (colors.isDark) Color(0xFF1E293B) else Color(0xFFF8FAFC),
                shape = RoundedCornerShape(12.dp),
                border = androidx.compose.foundation.BorderStroke(1.dp, colors.border),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Icon(
                            Icons.Default.AutoAwesome,
                            contentDescription = "Script Builder",
                            tint = if (colors.isDark) Color(0xFF60A5FA) else Color(0xFF022057),
                            modifier = Modifier.size(16.dp)
                        )
                        Text(
                            text = "One-Tap Video Ad Script Builder",
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Bold,
                            color = colors.textPrimary
                        )
                    }

                    Text(
                        text = "Target Persona:",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = colors.textSecondary
                    )

                    LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        items(audienceOptions) { opt ->
                            val isSel = selectedAudience == opt
                            Surface(
                                color = if (isSel) colors.activePillBg else colors.surface,
                                shape = RoundedCornerShape(12.dp),
                                border = androidx.compose.foundation.BorderStroke(
                                    1.dp,
                                    if (isSel) colors.activePillBg else colors.border
                                ),
                                modifier = Modifier.clickable { selectedAudience = opt }
                            ) {
                                Text(
                                    text = opt,
                                    fontSize = 11.sp,
                                    fontWeight = if (isSel) FontWeight.Bold else FontWeight.Normal,
                                    color = if (isSel) colors.activePillTint else colors.textSecondary,
                                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
                                )
                            }
                        }
                    }

                    val fullScript = remember(currentAngle, selectedAudience) {
                        """
                        [HOOK (0-3s)]
                        "${currentAngle.hooks.firstOrNull()?.headline ?: ""}"

                        [BODY / PROOF (3-15s)]
                        Rawatan di SuamiSihat dijalankan 100% secara klinikal dan beretika oleh doktor bertauliah. Sesuai khas untuk golongan ${selectedAudience} yang mementingkan privasi dan hasil selamat tanpa bergantung kepada produk tiruan.

                        [CALL TO ACTION (15-20s)]
                        Tekan butang di bawah untuk menempah sesi imbasan diagnostik peribadi di cawangan klinik SuamiSihat berdekatan anda hari ini.
                        """.trimIndent()
                    }

                    Surface(
                        color = colors.surface,
                        shape = RoundedCornerShape(8.dp),
                        border = androidx.compose.foundation.BorderStroke(1.dp, colors.border),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(
                            text = fullScript,
                            fontSize = 11.sp,
                            lineHeight = 16.sp,
                            color = colors.textPrimary,
                            modifier = Modifier.padding(12.dp)
                        )
                    }

                    Button(
                        onClick = { copyToClipboard(fullScript, "Complete Script") },
                        colors = ButtonDefaults.buttonColors(
                            containerColor = if (colors.isDark) Color(0xFF60A5FA) else Color(0xFF022057)
                        ),
                        shape = RoundedCornerShape(8.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Icon(
                            Icons.Default.ContentCopy,
                            contentDescription = "Copy Script",
                            modifier = Modifier.size(16.dp),
                            tint = Color.White
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = "Copy Complete 20s Script",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                    }
                }
            }
        }
    }
}
