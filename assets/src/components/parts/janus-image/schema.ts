export const schema = {
  customCssClass: {
    type: 'string',
  },
  src: {
    type: 'string',
  },
  alt: {
    type: 'string',
    description: 'image description text for SEO/accessibility',
  },
  scaleContent: {
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether the image scales responsively',
    default: true,
  },
  lockAspectRatio: {
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether image aspect ratio is locked',
    default: true,
  },
};

export const uiSchema = {};