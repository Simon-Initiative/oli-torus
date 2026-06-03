// this hook is used to evaluate MathJax expressions in the page
// just after the page is mounted and the websocket connection is established.

type MathJaxHook = {
  el: HTMLElement;
};

const mathJaxSelector = '.formula, .formula-inline, .chat-message';

export const evaluateMathJaxExpressions = (root: ParentNode = document) => {
  const rootElement = root instanceof Element && root.matches(mathJaxSelector) ? [root] : [];
  const elements = [...rootElement, ...Array.from(root.querySelectorAll(mathJaxSelector))];

  const getGlobalLastPromise = () => {
    /* istanbul ignore next */
    let lastPromise = window?.MathJax?.startup?.promise;
    /* istanbul ignore next */
    if (!lastPromise) {
      typeof jest === 'undefined' &&
        console.warn(
          'Load the MathJax script before this one or unpredictable rendering might occur.',
        );
      lastPromise = Promise.resolve();
    }
    return lastPromise;
  };

  const setGlobalLastPromise = (promise: Promise<any>) => {
    window.MathJax.startup.promise = promise;
  };

  let lastPromise = getGlobalLastPromise();
  lastPromise = lastPromise.then(() =>
    window.MathJax.typesetPromise(Array.from(elements) as HTMLElement[]),
  );
  setGlobalLastPromise(lastPromise);
};

export const EvaluateMathJaxExpressions = {
  mounted(this: MathJaxHook) {
    evaluateMathJaxExpressions();
  },
};
