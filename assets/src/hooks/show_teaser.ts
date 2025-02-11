export const ShowTeaser = {
  mounted() {
    this.handleEvent('show_teaser', () => {
      this.el.classList.remove('hidden');
      this.el.classList.add('show');
      this.el.style.removeProperty('display');
    });
  },
};
