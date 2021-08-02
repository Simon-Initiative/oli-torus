export const schema = {
  src: {
    type: 'string'
  },
  customCss: {
    type: 'string'
  },
    cssClasses: {
        type: 'string'
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
        default: 12
    },
    showOnAnswersReport: {
        type: 'boolean',
        format: 'checkbox',
        default: false
    },
    requireManualGrading: {
        type: 'boolean',
        format: 'checkbox',
        default: false
    },
    mode: {
        type: 'string',
        enum: [
            'Config',
            'Student'
        ],
        default: 'Student'
    },
    images: {
        type: 'array',
        description: 'Images to display in the carousel',
        items: {
            $ref: '#/definitions/image'
        }
    },
    zoom: {
        type: 'boolean',
        format: 'checkbox',
        description: 'Enables image zoom on double-click',
      default: false
    }
};

export const uiSchema = {};