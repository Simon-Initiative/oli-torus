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
    title: 'Verticle Gap',
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
    options: {
      hidden: true,
    },
  },
  mcqItems: {
    title: 'Items',
    type: 'array',
    description: 'list of items in the MCQ',
    items: {
      $ref: '#/definitions/mcqItem',
    },
  },
  enabled: {
    title: 'Enabled',
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether MCQ is enabled',
    default: true,
    isVisibleInTrapState: true,
  },
};

export const uiSchema = {};
