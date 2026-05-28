import type { MathExpressionSyntaxKind } from 'gleam/torusExpression';
import { MathExpressionQuestionType } from 'data/activities/model/match';

export type MathExpressionDeliveryInputKind = 'numeric' | 'text' | 'math';

export const mathExpressionDeliveryInputKind = (
  questionType?: MathExpressionQuestionType,
): MathExpressionDeliveryInputKind => {
  switch (questionType) {
    case 'numeric':
    case 'integer':
    case 'decimal':
      return 'numeric';
    case 'latex_direct':
      return 'math';
    case 'algebraic':
    case 'number_with_units':
    case 'expression_with_units':
    case 'fraction':
    case 'simplified_fraction':
    default:
      return 'text';
  }
};

export const mathExpressionSyntaxValidationKind = (
  questionType?: MathExpressionQuestionType,
): MathExpressionSyntaxKind | undefined => {
  switch (questionType) {
    case 'algebraic':
    case 'fraction':
    case 'simplified_fraction':
      return 'expression';
    case 'number_with_units':
    case 'expression_with_units':
      return 'quantity';
    default:
      return undefined;
  }
};
