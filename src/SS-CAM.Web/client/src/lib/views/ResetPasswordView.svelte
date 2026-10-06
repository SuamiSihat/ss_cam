<script lang="ts">
  import { onMount } from 'svelte';
  import { ApiClient } from '$lib/services/api';
  import { appState } from '$lib/stores/appState.svelte';

  let token = $state<string>('');
  let isVerifying = $state<boolean>(true);
  let isValid = $state<boolean>(false);
  let verifyError = $state<string | null>(null);
  let targetUser = $state<string>('');

  let newPassword = $state<string>('');
  let confirmPassword = $state<string>('');
  let showPassword = $state<boolean>(false);
  let isSubmitting = $state<boolean>(false);
  let submitError = $state<string | null>(null);
  let isSuccess = $state<boolean>(false);

  function extractToken(): string {
    if (typeof window === 'undefined') return '';
    // 1. Try URL search params (?token=...)
    const urlParams = new URLSearchParams(window.location.search);
    if (urlParams.get('token')) return urlParams.get('token') || '';

    // 2. Try hash query params (#reset-password?token=...)
    const hash = window.location.hash;
    if (hash.includes('?')) {
      const hashParams = new URLSearchParams(hash.substring(hash.indexOf('?') + 1));
      if (hashParams.get('token')) return hashParams.get('token') || '';
    }
    return '';
  }

  onMount(async () => {
    token = extractToken();
    if (!token) {
      isVerifying = false;
      isValid = false;
      verifyError = 'Missing reset token in URL. Please use the link sent to your email.';
      return;
    }

    try {
      const res = await ApiClient.verifyResetToken(token);
      if (res && res.valid) {
        isValid = true;
        targetUser = res.username || res.email || '';
      } else {
        isValid = false;
        verifyError = res.error || 'This reset link has expired or is invalid.';
      }
    } catch (err: any) {
      isValid = false;
      verifyError = err.message || 'Unable to verify reset link.';
    } finally {
      isVerifying = false;
    }
  });

  const passwordStrength = $derived.by(() => {
    const pw = newPassword;
    if (!pw) return 0;
    let score = 0;
    if (pw.length >= 8) score += 25;
    if (/[A-Z]/.test(pw)) score += 25;
    if (/[0-9]/.test(pw)) score += 25;
    if (/[^A-Za-z0-9]/.test(pw)) score += 25;
    return score;
  });

  async function handleSubmit(e: Event) {
    e.preventDefault();
    submitError = null;

    if (newPassword.length < 8) {
      submitError = 'Password must be at least 8 characters long.';
      return;
    }
    if (newPassword !== confirmPassword) {
      submitError = 'Passwords do not match.';
      return;
    }

    isSubmitting = true;
    try {
      const res = await ApiClient.resetPassword(token, newPassword);
      if (res && res.success) {
        isSuccess = true;
        appState.addToast('Password reset successfully. You can now sign in.', 'success');
      } else {
        submitError = res.message || 'Failed to reset password.';
      }
    } catch (err: any) {
      submitError = err.message || 'Error occurred while resetting password.';
    } finally {
      isSubmitting = false;
    }
  }
</script>

