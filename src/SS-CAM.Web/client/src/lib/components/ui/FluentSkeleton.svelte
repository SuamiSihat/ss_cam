<script lang="ts">
  let {
    width = '100%',
    height = '16px',
    radius = 'var(--radius-sm)',
    style = '',
    class: className = ''
  } = $props();
</script>

<div
  class="skeleton-block {className}"
  style="width:{width};height:{height};border-radius:{radius};{style}"
  aria-hidden="true"
></div>

<style>
  .skeleton-block {
    display: block;
    background: linear-gradient(
      90deg,
      var(--surface-card-subtle) 25%,
      var(--surface-card-hover, #E8EDF2) 50%,
      var(--surface-card-subtle) 75%
    );
    background-size: 200% 100%;
    animation: skeletonShimmer 1.6s ease-in-out infinite;
  }

  @keyframes skeletonShimmer {
    0%   { background-position: 200% 0; }
    100% { background-position: -200% 0; }
  }
</style>