export const FixedNavigationBar = {
  mounted() {
    const bottomBar = document.getElementById('bottom-bar');
    if (!bottomBar) return;

    const updateBarVisibility = () => {
      const { scrollTop, scrollHeight } = document.documentElement;
      const windowHeight = window.innerHeight;
      const atBottom = scrollTop + windowHeight >= scrollHeight - 5;
      const noScroll = scrollHeight <= windowHeight;

      if (atBottom || noScroll) {
        bottomBar.classList.add('translate-y-0', 'opacity-100');
        bottomBar.classList.remove('translate-y-full', 'opacity-0');
      } else {
        bottomBar.classList.remove('translate-y-0', 'opacity-100');
        bottomBar.classList.add('translate-y-full', 'opacity-0');
      }
    };

    window.addEventListener('scroll', updateBarVisibility);
    window.addEventListener('resize', updateBarVisibility); // por si cambia el alto
    requestAnimationFrame(updateBarVisibility); // correr al montar

    this.cleanup = () => {
      window.removeEventListener('scroll', updateBarVisibility);
      window.removeEventListener('resize', updateBarVisibility);
    };
  },

  destroyed() {
    this.cleanup?.();
  },
};
