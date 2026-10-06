const fs = require('fs');
const path = require('path');
const config = require('../config');

class EmailService {
  constructor() {
    this.transporter = null;
    this.initTransporter();
  }

  initTransporter() {
    if (config.SMTP_HOST && config.SMTP_USER) {
      try {
        const nodemailer = require('nodemailer');
        this.transporter = nodemailer.createTransporter({
          host: config.SMTP_HOST,
          port: config.SMTP_PORT,
          secure: config.SMTP_SECURE,
          auth: {
            user: config.SMTP_USER,
            pass: config.SMTP_PASS
          }
        });
        console.log(`[EmailService] SMTP transporter configured for ${config.SMTP_USER}@${config.SMTP_HOST}:${config.SMTP_PORT}`);
      } catch (err) {
        console.warn(`[EmailService] Failed to initialize nodemailer transporter: ${err.message}. Using fallback logger.`);
        this.transporter = null;
      }
    } else {
      // Outbox log fallback mode
      this.transporter = null;
    }
  }

  getLogDir() {
    const logDir = path.join(config.DATA_DIR, 'logs');
    if (!fs.existsSync(logDir)) {
      try {
        fs.mkdirSync(logDir, { recursive: true });
      } catch (e) { /* ignore */ }
    }
    return logDir;
  }

  async sendMail({ to, subject, html, text }) {
    const from = config.SMTP_FROM;
    const timestamp = new Date().toISOString();

    if (this.transporter) {
      try {
        const info = await this.transporter.sendMail({
          from,
          to,
          subject,
          text,
          html
        });
        console.log(`[EmailService] Sent email to ${to}: ${subject} (id: ${info.messageId})`);
        return { success: true, messageId: info.messageId };
      } catch (err) {
        console.error(`[EmailService] SMTP delivery failed to ${to}:`, err.message);
        this.logToOutbox({ timestamp, to, subject, text, error: err.message });
        return { success: false, error: err.message, fallback: true };
      }
    } else {
      // Fallback: log to mail_outbox.log
      this.logToOutbox({ timestamp, to, subject, text });
      console.log(`[EmailService (Fallback Outbox)] Email queued for ${to}: ${subject}`);
      return { success: true, fallback: true };
    }
  }

  logToOutbox(entry) {
    try {
      const logFile = path.join(this.getLogDir(), 'mail_outbox.log');
      const line = `[${entry.timestamp}] TO: ${entry.to} | SUBJECT: ${entry.subject} | ${entry.error ? 'ERROR: ' + entry.error : 'DISPATCHED (MOCK)'}\n`;
      fs.appendFileSync(logFile, line, 'utf8');
    } catch (e) {
      console.warn('[EmailService] Could not write to outbox log:', e.message);
    }
  }

