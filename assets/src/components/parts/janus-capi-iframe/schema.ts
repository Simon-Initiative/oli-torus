import { JSONSchema7Object } from 'json-schema';
import { formatExpression } from 'adaptivity/scripting';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import { Expression, JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export interface CapiIframeModel extends JanusAbsolutePositioned, JanusCustomCss {
  src: string;
  configData: any;
  allowScrolling: boolean;
}

export const simpleSchema: JSONSchema7Object = {
  src: {
    title: 'Source',
    type: 'string',
  },
  allowScrolling: {
    title: 'Allow Scrolling',
    type: 'boolean',
  },
  description: {
    title: 'description',
    description: 'provides title and aria-label content',
    type: 'string',
  },
};

export const schema: JSONSchema7Object = {
  customCssClass: {
    title: 'Custom CSS class',
    type: 'string',
  },
  src: {
    title: 'Source',
    type: 'string',
  },
  description: {
    title: 'description',
    description: 'provides title and aria-label content',
    type: 'string',
  },
  allowScrolling: {
    title: 'Allow Scrolling',
    type: 'boolean',
  },
};

export const getCapabilities = () => ({
  configure: true,
  canUseExpression: true,
});

export const validateUserConfig = (part: any, owner: any): Expression[] => {
  const brokenExpressions: Expression[] = [];
  part.custom.configData.forEach((element: any) => {
    const evaluatedValue = formatExpression(element);
    if (evaluatedValue && evaluatedValue?.length) {
      brokenExpressions.push({
        key: element.key,
        owner,
        part,
        suggestedFix: evaluatedValue,
        formattedExpression: true,
        message: ` configData - "${element.key}" variable`,
      });
    }
  });
  return [...brokenExpressions];
};

export const adaptivitySchema = ({
  currentModel,
  editorContext,
}: {
  currentModel: any;
  editorContext: string;
}) => {
  const context = editorContext;
  let adaptivitySchema = {};
  const configData: any = currentModel?.custom?.configData;
  if (configData && Array.isArray(configData)) {
    adaptivitySchema = configData.reduce((acc: any, typeToAdaptivitySchemaMap: any) => {
      let finalType: CapiVariableTypes = typeToAdaptivitySchemaMap.type;
      if (finalType) {
        if (isNaN(finalType)) {
          console.warn('Type is not a valid CapiVariableType', typeToAdaptivitySchemaMap);
          // attempt to fix the bad type
          if (finalType.toString().toLowerCase() === 'number') {
            finalType = CapiVariableTypes.NUMBER;
          } else if (finalType.toString().toLowerCase() === 'string') {
            finalType = CapiVariableTypes.STRING;
          } else if (finalType.toString().toLowerCase() === 'array') {
            finalType = CapiVariableTypes.ARRAY;
          } else if (finalType.toString().toLowerCase() === 'boolean') {
            finalType = CapiVariableTypes.BOOLEAN;
          } else if (finalType.toString().toLowerCase() === 'enum') {
            finalType = CapiVariableTypes.ENUM;
          } else if (finalType.toString().toLowerCase() === 'math_expr') {
            finalType = CapiVariableTypes.MATH_EXPR;
          } else if (finalType.toString().toLowerCase() === 'array_point') {
            finalType = CapiVariableTypes.ARRAY_POINT;
          } else {
            // couldn't fix it, so just remove it
            return acc;
          }
        }
        if (context === 'mutate') {
          if (!typeToAdaptivitySchemaMap.readonly) {
            acc[typeToAdaptivitySchemaMap.key] = finalType;
          }
        } else {
          acc[typeToAdaptivitySchemaMap.key] = finalType;
        }
      }
      return acc;
    }, {});
  }
  return adaptivitySchema;
};

export const uiSchema = {};
export const simpleUISchema = {};

export const createSchema = (): Partial<CapiIframeModel> => ({
  customCssClass: '',
  src: '',
  allowScrolling: false,
  configData: [],
  width: 400,
  height: 400,
});
