import { evaluateMathJaxExpressions } from './evaluate_mathjax_expressions';
import { LoadSurveyScripts } from './load_survey_scripts';

type HookWithUpdated = {
  updated?: () => void;
};

type ActivityDetailHook = {
  el: HTMLElement;
};

const forwardUpdated = (hook: unknown, context: unknown) => {
  (hook as HookWithUpdated).updated?.call(context);
};

export const ActivityDetailHooks = {
  mounted(this: ActivityDetailHook) {
    LoadSurveyScripts.mounted.call(this);
    evaluateMathJaxExpressions(this.el);
  },

  updated(this: ActivityDetailHook) {
    forwardUpdated(LoadSurveyScripts, this);
    evaluateMathJaxExpressions(this.el);
  },
};
