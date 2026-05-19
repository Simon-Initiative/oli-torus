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
    this._listener = (e: any) => listener(e, elementId);
    window.addEventListener('beforeunload', this._listener);
  },
  destroyed() {
    window.removeEventListener('beforeunload', this._listener);
  },
};
