const fs = require('fs');
const path = require('path');
const config = require('../config');
const AuditService = require('./AuditService');
const WorkspaceService = require('./WorkspaceService');

class CopywritingService {
  /**
   * Resolves the copywriting file path for a project.
   * Priority: <projectPath>/03_COPYWRITING/COPY.md -> fallback: <projectPath>/COPY.md -> fallback: _Team/copywriting/<id>.md
   */
  static getCopyFilePath(projectPath, projectId) {
    if (projectPath && fs.existsSync(projectPath)) {
      const dir03 = path.join(projectPath, '03_COPYWRITING');
      if (!fs.existsSync(dir03)) {
        try {
          fs.mkdirSync(dir03, { recursive: true });
        } catch (e) {
          // fallback to project root
          return path.join(projectPath, 'COPY.md');
        }
      }
      return path.join(dir03, 'COPY.md');
    }

    const teamDir = path.join(config.WORKSPACE_ROOT, '_Team', 'copywriting');
    if (!fs.existsSync(teamDir)) {
      try {
        fs.mkdirSync(teamDir, { recursive: true });
      } catch (e) {
        console.debug('[CopywritingService] Failed to create teamDir:', e.message);
      }
    }
    return path.join(teamDir, `${projectId}.md`);
  }

  /**
   * Default template for copywriting
   */
  static getDefaultTemplate(projectTitle = 'Project Copywriting') {
    return `# ✍️ Copywriting & Script Studio: ${projectTitle}

## 🎯 Target Audience & Hook Strategy
- **Core Demographic**: Men aged 30+ (and their wives, who often find the lead) who want better energy, performance and confidence.
- **Tone of Voice**: Masculine, calm, trustworthy, premium medical. Punchy: say what the avatar thinks ("betul la, aku kena buat something!"), not the obvious.
- **Primary Angle**: Doctor-led assessment first (blood test + consultation), then a plan that fits the patient's budget.
- **Mix**: Candid-shot content is ~90% serious / 10% light humour. Heavy topics (stem cell, hormones) need an interactive, motion-graphic edit, not subtitles only.

---

## 📢 Meta Ad Creative Copy Variants

### Angle 1: Hook + Sinker (Educational)
> **Hook (first 3s)**: A question or scenario the avatar recognises.
> **Sinker**: One clear fact or doctor explanation. No absolute claims.
> **CTA (ads)**: "Klik butang di bawah" · **CTA (organic)**: "Link di bio ☝️"

### Angle 2: Quiz / Privacy
> **Headline**: "Semak tahap kesihatan lelaki anda — soalan ringkas, keputusan peribadi."
> **Primary Text**: Quiz leads cost far less than WhatsApp leads; keep the promise modest and the tone private.
> **CTA**: [ Mulakan Quiz ]

### Angle 3: Social Proof (Testimonial Cards)
> Use 4:5 Google-review cards or floating overlay cards with the doctor reading the review. Protect patient privacy (no names, faces or identifying details without consent).

---

## 🎬 TikTok / Reels Video Script (9:16)

| Scene | Visual / On-Screen Action | Audio / Voiceover (Malay) |
| :--- | :--- | :--- |
| **00:00 - 00:03** | Hook: close-up doctor or relatable moment | *"Bang, ramai tak tahu perkara ni..."* |
| **00:03 - 00:12** | Doctor explains one point; Vox-style infographic + B-roll | *(Doctor's own words, plain language)* |
| **00:12 - 00:15** | CTA end card | *"Klik butang di bawah / link di bio untuk tempah konsultasi."* |

---

## 📦 Format & Delivery Checklist
- [ ] Poster / video ratio **4:5** (feed) or **9:16** (story/reel); line spacing at least 1.5
- [ ] CTA present (ads: "klik butang di bawah"; organic: "link di bio")
- [ ] Trending audio checked for platform licensing before use
- [ ] Sequenced Threads posts: Intro → Sinker → CTA (with link and location)
- [ ] Kelantan audience: dialect allowed, but keep proper nouns capitalised ("K" besar) and details accurate

## 🔒 Compliance Checklist (run Regulatory check before approval)
- [ ] No absolute claims ("100% sembuh", "pasti berkesan", "terbukti berkesan", "tanpa kesan sampingan")
- [ ] Do not use "ubat kuat" or double-meaning words; prefer "tenaga" over "kekuatan"
- [ ] No explicit anatomy or treatment-room imagery on outdoor media; use three-race models (Malay/Chinese/Indian)
- [ ] Outdoor/billboard: Jawi large, Rumi small, name exactly as in SSM; no English "Clinic/Wellness" in the logo for Kota Bharu
- [ ] Medical disclaimer and approval reference (KKM/LIU) included where required
`;
  }

  /**
   * Reads the project's copywriting Markdown file.
   */
  static getCopywriting(projectPath, projectId, projectTitle = '') {
    const filePath = this.getCopyFilePath(projectPath, projectId);
    let body = '';
    let lastUpdated = null;
    let updatedBy = 'Copywriter';

    if (fs.existsSync(filePath)) {
      try {
        body = fs.readFileSync(filePath, 'utf8');
        const stats = fs.statSync(filePath);
        lastUpdated = stats.mtime.toISOString();
      } catch (err) {
        console.error(`[CopywritingService] Read error for ${filePath}:`, err.message);
      }
    }

    if (!body.trim()) {
      body = this.getDefaultTemplate(projectTitle || projectId);
      // Auto-save the default template so the file is created on NAS
      try {
        fs.writeFileSync(filePath, body, 'utf8');
        lastUpdated = new Date().toISOString();
      } catch (err) {
        console.warn(`[CopywritingService] Auto-save default error:`, err.message);
      }
    }

    const words = body.trim().split(/\s+/).filter(Boolean).length;
    const chars = body.length;
    const readingTimeMin = Math.max(1, Math.ceil(words / 200));

    return {
      filePath,
      body,
      stats: {
        words,
        chars,
        readingTimeMin
      },
      lastUpdated,
      updatedBy
    };
  }

  /**
   * Updates copywriting markdown content for a project.
   */
  static updateCopywriting(projectPath, projectId, bodyContent = '', actor = 'Copywriter', role = 'Copywriter') {
    const filePath = this.getCopyFilePath(projectPath, projectId);
    
    try {
      fs.writeFileSync(filePath, bodyContent, 'utf8');

      AuditService.logEvent({
        actor,
        role,
        action: 'COPYWRITING_UPDATED',
        entityType: 'Project',
        entityId: projectId,
        details: {
          filePath,
          chars: bodyContent.length,
          snippet: bodyContent.length > 80 ? bodyContent.substring(0, 80) + '...' : bodyContent
        }
      });

      const words = bodyContent.trim().split(/\s+/).filter(Boolean).length;
      const chars = bodyContent.length;
      const readingTimeMin = Math.max(1, Math.ceil(words / 200));

      return {
        success: true,
        filePath,
        body: bodyContent,
        stats: {
          words,
          chars,
          readingTimeMin
        },
        lastUpdated: new Date().toISOString(),
        updatedBy: actor
      };
    } catch (err) {
      console.error(`[CopywritingService] Write error for ${filePath}:`, err.message);
      throw new Error(`Failed to save copywriting to NAS: ${err.message}`);
    }
  }
}

module.exports = CopywritingService;
