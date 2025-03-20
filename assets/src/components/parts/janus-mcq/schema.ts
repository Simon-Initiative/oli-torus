import { JSONSchema7Object } from 'json-schema';
import { formatExpression } from 'adaptivity/scripting';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import { Expression, JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export interface McqItem {
  scoreValue: number;
  nodes: any[]; // TODO: a text flow node
  // TODO: rest of typing
  [key: string]: any;
}
export interface McqModel extends JanusAbsolutePositioned, JanusCustomCss {
  fontSize?: number;
  overrideHeight?: boolean;
  layoutType: 'horizontalLayout' | 'verticalLayout';
  verticalGap: number;
  enabled: boolean;
  showLabel: boolean;
  showNumbering: boolean;
  multipleSelection: boolean;
  randomize: boolean;
  mcqItems: McqItem[];
}

export const schema: JSONSchema7Object = {
  overrideHeight: {
    title: 'Override Height',
    type: 'boolean',
    default: false,
    description: 'enable to use the value provided by the height field',
  },
  customCssClass: {
    title: 'Custom CSS Class',
    type: 'string',
  },
  fontSize: {
    title: 'Font Size',
    type: 'number',
    default: 12,
  },
  layoutType: {
    title: 'Layout',
    type: 'string',
    description: 'specifies the layout type for options',
    enum: ['horizontalLayout', 'verticalLayout'],
    default: 'verticalLayout',
  },
  verticalGap: {
    title: 'Vertical Gap',
    type: 'number',
  },
  multipleSelection: {
    title: 'Multiple Selection',
    type: 'boolean',
    default: false,
    description: 'specifies whether multiple items can be selected',
  },
  randomize: {
    title: 'Randomize',
    type: 'boolean',
    description: 'specifies whether to randomize the MCQ items',
    default: false,
  },
  enabled: {
    title: 'Enabled',
    type: 'boolean',
    description: 'specifies whether MCQ is enabled',
    default: true,
  },
};

export const simpleSchema: JSONSchema7Object = {
  layoutType: {
    title: 'Layout',
    type: 'string',
    description: 'specifies the layout type for options',
    enum: ['horizontalLayout', 'verticalLayout'],
    default: 'verticalLayout',
  },
  multipleSelection: {
    title: 'Multiple Selection',
    type: 'boolean',
    default: false,
    description: 'specifies whether multiple items can be selected',
  },
  randomize: {
    title: 'Randomize Order',
    type: 'boolean',
    description: 'specifies whether to randomize the MCQ items',
    default: false,
  },
  mcqItems: {
    title: 'MCQ Items',
    type: 'array',
    items: {
      type: 'object',
    },
  },
  anyCorrectAnswer: {
    title: 'Any answer is correct',
    type: 'boolean',
    default: false,
  },
  correctAnswer: {
    // To support multiple selection, this is an array of whether each option is correct
    title: 'Correct Answer',
    type: 'array',
    items: {
      type: 'boolean',
    },
    default: [true],
  },
  correctFeedback: {
    title: 'Correct Feedback',
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
    'mcqItems',
    'multipleSelection',
    'anyCorrectAnswer',
    'correctAnswer',
    'randomize',
    'correctFeedback',
    'incorrectFeedback',
    'commonErrorFeedback',
  ],
  correctAnswer: { 'ui:widget': 'MCQCorrectAnswerEditor' },
  mcqItems: { 'ui:widget': 'MCQOptionsEditor' },
  correctFeedback: {
    'ui:widget': 'textarea',
    'ui:options': {
      rows: 2,
    },
  },
  incorrectFeedback: {
    'ui:widget': 'MCQCustomErrorFeedbackAuthoring',
  },
};

export const adaptivitySchema = {
  enabled: CapiVariableTypes.BOOLEAN,
  randomize: CapiVariableTypes.BOOLEAN,
  numberOfSelectedChoices: CapiVariableTypes.NUMBER,
  selectedChoice: CapiVariableTypes.NUMBER,
  selectedChoiceText: CapiVariableTypes.STRING,
  selectedChoices: CapiVariableTypes.ARRAY,
  selectedChoicesText: CapiVariableTypes.ARRAY,
};

export const validateUserConfig = (part: any, owner: any): Expression[] => {
  const brokenExpressions: Expression[] = [];
  part.custom.mcqItems.forEach((element: any) => {
    const evaluatedValue = formatExpression(element.nodes[0]);
    if (evaluatedValue) {
      brokenExpressions.push({
        part,
        owner,
        suggestedFix: evaluatedValue,
        formattedExpression: true,
        message: ' MCQ Options',
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

export const createSchema = (): Partial<McqModel> => {
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
                text: `Option ${index}`,
                children: [],
              },
            ],
          },
        ],
      },
    ],
  });

  return {
    overrideHeight: false,
    customCssClass: '',
    layoutType: 'verticalLayout',
    verticalGap: 0,
    maxManualGrade: 0,
    showOnAnswersReport: false,
    requireManualGrading: false,
    showLabel: true,
    multipleSelection: false,
    randomize: false,
    showNumbering: false,
    enabled: true,
    mcqItems: [1, 2, 3].map(createSimpleOption),
    correctAnswer: [true, false, false],
    correctFeedback: '',
    incorrectFeedback: '',
    commonErrorFeedback: [],
  };
};
