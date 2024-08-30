// this hook is used to evaluate MathJax expressions in the page
// just after the page is mounted and the websocket connection is established.

export const EvaluateMathJaxExpressions = {
  mounted() {
    const elements = document.querySelectorAll('.formula');

    window.MathJax.typesetPromise(Array.from(elements) as HTMLElement[]);
  },
};
