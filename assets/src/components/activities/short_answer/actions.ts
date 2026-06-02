import {
  ShortAnswerQuestionType,
  applyMathExpressionConfigToMatchConfig,
  defaultMathExpressionConfig,
  expectedAnswerFromResponse,
  isMathExpressionQuestionType,
  mathExpressionItemConfigForQuestionType,
} from 'components/activities/short_answer/utils';
import { MathExpressionQuestionConfig } from 'data/activities/model/match';
import { Responses } from 'data/activities/model/responses';
import { getPartById } from 'data/activities/model/utils';
import { GradingApproach, HasParts } from '../types';
import { InputType, ShortAnswerModelSchema } from './schema';

export const ShortAnswerActions = {
  setQuestionType(questionType: ShortAnswerQuestionType, partId: string) {
    return (model: ShortAnswerModelSchema) => {
      if (!isMathExpressionQuestionType(questionType)) {
        const inputType = questionType;

        if (model.inputType === inputType) return;

        getPartById(model, partId).responses = Responses.forTextInput();
        model.inputType = inputType;
        delete model.itemConfig;
        return;
      }

      const config = defaultMathExpressionConfig(questionType);
      const correctText = 'Correct';
      const incorrectText = 'Incorrect';

      getPartById(model, partId).responses = Responses.forMathExpressionQuestionType(
        questionType,
        config,
        correctText,
        incorrectText,
      );
      model.inputType = 'math_expression';
      model.itemConfig = mathExpressionItemConfigForQuestionType(questionType, config);
    };
  },

  setMathExpressionConfig(
    questionType: ShortAnswerQuestionType,
    config: MathExpressionQuestionConfig,
    partId: string,
  ) {
    return (model: ShortAnswerModelSchema) => {
      if (!isMathExpressionQuestionType(questionType)) return;

      model.itemConfig = mathExpressionItemConfigForQuestionType(questionType, config);

      getPartById(model, partId).responses.forEach((response) => {
        if (response.matchConfig?.type === 'always') return;
        const matchWrongUnits =
          response.matchConfig?.type === 'math_expression' &&
          response.matchConfig.math.mode === 'unit_aware' &&
          response.matchConfig.math.matchWrongUnits === true;
        const matchMissingUnit =
          response.matchConfig?.type === 'math_expression' &&
          response.matchConfig.math.mode === 'unit_aware' &&
          response.matchConfig.math.matchMissingUnit === true;

        response.matchConfig = applyMathExpressionConfigToMatchConfig(
          questionType,
          response.matchConfig,
          expectedAnswerFromResponse(response),
          config,
          { matchWrongUnits, matchMissingUnit },
        );
        response.rule = '';
      });
    };
  },

  setInputType(inputType: InputType, partId: string) {
    return (model: ShortAnswerModelSchema) => {
      if (model.inputType === inputType) return;

      if (inputType === 'text' || inputType === 'textarea') {
        getPartById(model, partId).responses = Responses.forTextInput();
        delete model.itemConfig;
      } else if (inputType === 'numeric') {
        getPartById(model, partId).responses = Responses.forNumericInput();
        delete model.itemConfig;
      } else if (inputType === 'math') {
        getPartById(model, partId).responses = Responses.forMathInput();
        delete model.itemConfig;
      } else if (inputType === 'math_expression') {
        const questionType = 'algebraic';
        getPartById(model, partId).responses = Responses.forMathExpression();
        model.itemConfig = mathExpressionItemConfigForQuestionType(
          questionType,
          defaultMathExpressionConfig(questionType),
        );
      }

      model.inputType = inputType;
    };
  },
  setGradingApproach(gradingApproach: GradingApproach, partId: string) {
    return (model: HasParts) => {
      getPartById(model, partId).gradingApproach = gradingApproach;
    };
  },
};
