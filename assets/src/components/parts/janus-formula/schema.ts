import { JSONSchema7Object } from 'json-schema';
import { CapiVariableTypes } from 'adaptivity/capi';
import { formatExpression } from 'adaptivity/scripting';
import {
  CreationContext,
  Expression,
  JanusAbsolutePositioned,
  JanusCustomCss,
} from '../types/parts';

export interface FormulaModel extends JanusAbsolutePositioned, JanusCustomCss {
  visible: boolean;
  formula: string;
  formulaAltText: string;
}

export const schema: JSONSchema7Object = {
  visible: {
    type: 'boolean',
    default: true,
    description: 'controls the visibility of the formula',
  },
  customCssClass: { type: 'string' },
};

export const simpleSchema: JSONSchema7Object = {};

export const uiSchema = {};

export const simpleUISchema = {};

export const createSchema = (context?: CreationContext): Partial<FormulaModel> => {
  return {
    visible: true,
    customCssClass: '',
    formula: 'Sample formula',
    formulaAltText: 'Sample formula',
  };
};

export const transformModelToSchema = (model: Partial<FormulaModel>) => {
  return model;
};

export const transformSchemaToModel = (schema: Partial<FormulaModel>) => {
  const { visible, customCssClass } = schema;
  const result: Partial<FormulaModel> = {
    ...schema,
    visible: !!visible,
    customCssClass: customCssClass || '',
  };
  return result;
};

export const validateUserConfig = (part: any, owner: any): Expression[] => {
  const brokenExpressions: Expression[] = [];
  const evaluatedValue = formatExpression(part.custom.formula);
  if (evaluatedValue) {
    brokenExpressions.push({
      item: part,
      part,
      suggestedFix: evaluatedValue,
      owner,
      formattedExpression: true,
    });
  }
  return brokenExpressions;
};

export const adaptivitySchema = {
  visible: CapiVariableTypes.BOOLEAN,
};
export const getCapabilities = () => ({
  configure: true,
});
