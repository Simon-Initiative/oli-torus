import { EvaluateMathJaxExpressions } from './evaluate_mathjax_expressions';
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
    EvaluateMathJaxExpressions.mounted.call(this);
  },

  updated() {
    forwardUpdated(LoadSurveyScripts, this);
    forwardUpdated(EvaluateMathJaxExpressions, this);
  },
};
