/**
 * CAM STUDIO — COMMERCIAL DISTRIBUTION PORTAL LOGIC
 * Dynamic pricing switch, tab navigation, checkout simulations, and snippet copy.
 */

document.addEventListener('DOMContentLoaded', () => {
  initPricingToggle();
  initPlatformTabs();
  initCopyButtons();
  initModal();
});

// 1. Pricing Toggle (Monthly vs Annual with 17% savings)
function initPricingToggle() {
  const toggle = document.getElementById('pricing-toggle');
  const labelMonthly = document.getElementById('label-monthly');
  const labelAnnual = document.getElementById('label-annual');
  const bizPrice = document.getElementById('price-business');
  const bizPeriod = document.getElementById('period-business');
  const entPrice = document.getElementById('price-enterprise');
  const entPeriod = document.getElementById('period-enterprise');

  let isAnnual = true;

  function updatePricing() {
    if (isAnnual) {
      toggle.classList.add('annual');
      labelAnnual.classList.add('active');
      labelMonthly.classList.remove('active');

      if (bizPrice) bizPrice.textContent = '$490';
      if (bizPeriod) bizPeriod.textContent = '/ year (Save $98)';
      if (entPrice) entPrice.textContent = '$2,290';
      if (entPeriod) entPeriod.textContent = '/ year (Save $458)';
    } else {
      toggle.classList.remove('annual');
      labelAnnual.classList.remove('active');
      labelMonthly.classList.add('active');

      if (bizPrice) bizPrice.textContent = '$49';
      if (bizPeriod) bizPeriod.textContent = '/ month';
      if (entPrice) entPrice.textContent = '$199';
      if (entPeriod) entPeriod.textContent = '/ month';
    }
  }

  if (toggle) {
    toggle.addEventListener('click', () => {
      isAnnual = !isAnnual;
      updatePricing();
    });
  }

  if (labelMonthly) {
    labelMonthly.addEventListener('click', () => {
      isAnnual = false;
      updatePricing();
    });
  }

  if (labelAnnual) {
    labelAnnual.addEventListener('click', () => {
      isAnnual = true;
      updatePricing();
    });
  }

  updatePricing();
}

// 2. Platform Download Tabs
function initPlatformTabs() {
  const tabBtns = document.querySelectorAll('.tab-btn');
  const tabContents = document.querySelectorAll('.tab-content');

  tabBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      const targetPlatform = btn.getAttribute('data-tab');

      tabBtns.forEach(b => b.classList.remove('active'));
      tabContents.forEach(c => c.classList.remove('active'));

      btn.classList.add('active');
      const target = document.getElementById(`tab-${targetPlatform}`);
      if (target) target.classList.add('active');
    });
  });
}

// 3. Clipboard Snippet Copy
function initCopyButtons() {
  const copyBtns = document.querySelectorAll('.copy-btn');

  copyBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      const codeBlock = btn.closest('.code-box').querySelector('code');
      if (!codeBlock) return;

      navigator.clipboard.writeText(codeBlock.innerText.trim()).then(() => {
        const originalText = btn.textContent;
        btn.textContent = 'Copied!';
        setTimeout(() => {
          btn.textContent = originalText;
        }, 2000);
      });
    });
  });
}

// 4. License Checkout & Download Modal
function initModal() {
  const modal = document.getElementById('checkout-modal');
  const closeBtn = document.getElementById('modal-close-btn');
  const triggerBtns = document.querySelectorAll('.trigger-checkout');
  const modalTierName = document.getElementById('modal-tier-name');

  triggerBtns.forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.preventDefault();
      const tier = btn.getAttribute('data-tier') || 'Business';
      if (modalTierName) modalTierName.textContent = tier;
      if (modal) modal.classList.add('active');
    });
  });

  if (closeBtn && modal) {
    closeBtn.addEventListener('click', () => {
      modal.classList.remove('active');
    });
  }

  if (modal) {
    modal.addEventListener('click', (e) => {
      if (e.target === modal) modal.classList.remove('active');
    });
  }
}
