export const ScrollToTarget = {
  mounted() {
    window.addEventListener('phx:scroll-to-target', (e: Event) => {
      const el = document.getElementById((e as CustomEvent).detail.id);
      if (el) {
        el.scrollIntoView({ block: 'start', behavior: 'smooth' });
      }
    });
  },
};
