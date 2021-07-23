export const schema = {
  x: {
    type: 'number',
  },
  y: {
    type: 'number',
  },
  z: {
    type: 'number',
  },
  width: {
    type: 'number',
  },
  height: {
    type: 'number',
  },
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