<div class="reset-page-wrap">
  <div class="reset-card">
    <div class="reset-header">
      <div class="reset-brand-mark">
        <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#38bdf8" stroke-width="2">
          <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
        </svg>
      </div>
      <h2 class="reset-title">Create New Password</h2>
      <p class="reset-subtitle">SS-CAM Creative Assets Management</p>
    </div>

    {#if isVerifying}
      <div class="state-container">
        <div class="spinner"></div>
        <p>Verifying your security token…</p>
      </div>
    {:else if !isValid}
      <div class="error-banner" role="alert">
        <div class="error-icon">⚠️</div>
        <div class="error-text">
          <strong>Link Expired or Invalid</strong>
          <p>{verifyError}</p>
        </div>
      </div>
      <div class="action-footer">
        <a href="#login" class="back-login-btn">← Back to Sign In</a>
      </div>
    {:else if isSuccess}
      <div class="success-banner">
        <div class="success-icon">✅</div>
        <h3>Password Successfully Changed!</h3>
        <p>Your new password is now active for <strong>{targetUser}</strong>.</p>
        <a href="#login" class="submit-btn" style="text-align: center; text-decoration: none; margin-top: 16px;">
          Sign In Now →
        </a>
      </div>
    {:else}
      <form onsubmit={handleSubmit} class="reset-form">
        <div class="user-chip">
          <span class="user-chip-label">Account</span>
          <span class="user-chip-name">{targetUser}</span>
        </div>

        {#if submitError}
          <div class="error-banner" role="alert">{submitError}</div>
        {/if}

        <div class="form-group">
          <label class="field-label" for="new-pw">New Password</label>
          <div class="pw-input-wrap">
            <input
              id="new-pw"
              type={showPassword ? 'text' : 'password'}
              class="field-input"
              bind:value={newPassword}
              placeholder="Minimum 8 characters"
              required
            />
            <button
              type="button"
              class="eye-btn"
              onclick={() => (showPassword = !showPassword)}
              title="Toggle visibility"
            >
              {showPassword ? '🙈' : '👁️'}
            </button>
          </div>
          {#if newPassword}
            <div class="strength-bar-wrap">
              <div class="strength-bar" style="width: {passwordStrength}%; background: {passwordStrength < 50 ? '#ef4444' : passwordStrength < 75 ? '#f59e0b' : '#10b981'};"></div>
            </div>
          {/if}
        </div>

        <div class="form-group">
          <label class="field-label" for="confirm-pw">Confirm New Password</label>
          <input
            id="confirm-pw"
            type={showPassword ? 'text' : 'password'}
            class="field-input"
            bind:value={confirmPassword}
            placeholder="Re-enter new password"
            required
          />
        </div>

        <button type="submit" class="submit-btn" disabled={isSubmitting}>
          {isSubmitting ? 'Updating Password…' : 'Set New Password'}
        </button>

        <div class="action-footer">
          <a href="#login" class="cancel-link">Cancel</a>
        </div>
      </form>
    {/if}
  </div>
</div>

<style>
  .reset-page-wrap {
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(135deg, #090d16 0%, #0f172a 100%);
    padding: 20px;
  }
  .reset-card {
    width: 100%;
    max-width: 440px;
    background: #1e293b;
    border: 1px solid #334155;
    border-radius: 12px;
    padding: 32px;
    box-shadow: 0 20px 35px rgba(0, 0, 0, 0.4);
  }
  .reset-header {
    text-align: center;
    margin-bottom: 24px;
  }
  .reset-brand-mark {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 52px;
    height: 52px;
    background: rgba(56, 189, 248, 0.1);
    border-radius: 12px;
    margin-bottom: 12px;
  }
  .reset-title {
    font-size: 20px;
    font-weight: 700;
    color: #f8fafc;
    margin: 0 0 4px 0;
  }
  .reset-subtitle {
    font-size: 13px;
    color: #94a3b8;
    margin: 0;
  }
  .state-container {
    text-align: center;
    padding: 32px 0;
    color: #94a3b8;
  }
  .spinner {
    width: 32px;
    height: 32px;
    border: 3px solid rgba(255, 255, 255, 0.1);
    border-top-color: #38bdf8;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
    margin: 0 auto 16px auto;
  }
  @keyframes spin {
    to { transform: rotate(360deg); }
  }
  .user-chip {
    display: flex;
    justify-content: space-between;
    background: #0f172a;
    border: 1px solid #334155;
    border-radius: 8px;
    padding: 10px 14px;
    margin-bottom: 20px;
    font-size: 13px;
  }
  .user-chip-label { color: #64748b; font-weight: 600; }
  .user-chip-name { color: #38bdf8; font-weight: 600; }
  .form-group {
    margin-bottom: 18px;
  }
  .field-label {
    display: block;
    font-size: 13px;
    font-weight: 600;
    color: #cbd5e1;
    margin-bottom: 6px;
  }
  .pw-input-wrap {
    position: relative;
    display: flex;
    align-items: center;
  }
  .field-input {
    width: 100%;
    background: #0f172a;
    border: 1px solid #334155;
    border-radius: 8px;
    padding: 10px 14px;
    color: #f8fafc;
    font-size: 14px;
    outline: none;
    box-sizing: border-box;
  }
  .field-input:focus {
    border-color: #38bdf8;
  }
  .eye-btn {
    position: absolute;
    right: 10px;
    background: none;
    border: none;
    cursor: pointer;
    font-size: 15px;
    padding: 4px;
  }
  .strength-bar-wrap {
    height: 4px;
    background: #334155;
    border-radius: 2px;
    overflow: hidden;
    margin-top: 6px;
  }
  .strength-bar {
    height: 100%;
    transition: width 0.3s ease, background 0.3s ease;
  }
  .submit-btn {
    display: block;
    width: 100%;
    background: #0284c7;
    color: #ffffff;
    border: none;
    border-radius: 8px;
    padding: 12px;
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.15s ease;
  }
  .submit-btn:hover:not(:disabled) {
    background: #0369a1;
  }
  .submit-btn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
  .error-banner {
    background: rgba(239, 68, 68, 0.15);
    border: 1px solid rgba(239, 68, 68, 0.3);
    color: #fca5a5;
    border-radius: 8px;
    padding: 12px;
    font-size: 13px;
    margin-bottom: 16px;
  }
  .success-banner {
    text-align: center;
    padding: 16px 0;
    color: #cbd5e1;
  }
  .success-icon {
    font-size: 40px;
    margin-bottom: 8px;
  }
  .success-banner h3 {
    margin: 0 0 6px 0;
    color: #f8fafc;
  }
  .action-footer {
    text-align: center;
    margin-top: 16px;
  }
  .back-login-btn, .cancel-link {
    color: #94a3b8;
    text-decoration: none;
    font-size: 13px;
  }
  .back-login-btn:hover, .cancel-link:hover {
    color: #f8fafc;
  }
</style>
