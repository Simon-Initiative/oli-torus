export const schema = {
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
  visible: {
    type: 'boolean',
    format: 'checkbox',
    default: true,
  },
  enabled: {
    type: 'boolean',
    format: 'checkbox',
    default: true,
  },
  textColor: {
    type: 'string',
    description: 'hex color value for text',
  },
  buttonColor: {
    type: 'string',
    description: 'hex color value for button',
  },
  transparent: {
    type: 'boolean',
    format: 'checkbox',
    default: false,
    description: 'specifies if button is transparent',
  },
  ariaLabel: {
    type: 'string',
    description: 'accessibility text label visible to screen readers',
  },
};

export const uiSchema = {};
