export const schema = {
  defaultID: {
    type: 'string',
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
  maxManualGrade: {
    type: 'number',
  },
  number: {
    type: 'number',
  },
  maxValue: {
    type: 'number',
  },
  minValue: {
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
    description: 'specifies whether label is visible',
    default: true,
  },
  label: {
    type: 'string',
    description: 'text label for the input field',
  },
  unitsLabel: {
    type: 'string',
    description: 'text label appended to the input',
  },
  deleteEnabled: {
    type: 'boolean',
    format: 'checkbox',
  },
  enabled: {
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether number input textbox is enabled',
    isVisibleInTrapState: true,
    default: true,
  },
  showIncrementArrows: {
    type: 'boolean',
    description: 'specifies whether increment arrows should be visible in number textbox',
    default: false,
  },
};

export const uiSchema = {};