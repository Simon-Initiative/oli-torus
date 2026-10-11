const MARGIN = 8;

// LiveView re-renders the element without the inline style, so every update places it again.
export const KeepInViewport = {
  mounted(this: any) {
    place(this.el as HTMLElement);
  },
  updated(this: any) {
    place(this.el as HTMLElement);
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
