export const schema = {
  overrideHeight: {
    title: 'Override Height',
    type: 'boolean',
    format: 'checkbox',
    default: false,
    description: 'enable to use the value provided by the height field',
  },
  customCssClass: {
    title: 'Custom CSS Class',
    type: 'string',
  },
  palette: {
    type: 'object',
    properties: {
      backgroundColor: { type: 'string', title: 'Background Color' },
      borderColor: { type: 'string', title: 'Border Color' },
      borderRadius: { type: 'string', title: 'Border Radius' },
      borderStyle: { type: 'string', title: 'Border Style' },
      borderWidth: { type: 'string', title: 'Border Width' },
    },
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
  maxManualGrade: {
    title: 'Max Manual Grade',
    type: 'number',
  },
  showOnAnswersReport: {
    title: 'Answers Report',
    type: 'boolean',
    format: 'checkbox',
    default: false,
  },
  requireManualGrading: {
    title: 'Require Manual Grading',
    type: 'boolean',
    format: 'checkbox',
    default: false,
  },
  showLabel: {
    title: 'Show Label',
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether to show the MCQ label',
    default: true,
  },
  multipleSelection: {
    title: 'Multiple Selection',
    type: 'boolean',
    format: 'checkbox',
    default: false,
    description: 'specifies whether multiple items can be selected',
  },
  randomize: {
    title: 'Randomize',
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether to randomize the MCQ items',
    default: false,
  },
  showNumbering: {
    title: 'Show Numbering',
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether to show numbering on the MCQ items',
    default: false,
  },
  mcqItems: {
    title: 'Items',
    type: 'array',
    description: 'list of items in the MCQ',
    items: {
      type: 'object',
      properties: {
        scoreValue: {
          type: 'number',
        },
        nodes: {
          type: 'array',
          items: {
            $ref: '#/definitions/node',
          },
        },
      },
    },
  },
  enabled: {
    title: 'Enabled',
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether MCQ is enabled',
    default: true,
  },
  definitions: {
    node: {
      type: 'object',
      properties: {
        tag: {
          type: 'string',
          description: "should be an html tag, exception made for 'text'",
        },
        href: { type: 'string' },
        src: {
          type: 'string',
          description: 'should map from either src OR source',
        },
        alt: { type: 'string' },
        width: { type: 'number' },
        height: { type: 'number' },
        target: { type: 'string' },
        style: { type: 'object' },
        text: { type: 'string', format: 'textarea' },
        children: {
          type: 'array',
          items: { $ref: '#/definitions/node' },
        },
      },
    },
  },
};

export const uiSchema = {};

export const requiredFields = ['id', 'palette'];

export const createSchema = () => {
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
  };
};
