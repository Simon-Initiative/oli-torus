export const schema = {
  src: {
    type: 'string',
  },
  customCss: {
    title: 'Custom CSS',
    type: 'string',
  },
  cssClasses: {
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
  showOnAnswersReport: {
    title: 'Show on Answer Report',
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
  mode: {
    title: 'Mode',
    type: 'string',
    enum: ['Config', 'Student'],
    default: 'Student',
  },
  images: {
    title: 'Images',
    type: 'array',
    description: 'Images to display in the carousel',
    items: {
      $ref: '#/definitions/image',
    },
  },
  zoom: {
    type: 'boolean',
    format: 'checkbox',
    description: 'Enables image zoom on double-click',
    default: false,
  },
};

export const uiSchema = {};
