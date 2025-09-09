export const GlobalTooltip = {
  mounted() {
    this.el.addEventListener('mouseenter', () => {
      const wrapper = document.createElement('div');
      wrapper.id = 'global-tooltip-wrapper';
      wrapper.className = 'fixed z-[9999] pointer-events-none flex flex-col items-center';
      wrapper.style.visibility = 'hidden'; // Hide initially

      const tooltip = document.createElement('div');
      tooltip.className = `
        px-2 pb-1.5 pt-2 min-w-[210px] text-Text-text-high text-xs font-bold leading-none
        bg-Surface-surface-background border-[0.5px] border-Border-border-default
        rounded-sm shadow text-center
      `;
      tooltip.innerHTML = this.el.dataset.tooltip;

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
    });

    this.el.addEventListener('mouseleave', () => {
      const wrapper = document.getElementById('global-tooltip-wrapper');
      if (wrapper) wrapper.remove();
    });
  },
};
