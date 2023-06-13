const listener = (e: any, elementId?: string) => {
  const element = elementId && document.getElementById(elementId);
  if (!element || element.dataset.saved !== 'true') {
    e.preventDefault();
    e.returnValue = '';
  }
};

export const BeforeUnloadListener = {
  mounted() {
    const elementId = this.el && this.el.id;
    window.addEventListener('beforeunload', (e: any) => listener(e, elementId));
  },
  destroyed() {
    window.removeEventListener('beforeunload', listener);
  },
};
