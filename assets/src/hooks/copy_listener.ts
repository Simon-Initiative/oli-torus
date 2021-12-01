export const CopyListener = {
  mounted() {
    this.el.addEventListener('click', (_e: any) => {
      const targetText = document.querySelector(this.el.dataset['clipboard-target'])?.value;
      const el = this.el;

      navigator.clipboard.writeText(targetText).then(function () {
        el.innerHTML = 'Copied!';
        setTimeout(() => (el.innerHtml = '<i class="lar la-clipboard"></i> Copy'), 5000);
      });
    });
  },
};
