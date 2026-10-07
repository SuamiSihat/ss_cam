# Fixing Design-System Drift in Antigravity (Gemini Flash) — SS-CAM / SS-Design-System

**Symptom:** Gemini Flash agents in Google Antigravity follow the SuamiSihat design-system rules for the first few files, then drift — ignoring tokens or diverging from `AGENTS.md` — on later edits within the same session.

**Verdict:** Not a missing-rules problem. Three independent structural gaps were found in the repos themselves, plus one model-behavior factor. All four compound.

---

## Root Cause 1 — Rules are Claude Skill format; Antigravity has no discovery mechanism for them

`ss_cam/.agents/skills/*/SKILL.md` (e.g. `sscam-code-guardian`, `sscam-fluent2-design`) uses Claude Code's native skill frontmatter (`name:` / `description:` + progressive disclosure). Claude Code auto-discovers and triggers these on relevant file changes. **Antigravity has no equivalent discovery logic** — it only works with what it's explicitly given in its own session context or its own auto-generated "Artifacts." A `.agents/skills/` folder sitting in the repo is invisible to it unless a human or task spec points at it directly.

Root `AGENTS.md` is a more universal convention some tools do read automatically, but it's a passive reference doc, not an enforcement hook — see Root Cause 2.

## Root Cause 2 — Zero mechanical enforcement anywhere

Checked: `.git/hooks/` (empty, no custom hooks), Husky/pre-commit config (none), CI workflows (none reference `verify-sscam.ps1`).

`QA/verify-sscam.ps1` — the script that actually checks UTF-8 BOM, Fluent 2 compliance, hardcoded paths, silent catches — is **only ever invoked because a markdown file tells an agent to remember to run it.** There is no git hook, no CI gate, nothing that runs it independent of the model's own compliance in a given turn. When a fast/cheap model's sustained rule-following degrades after several files (expected behavior for Flash-tier models on long, constraint-dense sessions), nothing catches the regression.

## Root Cause 3 (compounding) — WPF app is not actually wired to the token source of truth

Checked `ss_cam/src/SS-CAM/Styles/*.xaml` (`SSDefaultTheme.xaml`, `Fluent2Styles.xaml`, etc.) against `SS-Design-System/assets/tokens/{tokens.json, design-tokens.json, ss_tokens.ts}`.

**Result: zero references.** The WPF theme resource dictionaries are a hand-maintained, independent copy — not generated or synced from the design system's token export. So even a perfectly rule-following agent editing `ss_cam` has no live link back to the actual source of truth; it can only match whatever local XAML happens to currently contain, which can silently drift from `SS-Design-System` over time regardless of which AI tool is used.

## Root Cause 4 — Status/terminology values are not actually shared across Web, WPF, and Android

The ecosystem's own self-audit (`QA/SSCAM_ECOSYSTEM_HEALTH_REPORT.md`, dated Sept 8, 2026, authored by "Antigravity AI") scores **"Cross-Platform Status Alignment" at 100% PASS**, claiming identical states across all three platforms. The source code doesn't support that claim:

- **Naming convention differs by platform, not just casing:** Web/WPF use hyphenated values (`in-progress`, `on-hold`, `review`); Android uses underscored values (`in_progress`, `on_hold`, `in_review`). That's a translation layer being described as identity — translation layers are exactly where drift re-enters.
- **Android's own code shows unresolved drift, not a clean mapping.** `ManageProjectBottomSheet.kt` checks `"in-progress", "in_progress", "progress"` and `"review", "in_review"` side-by-side in the same conditionals — the signature of patches layered over inconsistent data over time, not a single canonical enum.
- **`approved` silently disappears on Android.** Web/WPF treat `approved` and `done` as distinct values; Android's primary status list only defines `done`, with `approved` handled ad hoc in a few files and absent from the canonical list (`ManageProjectBottomSheet.kt:70-73`). Whether that's an intentional merge or a dropped state isn't documented anywhere.
- **Terminology rule is already being violated in a small way inside a single codebase.** WPF source has 217 uses of `Project` but also 8 stray uses of `job`/`jobId` — exactly the "Project vs Job" inconsistency `AGENTS.md`'s own Terminology Rule forbids.
- **The 100% claim was self-graded by the same tool that wrote the code**, with no independent verification step — a direct violation of `AGENTS.md`'s own testing rule ("Never claim PASS unless the behaviour has actually been verified") applied to the audit itself.

Same underlying pattern as Root Cause 3: no single source of truth. Each platform hand-maintains its own status-string set, kept in agreement by convention rather than by generation from one file.

---

## Fix Plan (priority order)

### 1. Add a real pre-commit / build gate (highest leverage — model-agnostic)

