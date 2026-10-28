package com.suamisihat.sscam.ui.screens

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.Toast
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.suamisihat.sscam.data.models.ProjectItem
import com.suamisihat.sscam.data.models.ProjectStatusConstants
import com.suamisihat.sscam.ui.components.FluentCard
import com.suamisihat.sscam.ui.theme.*

@Composable
fun ProjectCatalogScreen(
    projects: List<ProjectItem>,
    onSelectProject: (ProjectItem) -> Unit = {}
) {
    val context = LocalContext.current
    val colors = LocalSscamColors.current
    var searchQuery by remember { mutableStateOf("") }
    var selectedStatusFilter by remember { mutableStateOf("All") }
    var selectedBrandFilter by remember { mutableStateOf("All") }
    var inspectedProject by remember { mutableStateOf<ProjectItem?>(null) }

    val statusFilters = listOf("All", "In Progress", "In Review", "Done", "Backlog")

    val availableBrands = remember(projects) {
        listOf("All") + projects.map { it.safeBrand }.distinct().filter { it.isNotBlank() }
    }

    val filteredProjects = remember(projects, searchQuery, selectedStatusFilter, selectedBrandFilter) {
        projects.filter { item ->
            val matchSearch = searchQuery.isBlank() ||
                item.safeTitle.contains(searchQuery, ignoreCase = true) ||
                item.id.contains(searchQuery, ignoreCase = true) ||
                item.safeDesigner.contains(searchQuery, ignoreCase = true) ||
                item.safeBrand.contains(searchQuery, ignoreCase = true)

            val matchStatus = when (selectedStatusFilter) {
                "In Progress" -> item.normalizedStatus == "in_progress"
                "In Review" -> item.normalizedStatus == "in_review" || item.normalizedStatus == "revision"
                "Done" -> item.normalizedStatus == "done"
                "Backlog" -> item.normalizedStatus == "backlog"
                else -> true
            }

            val matchBrand = selectedBrandFilter == "All" || item.safeBrand.equals(selectedBrandFilter, ignoreCase = true)

            matchSearch && matchStatus && matchBrand
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        // ── Search & Filter Controls ──────────────────────────────────────
        Surface(
            color = if (colors.isDark) Color(0xFF1E293B) else Color(0xFFF1F5F9),
            shape = RoundedCornerShape(12.dp),
            border = androidx.compose.foundation.BorderStroke(1.dp, colors.border),
            modifier = Modifier
                .fillMaxWidth()
                .height(44.dp)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    Icons.Default.Search,
                    contentDescription = "Search",
                    tint = colors.textSecondary,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                TextField(
                    value = searchQuery,
                    onValueChange = { searchQuery = it },
                    placeholder = {
                        Text(
                            "Search projects, brands, designers…",
                            fontSize = 13.sp,
                            color = colors.textSecondary
                        )
                    },
                    singleLine = true,
                    colors = TextFieldDefaults.colors(
                        focusedContainerColor = Color.Transparent,
                        unfocusedContainerColor = Color.Transparent,
                        focusedIndicatorColor = Color.Transparent,
                        unfocusedIndicatorColor = Color.Transparent,
                        focusedTextColor = colors.textPrimary,
                        unfocusedTextColor = colors.textPrimary
                    ),
                    modifier = Modifier.weight(1f)
                )
                if (searchQuery.isNotBlank()) {
                    IconButton(
                        onClick = { searchQuery = "" },
                        modifier = Modifier.size(24.dp)
                    ) {
                        Icon(
                            Icons.Default.Close,
                            contentDescription = "Clear",
                            tint = colors.textSecondary,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(10.dp))

        // ── Status Filter Chips ───────────────────────────────────────────
        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            items(statusFilters) { status ->
                val isSelected = selectedStatusFilter == status
                Surface(
                    color = if (isSelected) colors.activePillBg else colors.surface,
                    shape = RoundedCornerShape(16.dp),
                    border = androidx.compose.foundation.BorderStroke(
                        1.dp,
                        if (isSelected) colors.activePillBg else colors.border
                    ),
                    modifier = Modifier.clickable { selectedStatusFilter = status }
                ) {
                    Text(
                        text = status,
                        fontSize = 12.sp,
                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                        color = if (isSelected) colors.activePillTint else colors.textSecondary,
                        modifier = Modifier.padding(horizontal = 14.dp, vertical = 6.dp)
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        // ── Summary Telemetry Row ─────────────────────────────────────────
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 4.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "${filteredProjects.size} Projects found",
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = colors.textSecondary
            )
            Text(
                text = "Total Deliverables: ${filteredProjects.sumOf { it.safeDeliverableCount }}",
                fontSize = 11.sp,
                color = colors.textSecondary
            )
        }

        Spacer(modifier = Modifier.height(8.dp))

        // ── Project List ──────────────────────────────────────────────────
        if (filteredProjects.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(32.dp),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        Icons.Default.FolderOpen,
                        contentDescription = "Empty",
                        tint = colors.textSecondary,
                        modifier = Modifier.size(48.dp)
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "No matching projects found",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                        color = colors.textPrimary
                    )
                    Text(
                        text = "Try adjusting your search query or filter tags.",
                        fontSize = 12.sp,
                        color = colors.textSecondary
                    )
                }
            }
        } else {
            LazyColumn(
                verticalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier.fillMaxSize()
            ) {
                items(filteredProjects, key = { it.id }) { item ->
                    ProjectCatalogCard(
                        project = item,
                        onClick = {
                            inspectedProject = item
                            onSelectProject(item)
                        }
                    )
                }
            }
        }
    }

    // ── Inspection Bottom Sheet / Dialog ──────────────────────────────────
    inspectedProject?.let { proj ->
        AlertDialog(
            onDismissRequest = { inspectedProject = null },
            title = {
                Column {
                    Text(
                        text = proj.id,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = if (colors.isDark) Color(0xFF60A5FA) else Color(0xFF022057)
                    )
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = proj.safeTitle,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                        color = colors.textPrimary
                    )
                }
            },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text("Brand / Subsidiary:", fontSize = 12.sp, color = colors.textSecondary)
                        Text(proj.safeBrand, fontSize = 12.sp, fontWeight = FontWeight.Bold, color = colors.textPrimary)
                    }
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text("Lead Designer:", fontSize = 12.sp, color = colors.textSecondary)
                        Text(proj.safeDesigner, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = colors.textPrimary)
                    }
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text("Current Status:", fontSize = 12.sp, color = colors.textSecondary)
                        Text(proj.normalizedStatus.replace('_', ' ').uppercase(), fontSize = 12.sp, fontWeight = FontWeight.Bold, color = colors.textPrimary)
                    }
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text("Target Deadline:", fontSize = 12.sp, color = colors.textSecondary)
                        Text(proj.deadline.orEmpty().ifBlank { "Not set" }, fontSize = 12.sp, color = colors.textPrimary)
                    }
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text("Deliverables Pack:", fontSize = 12.sp, color = colors.textSecondary)
                        Text("${proj.safeDeliverableCount} files ready on NAS", fontSize = 12.sp, color = colors.textPrimary)
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        val clip = ClipData.newPlainText("Project ID", proj.id)
                        (context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(clip)
                        Toast.makeText(context, "Copied ${proj.id} to clipboard", Toast.LENGTH_SHORT).show()
                        inspectedProject = null
                    },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (colors.isDark) Color(0xFF60A5FA) else Color(0xFF022057)
                    )
                ) {
                    Text("Copy ID", color = Color.White)
                }
            },
            dismissButton = {
                TextButton(onClick = { inspectedProject = null }) {
                    Text("Close", color = colors.textSecondary)
                }
            },
            containerColor = colors.surface,
            shape = RoundedCornerShape(16.dp)
        )
    }
}

