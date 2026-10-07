const cleanupByElement = new WeakMap<HTMLElement, () => void>();
let activeDescribedElement: HTMLElement | null = null;
let activePreviousAriaDescribedBy: string | null = null;
const tooltipId = 'global-tooltip-wrapper';

const clearActiveTooltip = () => {
  const wrapper = document.getElementById(tooltipId);
  if (wrapper) wrapper.remove();

  if (activeDescribedElement) {
    if (activePreviousAriaDescribedBy) {
      activeDescribedElement.setAttribute('aria-describedby', activePreviousAriaDescribedBy);
    } else {
      activeDescribedElement.removeAttribute('aria-describedby');
    }
  }

  activeDescribedElement = null;
  activePreviousAriaDescribedBy = null;
};

export const GlobalTooltip = {
  mounted(this: { el: HTMLElement }) {
    const el = this.el;
    let tooltipVisible = false;
    let shownAt = 0;

    const removeTooltip = () => {
      if (activeDescribedElement === el) {
        clearActiveTooltip();
      }

      tooltipVisible = false;
    };

    const showTooltip = () => {
      clearActiveTooltip();

      const wrapper = document.createElement('div');
      wrapper.id = tooltipId;
      wrapper.setAttribute('role', 'tooltip');
      wrapper.className = 'fixed z-[9999] pointer-events-none flex flex-col items-center';
      wrapper.style.visibility = 'hidden'; // Hide initially

      const tooltip = document.createElement('div');
      const bodyStyle = el.dataset.tooltipStyle === 'body';

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
      tooltip.textContent = el.dataset.tooltip || '';

      const caret = document.createElement('div');
      caret.className = `
        w-2 h-2 bg-Surface-surface-background
        border-l-[0.5px] border-b-[0.5px] border-Border-border-default
        -rotate-45 -mt-1
      `;

      wrapper.appendChild(tooltip);
      wrapper.appendChild(caret);
      document.body.appendChild(wrapper);

      activePreviousAriaDescribedBy = el.getAttribute('aria-describedby');
      el.setAttribute(
        'aria-describedby',
        [activePreviousAriaDescribedBy, tooltipId].filter(Boolean).join(' '),
      );
      activeDescribedElement = el;
      tooltipVisible = true;
      shownAt = Date.now();

      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          const rect = el.getBoundingClientRect();
          const wrapperRect = wrapper.getBoundingClientRect();

          const alignLeft = el.dataset.tooltipAlign === 'left';

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

    const handleClick = (event: MouseEvent) => {
      const ownsActiveTooltip = activeDescribedElement === el;

      if (el.dataset.tooltipStopPropagation === 'true') {
        event.stopPropagation();
      }

      if (ownsActiveTooltip && tooltipVisible && Date.now() - shownAt > 100) {
        hideTooltip();
      } else if (!ownsActiveTooltip) {
        showTooltip();
      }
    };

    const handleDocumentClick = (event: MouseEvent) => {
      if (activeDescribedElement === el && !el.contains(event.target as Node)) {
        hideTooltip();
      }
    };

    const handleKeydown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        hideTooltip();
      }
    };

    el.addEventListener('mouseenter', showTooltip);
    el.addEventListener('focus', showTooltip);
    el.addEventListener('click', handleClick);
    el.addEventListener('mouseleave', hideTooltip);
    el.addEventListener('blur', hideTooltip);
    el.addEventListener('keydown', handleKeydown);
    document.addEventListener('click', handleDocumentClick);

    cleanupByElement.set(el, () => {
      removeTooltip();
      el.removeEventListener('mouseenter', showTooltip);
      el.removeEventListener('focus', showTooltip);
      el.removeEventListener('click', handleClick);
      el.removeEventListener('mouseleave', hideTooltip);
      el.removeEventListener('blur', hideTooltip);
      el.removeEventListener('keydown', handleKeydown);
      document.removeEventListener('click', handleDocumentClick);
    });
  },

  destroyed(this: { el: HTMLElement }) {
    cleanupByElement.get(this.el)?.();
    cleanupByElement.delete(this.el);
  },
};
