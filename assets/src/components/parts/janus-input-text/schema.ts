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
    title: 'Manual Grade',
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
    description: 'specifies whether label is visible',
    default: true,
  },
  label: {
    title: 'Label',
    type: 'string',
    description: 'text label for the input field',
  },
  prompt: {
    title: 'Prompt',
    type: 'string',
    description: 'placeholder for the input field',
  },
  enabled: {
    title: 'Enabled',
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether textbox is enabled',
    isVisibleInTrapState: true,
    default: true,
  },
};

export const uiSchema = {};

export const requiredFields = ['id'];

export const createSchema = () => ({
  enabled: true,
  customCssClass: '',
  showLabel: true,
  label: 'Input',
  prompt: 'enter some text',
  maxManualGrade: 0,
  showOnAnswersReport: false,
  requireManualGrading: false,
});