@Composable
fun ProjectCatalogCard(
    project: ProjectItem,
    onClick: () -> Unit
) {
    val colors = LocalSscamColors.current

    val statusColor = when (project.normalizedStatus) {
        "done" -> Color(0xFF107C41)
        "in_review" -> Color(0xFF022057)
        "revision" -> Color(0xFFD83B01)
        "in_progress" -> Color(0xFF21A1F7)
        else -> Color(0xFF64748B)
    }

    Surface(
        color = colors.surface,
        shape = RoundedCornerShape(12.dp),
        border = androidx.compose.foundation.BorderStroke(1.dp, colors.border),
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
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
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(
                        text = project.id,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = if (colors.isDark) Color(0xFF60A5FA) else Color(0xFF022057)
                    )
                    Surface(
                        color = (if (colors.isDark) Color(0xFF60A5FA) else Color(0xFF022057)).copy(alpha = 0.12f),
                        shape = RoundedCornerShape(4.dp)
                    ) {
                        Text(
                            text = project.safeBrand,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            color = if (colors.isDark) Color(0xFF60A5FA) else Color(0xFF022057),
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                        )
                    }
                }

                Surface(
                    color = statusColor.copy(alpha = 0.15f),
                    shape = RoundedCornerShape(4.dp)
                ) {
                    Text(
                        text = project.normalizedStatus.replace('_', ' ').uppercase(),
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold,
                        color = statusColor,
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                    )
                }
            }

            Text(
                text = project.safeTitle,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                color = colors.textPrimary,
                lineHeight = 18.sp
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Icon(
                        Icons.Default.Person,
                        contentDescription = "Designer",
                        tint = colors.textSecondary,
                        modifier = Modifier.size(13.dp)
                    )
                    Text(
                        text = project.safeDesigner,
                        fontSize = 11.sp,
                        color = colors.textSecondary
                    )
                }

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Icon(
                        Icons.Default.Attachment,
                        contentDescription = "Deliverables",
                        tint = colors.textSecondary,
                        modifier = Modifier.size(13.dp)
                    )
                    Text(
                        text = "${project.safeDeliverableCount} files",
                        fontSize = 11.sp,
                        color = colors.textSecondary
                    )
                }
            }
        }
    }
}