Wire `QA/verify-sscam.ps1` into an actual git hook (or Husky) so it runs on every commit, not just when an agent remembers to.

```bash
# .git/hooks/pre-commit  (or husky .husky/pre-commit)
pwsh -File QA/verify-sscam.ps1
exit $LASTEXITCODE
```

This catches drift from *any* agent — Flash, Pro, Claude, or a human — not just one you happened to prompt well.

### 2. Generate a token bridge from SS-Design-System into ss_cam

Add a build step (or a small script under `QA/`) that reads `SS-Design-System/assets/tokens/design-tokens.json` and generates the WPF `ResourceDictionary` values, instead of hand-maintaining `SSDefaultTheme.xaml` separately. Even a one-way sync script run on each design-system release closes this gap. Until this exists, treat `ss_cam`'s current theme files as **not guaranteed to match** the published design system.

### 3. Create one canonical status-enum source file and generate all three platforms from it

Add e.g. `SS-Design-System/assets/tokens/status-enum.json` (or keep it in `ss_cam` if it's app-specific, not design-system-wide — your call) as the single source of truth:

```json
{
  "backlog":     { "web": "backlog",     "wpf": "backlog",     "android": "backlog" },
  "in_progress": { "web": "in-progress", "wpf": "in-progress", "android": "in_progress" },
  "review":      { "web": "review",      "wpf": "review",      "android": "in_review" },
  "revision":    { "web": "revision",    "wpf": "revision",    "android": "revision" },
  "approved":    { "web": "approved",    "wpf": "approved",    "android": "done" },
  "on_hold":     { "web": "on-hold",     "wpf": "on-hold",     "android": "on_hold" }
}
```

Then generate the Web enum, the WPF `ProjectStatusItem` constants, and the Android `Models.kt` constants from this one file — do not hand-maintain three separate lists. This also forces an explicit decision on the `approved` vs `done` merge instead of leaving it ambiguous. Clean up `ManageProjectBottomSheet.kt`'s multi-variant string checks (`"in-progress", "in_progress", "progress"`) once the generated constant is the only value ever produced.

### 4. Fix the stray `Job`/`jobId` terminology leak in WPF

Per `AGENTS.md`'s own Terminology Rule: grep `src/SS-CAM` for `job`/`jobId`, confirm whether it's a deliberate distinct concept or leftover terminology, and either rename to `Project`/`ProjectId` or document why it's intentionally different.

### 5. Stop relying on Antigravity to "find" `.agents/skills/`

For any Antigravity/Gemini session on this repo, explicitly paste the relevant `SKILL.md` path into the task/Artifact spec at the start of the session, e.g.:
> "Before editing any file under `src/SS-CAM`, read and follow `.agents/skills/sscam-code-guardian/SKILL.md` in full, and re-read it before every third file you touch."
Treat it as an injected file, not a folder the agent will browse on its own.

### 6. Raise Antigravity's thinking budget for this repo

Set the session's thinking tier to **High** (not default/Flash-speed) for any task touching UI/token/status rules. If drift persists at High, move this specific repo's sessions to Gemini 3.5/3.6 **Pro** instead of Flash — Flash is architected to trade sustained reasoning/constraint-adherence for speed, which is exactly what dense rule sets need most.

### 7. Structural option: run this repo through Claude Code instead of Antigravity

Since the skills are already authored in Claude's native skill format, Claude Code will auto-discover and trigger `.agents/skills/*/SKILL.md` with no translation step — removing Root Cause 1 entirely rather than working around it. Worth trialing on one feature branch as a direct comparison against the Antigravity/Flash sessions.

### 8. Stop trusting self-graded audits

Any future "ecosystem health report" generated by the same AI tool that wrote the code being audited should be treated as a draft claim, not a verified result — per `AGENTS.md`'s own rule. Have a second, independent agent (different model/tool) or a human re-run the same checks before accepting a 100%/PASS score.

---

## Verification checklist after applying fixes

- [ ] `git commit` with an intentionally non-BOM file fails locally (hook works)
- [ ] Token bridge script run once; diff `SSDefaultTheme.xaml` against generated output — check for existing drift
- [ ] Status-enum source file created; Web, WPF, and Android constants all regenerated from it, not hand-edited
- [ ] `ManageProjectBottomSheet.kt`'s redundant multi-variant string checks removed once only one canonical value is ever produced
- [ ] `job`/`jobId` occurrences in WPF resolved (renamed or documented as intentional)
- [ ] Next Antigravity session given explicit `SKILL.md` path in task spec — confirm agent references it in its own reasoning/Artifact output
- [ ] Same task run at High thinking tier — compare drift point (file count before first miss) against previous Low/Medium runs
- [ ] Any future self-generated health/audit report re-checked by a second independent agent or human before being trusted
