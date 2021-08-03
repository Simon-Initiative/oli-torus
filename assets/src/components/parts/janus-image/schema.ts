export const schema = {
  customCssClass: {
    title: 'Custom CSS Class',
    type: 'string',
  },
  src: {
    title: 'Source',
    type: 'string',
  },
  alt: {
    title: 'Alternate text',
    type: 'string',
    description: 'image description text for SEO/accessibility',
  },
  scaleContent: {
    title: 'Scale Content',
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether the image scales responsively',
    default: true,
  },
  lockAspectRatio: {
    title: 'Locl Aspect Ratio',
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether image aspect ratio is locked',
    default: true,
  },
};

export const uiSchema = {};
