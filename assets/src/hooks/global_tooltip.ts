export const GlobalTooltip = {
  mounted() {
    const tooltipId = 'global-tooltip-wrapper';

    const removeTooltip = () => {
      const wrapper = document.getElementById(tooltipId);
      if (wrapper) wrapper.remove();
    };

    const showTooltip = () => {
      removeTooltip();

      const wrapper = document.createElement('div');
      wrapper.id = tooltipId;
      wrapper.className = 'fixed z-[9999] pointer-events-none flex flex-col items-center';
      wrapper.style.visibility = 'hidden'; // Hide initially

      const tooltip = document.createElement('div');
      const bodyStyle = this.el.dataset.tooltipStyle === 'body';

      tooltip.className = bodyStyle
        ? `
          px-3 py-2 min-w-[210px] max-w-[260px] text-Text-text-high text-sm font-normal leading-5
          bg-Surface-surface-background border-[0.5px] border-Border-border-default
          rounded-sm shadow text-left
        `
        : `
          px-2 pb-1.5 pt-2 min-w-[210px] text-Text-text-high text-xs font-bold leading-none
          bg-Surface-surface-background border-[0.5px] border-Border-border-default
          rounded-sm shadow text-center
        `;
      tooltip.textContent = this.el.dataset.tooltip || '';

      const caret = document.createElement('div');
      caret.className = `
        w-2 h-2 bg-Surface-surface-background
        border-l-[0.5px] border-b-[0.5px] border-Border-border-default
        -rotate-45 -mt-1
      `;

      wrapper.appendChild(tooltip);
      wrapper.appendChild(caret);
      document.body.appendChild(wrapper);

      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          const rect = this.el.getBoundingClientRect();
          const wrapperRect = wrapper.getBoundingClientRect();

          const alignLeft = this.el.dataset.tooltipAlign === 'left';

          if (alignLeft) {
            wrapper.style.left = `${rect.left}px`;
            wrapper.style.transform = 'translateX(0)';
          } else {
            wrapper.style.left = `${rect.left + rect.width / 2}px`;
            wrapper.style.transform = 'translateX(-50%)';
          }

          wrapper.style.top = `${rect.top - wrapperRect.height - 4}px`;

          wrapper.style.visibility = 'visible'; // Show after positioning
        });
      });
    };

    const hideTooltip = () => removeTooltip();

    const handleKeydown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        hideTooltip();
      }
    };

    this.el.addEventListener('mouseenter', showTooltip);
    this.el.addEventListener('focus', showTooltip);
    this.el.addEventListener('mouseleave', hideTooltip);
    this.el.addEventListener('blur', hideTooltip);
    this.el.addEventListener('keydown', handleKeydown);

    this.cleanupTooltip = () => {
      removeTooltip();
      this.el.removeEventListener('mouseenter', showTooltip);
      this.el.removeEventListener('focus', showTooltip);
      this.el.removeEventListener('mouseleave', hideTooltip);
      this.el.removeEventListener('blur', hideTooltip);
      this.el.removeEventListener('keydown', handleKeydown);
    };
  },

  destroyed() {
    if (this.cleanupTooltip) this.cleanupTooltip();
  },
};
