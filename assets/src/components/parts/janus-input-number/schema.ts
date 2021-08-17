export const schema = {
  defaultID: {
    title: 'Default ID',
    type: 'string',
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
  maxManualGrade: {
    title: 'Max Manual Grade',
    type: 'number',
  },
  number: {
    title: 'Number',
    type: 'number',
  },
  maxValue: {
    title: 'Max Value',
    type: 'number',
  },
  minValue: {
    title: 'Min Value',
    type: 'number',
  },
  showOnAnswersReport: {
    title: 'Answers Report',
    type: 'boolean',
    default: false,
  },
  requireManualGrading: {
    title: 'Require Manual Grading',
    type: 'boolean',
    default: false,
  },
  showLabel: {
    title: 'Show Label',
    type: 'boolean',
    description: 'specifies whether label is visible',
    default: true,
  },
  label: {
    title: 'Label',
    type: 'string',
    description: 'text label for the input field',
  },
  unitsLabel: {
    title: 'Unit Label',
    type: 'string',
    description: 'text label appended to the input',
  },
  deleteEnabled: {
    title: 'Delete Enabled',
    type: 'boolean',
  },
  enabled: {
    title: 'Enabled',
    type: 'boolean',
    description: 'specifies whether number input textbox is enabled',
    default: true,
  },
  showIncrementArrows: {
    title: 'Show Increment Arrows',
    type: 'boolean',
    description: 'specifies whether increment arrows should be visible in number textbox',
    default: false,
  },
};

export const uiSchema = {};

export const createSchema = () => ({
  enabled: true,
  showIncrementArrows: false,
  showLabel: true,
  label: 'How many?',
  unitsLabel: 'quarks',
  deleteEnabled: true,
  requireManualGrading: false,
  maxManualGrade: 0,
  maxValue: 1,
  minValue: 0,
});
