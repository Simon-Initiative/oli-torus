import { EvaluateMathJaxExpressions } from './evaluate_mathjax_expressions';
import { LoadSurveyScripts } from './load_survey_scripts';

export const ActivityDetailHooks = {
  mounted() {
    LoadSurveyScripts.mounted.call(this);
    EvaluateMathJaxExpressions.mounted.call(this);
  },
};
