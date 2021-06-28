import { JSONSchema7 } from 'json-schema';
const lessonSchema: JSONSchema7 = {
  type: 'object',
  properties: {
    title: {
      type: 'string',
      title: 'Title' ,
    },
    customCssUrl: {
      type: 'string',
      description: 'global css override file for overriding the theme',
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
