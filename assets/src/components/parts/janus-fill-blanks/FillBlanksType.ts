import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export interface JanusFillBlanksProperties extends JanusCustomCss, JanusAbsolutePositioned {
  customCss?: string;
  showOnAnswersReport?: boolean;
  requireManualGrading?: boolean;
  maxManualGrade?: string;
  showHints?: boolean;
  mode?: string;
  enabled?: boolean;
  showCodeLineNumbers?: boolean;
  alternateCorrectDelimiter?: string;
  showCorrect?: boolean;
  showSolution?: boolean;
  formValidation?: boolean;
  showValidation?: boolean;
  screenReaderLanguage?: string;
  caseSensitiveAnswers?: boolean;
  content?: any;
  elements?: any;
}
