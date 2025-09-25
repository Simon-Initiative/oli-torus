export const CopyToClipboard = {
  mounted() {
    this.el.addEventListener('click', () => {
      const value = this.el.getAttribute('data-copy-text');

      if (!value) return;

      navigator.clipboard.writeText(value).then(() => {
        this.showCopiedTooltip();
      });
    });
  },

  showCopiedTooltip() {
    if (this.el.querySelector('.copied-tooltip')) return;

    const tooltip = document.createElement('span');
    tooltip.className =
      'copied-tooltip absolute -top-7 left-1/2 -translate-x-1/2 bg-black text-white text-xs px-2 py-1 rounded shadow-md opacity-0 transition-opacity duration-300';
    tooltip.innerText = 'Copied';

    this.el.appendChild(tooltip);

    requestAnimationFrame(() => {
      tooltip.classList.add('opacity-100');
    });

    setTimeout(() => {
      tooltip.classList.remove('opacity-100');
      tooltip.classList.add('opacity-0');
      tooltip.addEventListener('transitionend', () => {
        tooltip.remove();
      });
    }, 1200);
  },
};
