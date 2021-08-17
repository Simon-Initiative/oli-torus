export const schema = {
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
    description: 'Enables image zoom on double-click',
    default: false,
  },
  definitions: {
    image: {
      type: 'object',
      properties: {
        url: {
          type: 'string',
          description: 'Image URL',
        },
        caption: {
          type: 'string',
          description: 'Image caption',
        },
        alt: {
          type: 'string',
          description: 'Image description for screen readers',
        },
      },
    },
  },
};

export const uiSchema = {};

export const createSchema = () => ({
  customCss: '',
  cssClasses: '',
  zoom: true,
  images: [{ url: '/images/placeholder-image.svg', caption: 'an image at night', alt: 'an image' }],
});