  /**
   * Fluent 2 styled base HTML email wrapper
   */
  renderEmailShell({ title, subtitle, contentHtml, ctaText, ctaUrl, footerNotice }) {
    const appUrl = config.APP_URL;
    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #0f172a; color: #f8fafc; margin: 0; padding: 24px; }
    .container { max-width: 600px; margin: 0 auto; background-color: #1e293b; border-radius: 12px; border: 1px solid #334155; overflow: hidden; box-shadow: 0 10px 25px rgba(0,0,0,0.5); }
    .header { padding: 24px 32px; background: linear-gradient(135deg, #0284c7 0%, #2563eb 100%); color: #ffffff; text-align: left; }
    .header h1 { margin: 0 0 4px 0; font-size: 20px; font-weight: 700; letter-spacing: -0.02em; }
    .header p { margin: 0; font-size: 13px; opacity: 0.9; }
    .body { padding: 32px; font-size: 15px; line-height: 1.6; color: #cbd5e1; }
    .card-meta { background: #0f172a; border-radius: 8px; border: 1px solid #334155; padding: 16px 20px; margin: 20px 0; font-size: 14px; }
    .card-meta-row { display: flex; justify-content: space-between; margin-bottom: 8px; border-bottom: 1px solid #1e293b; padding-bottom: 8px; }
    .card-meta-row:last-child { margin-bottom: 0; border-bottom: none; padding-bottom: 0; }
    .card-meta-label { color: #94a3b8; font-weight: 600; }
    .card-meta-value { color: #f8fafc; font-weight: 500; }
    .cta-wrap { text-align: center; margin: 32px 0 16px 0; }
    .cta-button { display: inline-block; background: #0284c7; color: #ffffff !important; text-decoration: none; padding: 12px 28px; border-radius: 6px; font-size: 15px; font-weight: 600; box-shadow: 0 4px 12px rgba(2,132,199,0.3); }
    .footer { padding: 20px 32px; background-color: #0f172a; border-top: 1px solid #334155; font-size: 12px; color: #64748b; text-align: center; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>${title}</h1>
      <p>${subtitle || 'SS-CAM Creative Assets Management'}</p>
    </div>
    <div class="body">
      ${contentHtml}
      ${ctaText && ctaUrl ? `
      <div class="cta-wrap">
        <a href="${ctaUrl}" class="cta-button" target="_blank">${ctaText}</a>
      </div>
      ` : ''}
      ${footerNotice ? `<p style="font-size: 12px; color: #94a3b8; margin-top: 24px;">${footerNotice}</p>` : ''}
    </div>
    <div class="footer">
      <div>SuamiSihat Creative Studio · SS-CAM Web Portal v${config.VERSION}</div>
      <div style="margin-top: 4px;">Host: <a href="${appUrl}" style="color: #38bdf8; text-decoration: none;">${appUrl}</a></div>
    </div>
  </div>
</body>
</html>`;
  }

  /**
   * Password Reset Email
   */
  async sendPasswordResetEmail(user, resetToken, clientBaseUrl) {
    const baseUrl = clientBaseUrl || config.APP_URL;
    const resetUrl = `${baseUrl}/#reset-password?token=${encodeURIComponent(resetToken)}`;
    const recipient = user.email || user.username;

    const html = this.renderEmailShell({
      title: 'Password Reset Request',
      subtitle: 'Secure Account Recovery',
      contentHtml: `
        <p>Hello <strong>${user.name || user.username}</strong>,</p>
        <p>We received a request to reset the password for your SS-CAM account (Staff ID: <code>${user.staffId || user.id || 'N/A'}</code>).</p>
        <p>Click the button below to choose a new password. This security link is valid for <strong>30 minutes</strong>.</p>
      `,
      ctaText: 'Reset My Password →',
      ctaUrl: resetUrl,
      footerNotice: 'If you did not request a password reset, you can safely ignore this email. Your current password remains unchanged.'
    });

    const text = `Password Reset Request\n\nHello ${user.name || user.username},\n\nReset your password at: ${resetUrl}\n\nValid for 30 minutes. If you did not request this, please ignore.`;

    return this.sendMail({
      to: recipient,
      subject: '[SS-CAM] Password Reset Request',
      html,
      text
    });
  }

  /**
   * New Task Assignment Email
   */
  async sendTaskAssignedEmail(assigneeUser, task, project, creatorName) {
    if (!assigneeUser?.email) return { success: false, reason: 'No email found for assignee' };

    const baseUrl = config.APP_URL;
    const isCopy = task.role === 'copywriter';
    const ctaUrl = isCopy && project?.id
      ? `${baseUrl}/#copy-studio?project=${encodeURIComponent(project.id)}`
      : `${baseUrl}/#tasks`;

    const html = this.renderEmailShell({
      title: 'New Creative Task Assigned',
      subtitle: `${project.title || project.id} · Priority: ${(project.priority || 'Normal').toUpperCase()}`,
      contentHtml: `
        <p>Hello <strong>${assigneeUser.name || assigneeUser.username}</strong>,</p>
        <p><strong>${creatorName || 'Your Creative Manager'}</strong> has assigned a new task to you:</p>
        
        <div class="card-meta">
          <div class="card-meta-row">
            <span class="card-meta-label">Task</span>
            <span class="card-meta-value">${task.name}</span>
          </div>
          <div class="card-meta-row">
            <span class="card-meta-label">Project ID</span>
            <span class="card-meta-value"><code>${project.id}</code></span>
          </div>
          <div class="card-meta-row">
            <span class="card-meta-label">Brand</span>
            <span class="card-meta-value">${project.brand || 'SuamiSihat'}</span>
          </div>
          <div class="card-meta-row">
            <span class="card-meta-label">Channel</span>
            <span class="card-meta-value">${(task.channel || 'General').toUpperCase()}</span>
          </div>
          <div class="card-meta-row">
            <span class="card-meta-label">Due Date</span>
            <span class="card-meta-value">${project.deadline || 'Standard Production'}</span>
          </div>
          ${task.notes ? `
          <div class="card-meta-row">
            <span class="card-meta-label">Notes</span>
            <span class="card-meta-value">${task.notes}</span>
          </div>` : ''}
        </div>
      `,
      ctaText: isCopy ? '✍️ Open in Copy Studio →' : '📋 Open in Workstream →',
      ctaUrl,
      footerNotice: 'You can update the task progress or discuss requirements directly inside the SS-CAM workspace.'
    });

    const text = `New Task Assigned: ${task.name}\nProject: ${project.id}\nAssigned by: ${creatorName}\nOpen task: ${ctaUrl}`;

    return this.sendMail({
      to: assigneeUser.email,
      subject: `[SS-CAM Task] ${task.name} (${project.id})`,
      html,
      text
    });
  }

  /**
   * Task Ready for Review Email
   */
  async sendTaskReviewAlertEmail(managerUser, task, project, submitterName) {
    if (!managerUser?.email) return { success: false, reason: 'No email found for manager' };

    const baseUrl = config.APP_URL;
    const ctaUrl = `${baseUrl}/#tasks`;

    const html = this.renderEmailShell({
      title: 'Task Ready for Review & QA',
      subtitle: `${project.id} · ${project.title || ''}`,
      contentHtml: `
        <p>Hello <strong>${managerUser.name || managerUser.username}</strong>,</p>
        <p><strong>${submitterName || 'A team member'}</strong> has completed work on <strong>"${task.name}"</strong> and moved the task to <strong>Review & QA</strong>.</p>
        
        <div class="card-meta">
          <div class="card-meta-row">
            <span class="card-meta-label">Task</span>
            <span class="card-meta-value">${task.name}</span>
          </div>
          <div class="card-meta-row">
            <span class="card-meta-label">Project ID</span>
            <span class="card-meta-value"><code>${project.id}</code></span>
          </div>
          <div class="card-meta-row">
            <span class="card-meta-label">Submitted By</span>
            <span class="card-meta-value">${submitterName} (${task.role})</span>
          </div>
          <div class="card-meta-row">
            <span class="card-meta-label">Channel</span>
            <span class="card-meta-value">${(task.channel || 'General').toUpperCase()}</span>
          </div>
        </div>
        <p>Please review the submitted copywriting / assets and submit an approval or revision decision.</p>
      `,
      ctaText: '🔍 Review in Workstream →',
      ctaUrl,
      footerNotice: 'One-click approvals immediately notify the designer and update the project status.'
    });

    const text = `Task Ready for Review: ${task.name}\nProject: ${project.id}\nSubmitted by: ${submitterName}\nReview at: ${ctaUrl}`;

    return this.sendMail({
      to: managerUser.email,
      subject: `[SS-CAM Review] "${task.name}" submitted by ${submitterName}`,
      html,
      text
    });
  }
}

module.exports = new EmailService();
