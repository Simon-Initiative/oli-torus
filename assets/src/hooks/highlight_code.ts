export const HighlightCode = {
  mounted() {
    const hljs = (window as any).hljs;

    hljs.configure({
      cssSelector: 'pre code.torus-code',
    });

    hljs.highlightAll();
    hljs.initLineNumbersOnLoad();
  },
};
