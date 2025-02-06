import { JSONSchema7Object } from 'json-schema';
import { formatExpression } from 'adaptivity/scripting';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import { Expression, JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export interface JanusHubSpokeProperties extends JanusCustomCss, JanusAbsolutePositioned {
  title: string;
}

export interface JanusHubSpokeItemProperties extends JanusCustomCss {
  nodes: [];
  itemId: string;
  layoutType: string;
  totalItems: number;
  groupId: string;
  selected: boolean;
  val: number;
  disabled?: boolean;
  index: number;
  mustVisitAllSpokes: boolean;
  overrideHeight: boolean;
  onConfigOptionClick?: any;
  configureMode?: boolean;
  verticalGap: number;
  spokeFeedback?: string;
}

export interface Item {
  scoreValue: number;
  nodes: any[];
  [key: string]: any;
}
export interface hubSpokeModel extends JanusAbsolutePositioned, JanusCustomCss {
  fontSize?: number;
  overrideHeight?: boolean;
  layoutType: 'horizontalLayout' | 'verticalLayout';
  verticalGap: number;
  enabled: boolean;
  spokeItems: Item[];
  mustVisitAllSpokes: boolean;
  spokeFeedback?: string;
  requiredSpoke?: number;
}

export const simpleSchema: JSONSchema7Object = {
  layoutType: {
    title: 'Layout',
    type: 'string',
    description: 'specifies the layout type of hub and Spoke buttons',
    enum: ['horizontalLayout', 'verticalLayout'],
    default: 'verticalLayout',
  },
  spokeItems: {
    title: 'Number of spokes',
    type: 'array',
    items: {
      type: 'object',
    },
  },
  mustVisitAllSpokes: {
    title: 'Must visit all spokes',
    type: 'boolean',
    default: false,
  },
  requiredSpoke: {
    title: 'Number of required spokes',
    type: 'number',
    enum: [0, 1, 2, 3, 4, 5],
    default: 3,
  },
  showProgressBar: {
    title: 'Show progress bar',
    type: 'boolean',
    default: true,
  },
  correctFeedback: {
    title: 'Complete Feedback',
    description: 'Feedback shown when all the required spokes are completed',
    type: 'string',
    default: '',
  },
  incorrectFeedback: {
    title: 'Incomplete Feedback',
    description: 'Feedback shown when all the required spokes are not completed',
    type: 'string',
    default: '',
  },
  spokeFeedback: {
    title: 'Spoke Feedback',
    description: 'Feedback shown when user visits any spoke',
    type: 'string',
    default: '',
  },
  commonErrorFeedback: {
    title: 'Advanced Feedback',
    type: 'array',
    default: [],
    items: {
      type: 'string',
    },
  },
  allOf: [
    {
      if: {
        properties: {
          anyCorrectAnswer: {
            const: false,
          },
        },
      },
      then: {
        properties: {
          incorrectFeedback: {
            title: 'Incorrect Feedback',
            type: 'string',
            default: '',
          },
        },
      },
    },
  ],
};

export const simpleUiSchema = {
  'ui:order': [
    'layoutType',
    'spokeItems',
    'mustVisitAllSpokes',
    'requiredSpoke',
    'anyCorrectAnswer',
    'showProgressBar',
    'correctFeedback',
    'incorrectFeedback',
    'spokeFeedback',
    'commonErrorFeedback',
  ],
  spokeItems: { 'ui:widget': 'SpokeOptionsEditor' },
  commonErrorFeedback: {
    'ui:widget': 'SpokeCustomErrorFeedbackAuthoring',
  },
};

export const adaptivitySchema = {
  mustVisitAllSpokes: CapiVariableTypes.BOOLEAN,
  requiredSpoke: CapiVariableTypes.NUMBER,
  enabled: CapiVariableTypes.BOOLEAN,
  showProgressBar: CapiVariableTypes.BOOLEAN,
  numberOfSelectedChoices: CapiVariableTypes.NUMBER,
  selectedChoice: CapiVariableTypes.NUMBER,
  selectedChoiceText: CapiVariableTypes.STRING,
  selectedChoices: CapiVariableTypes.ARRAY,
  selectedChoicesText: CapiVariableTypes.ARRAY,
  spokeFeedback: CapiVariableTypes.STRING,
};

export const validateUserConfig = (part: any, owner: any): Expression[] => {
  const brokenExpressions: Expression[] = [];
  part.custom.spokeItems.forEach((element: any) => {
    const evaluatedValue = formatExpression(element.nodes[0]);
    if (evaluatedValue) {
      brokenExpressions.push({
        part,
        owner,
        suggestedFix: evaluatedValue,
        formattedExpression: true,
        message: 'Spoke Options',
      });
    }
  });
  return brokenExpressions;
};

export const uiSchema = {};

export const getCapabilities = () => ({
  configure: true,
  canUseExpression: true,
});

export const createSchema = (): Partial<hubSpokeModel> => {
  const createSimpleOption = (index: number, score = 1) => ({
    scoreValue: score,
    nodes: [
      {
        tag: 'p',
        children: [
          {
            tag: 'span',
            style: {},
            children: [
              {
                tag: 'text',
                text: `Spoke ${index}`,
                children: [],
              },
            ],
          },
        ],
      },
    ],
  });

  return {
    width: 125,
    height: 200,
    overrideHeight: false,
    customCssClass: '',
    layoutType: 'verticalLayout',
    verticalGap: 0,
    showOnAnswersReport: false,
    mustVisitAllSpokes: true,
    requiredSpoke: 3,
    requireManualGrading: false,
    showProgressBar: true,
    enabled: true,
    spokeItems: [1, 2, 3].map(createSimpleOption),
    correctAnswer: [true, true, true],
    correctFeedback: '',
    incorrectFeedback: '',
    spokeFeedback: '',
    commonErrorFeedback: [],
  };
};
