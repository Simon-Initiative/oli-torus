export const schema = {
  overrideHeight: {
    type: 'boolean',
    format: 'checkbox',
    default: false,
    description: 'enable to use the value provided by the height field',
  },
  customCssClass: {
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
    type: 'number',
    default: 12,
  },
  layoutType: {
    type: 'string',
    description: 'specifies the layout type for options',
    enum: ['horizontalLayout', 'verticalLayout'],
    default: 'verticalLayout',
  },
  borderAlpha: {
    type: 'number',
  },
  borderColor: {
    type: 'number',
  },
  verticalGap: {
    type: 'number',
  },
  maxManualGrade: {
    type: 'number',
  },
  showOnAnswersReport: {
    type: 'boolean',
    format: 'checkbox',
    default: false,
  },
  requireManualGrading: {
    type: 'boolean',
    format: 'checkbox',
    default: false,
  },
  showLabel: {
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether to show the MCQ label',
    default: true,
  },
  multipleSelection: {
    type: 'boolean',
    format: 'checkbox',
    default: false,
    description: 'specifies whether multiple items can be selected',
  },
  randomize: {
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether to randomize the MCQ items',
    default: false,
  },
  showNumbering: {
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether to show numbering on the MCQ items',
    default: false,
    options: {
      hidden: true,
    },
  },
  mcqItems: {
    type: 'array',
    description: 'list of items in the MCQ',
    items: {
      $ref: '#/definitions/mcqItem',
    },
  },
  enabled: {
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether MCQ is enabled',
    default: true,
    isVisibleInTrapState: true,
  },
};

export const uiSchema = {};
