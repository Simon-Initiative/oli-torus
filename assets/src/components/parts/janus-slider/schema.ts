export const schema = {
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
  customCssClass: {
    title: 'Custom CSS Class',
    type: 'string',
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
    description: 'text label for the slider',
  },
  showDataTip: {
    title: 'Show Data Tip',
    type: 'boolean',
    format: 'checkbox',
  },
  showValueLabels: {
    title: 'Show Value Labels',
    type: 'boolean',
    format: 'checkbox',
  },
  showTicks: {
    title: 'Show Ticks',
    type: 'boolean',
    format: 'checkbox',
  },
  showThumbByDefault: {
    title: 'Thumb By Default',
    type: 'boolean',
    format: 'checkbox',
  },
  invertScale: {
    title: 'Invert Scale',
    type: 'boolean',
    format: 'checkbox',
  },
  minimum: {
    title: 'Min',
    type: 'number',
  },
  maximum: {
    title: 'Max',
    type: 'number',
  },
  snapInterval: {
    title: 'Interval',
    type: 'number',
  },
  enabled: {
    title: 'Enabled',
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether slider is enabled',
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
  showDataTip: true,
  showValueLabels: true,
  showTicks: true,
  showThumbByDefault: true,
  invertScale: false,
  minimum: 0,
  maximum: 100,
  snapInterval: 1,
  label: 'Slider',
});
