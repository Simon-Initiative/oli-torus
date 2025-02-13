export const ShowTeaser = {
  mounted() {
    window.addEventListener("teaser_quick_hide", (event) => {

      // Set the opacity to 0 for this element this.el
      this.el.style.opacity = 0;

      setTimeout(() => {
        this.el.style.opactity = 1;
      }, 500);
    });
  }
}
