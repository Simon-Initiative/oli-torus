import { EvaluateMathJaxExpressions } from './evaluate_mathjax_expressions';
import { HighlightCode } from './highlight_code';

// single delegating hook to apply all hooks adjusting special page content elements
export const PageContentHooks = {
  mounted() {
    EvaluateMathJaxExpressions.mounted.call(this);
    HighlightCode.mounted.call(this);
  },
};
