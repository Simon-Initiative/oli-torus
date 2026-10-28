const MARGIN = 8;

// LiveView re-renders the element without the inline style, so every update places it again;
// a window resize changes the room it has, so it places it again too.
export const KeepInViewport = {
  mounted(this: any) {
    this.onResize = () => place(this.el as HTMLElement);
    window.addEventListener('resize', this.onResize);
    place(this.el as HTMLElement);
  },
  updated(this: any) {
    place(this.el as HTMLElement);
  },
  destroyed(this: any) {
    window.removeEventListener('resize', this.onResize);
  },
};

function place(el: HTMLElement) {
  const viewport = document.documentElement.clientWidth;

  el.style.transform = '';
  el.style.maxWidth = `${viewport - 2 * MARGIN}px`;
  if (el.hidden) return;

  const { left, right } = el.getBoundingClientRect();
  const shift = Math.max(MARGIN - left, Math.min(0, viewport - MARGIN - right));

  if (shift !== 0) el.style.transform = `translateX(${shift}px)`;
}
