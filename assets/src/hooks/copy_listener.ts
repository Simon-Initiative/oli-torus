export const CopyListener = {
  mounted() {
    const clipTargetSelector = this.el.dataset['clipboardTarget'];
    const el = this.el;
    const originalHTML = this.el.innerHTML;
    const animate = this.el.dataset['animate'] || false;

    this.el.addEventListener('click', (_e: any) => {
      const targetText =
        document.querySelector(clipTargetSelector)?.value ||
        document.querySelector(clipTargetSelector)?.innerHTML;

      navigator.clipboard.writeText(targetText).then(function () {
        if (animate) {
          el.classList.add('scale-[1.2]');
          setTimeout(() => {
            el.classList.remove('scale-[1.2]');
          }, 300);
        } else {
          el.innerHTML = 'Copied!';
          setTimeout(() => {
            el.innerHTML = originalHTML;
          }, 5000);
        }
      });
    });
  },
};
