export const CopyListener = {
  mounted() {
    const clipTargetSelector = this.el.dataset['clipboardTarget'];
    const el = this.el;
    const originalHTML = this.el.innerHTML;

    this.el.addEventListener('click', (_e: any) => {
      const targetText = document.querySelector(clipTargetSelector)?.value;

      navigator.clipboard.writeText(targetText).then(function () {
        el.innerHTML = 'Copied!';
        setTimeout(() => {
          el.innerHTML = originalHTML;
        }, 5000);
      });
    });
  },
};
