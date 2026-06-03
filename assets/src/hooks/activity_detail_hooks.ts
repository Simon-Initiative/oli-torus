import { evaluateMathJaxExpressions } from './evaluate_mathjax_expressions';
import { LoadSurveyScripts } from './load_survey_scripts';

type HookWithUpdated = {
  updated?: () => void;
};

const forwardUpdated = (hook: unknown, context: unknown) => {
  (hook as HookWithUpdated).updated?.call(context);
};

export const ActivityDetailHooks = {
  mounted() {
    LoadSurveyScripts.mounted.call(this);
    evaluateMathJaxExpressions(this.el);
  },

  updated() {
    forwardUpdated(LoadSurveyScripts, this);
    evaluateMathJaxExpressions(this.el);
  },
};
