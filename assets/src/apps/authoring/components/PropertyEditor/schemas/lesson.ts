const lessonSchema = {
  type: 'object',
  properties: {
    title: {
      type: 'string',
      options: { label: 'Title' },
    },
    customCssUrl: {
      type: 'string',
      description: 'global css override file for overriding the theme',
      options: { input_width: '500px' },
    },
    customCss: {
      type: 'string',
      description: 'block of css code to be injected into style tag',
      format: 'textarea',
    },
    theme: {
      type: 'string',
      enum: ['torus-theme-light', 'torus-theme-dark'],
    },
  },
};

export default lessonSchema;
