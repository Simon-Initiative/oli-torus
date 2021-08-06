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
    title: 'Lock Aspect Ratio',
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether image aspect ratio is locked',
    default: true,
  },
};

export const uiSchema = {};

export const transformModelToSchema = (model: any) => {
  console.log('Image Model -> Schema transformer', model);
  // nothing to do for now
  return model;
};

export const transformSchemaToModel = (schema: any) => {
  console.log('Image Schema -> Model transformer', schema);
  // nothing to do for now
  return schema;
};

interface CreationContext {
  transform?: {
    x: number;
    y: number;
    z: number;
    width: number;
    height: number;
  };
  [key: string]: any;
}

export const createSchema = (context?: CreationContext) => {
  // placeholder image 150px by 150px
  let src = 'https://via.placeholder.com/150';

  if (context?.transform) {
    if (context.transform.width && context.transform.height) {
      src = `https://via.placeholder.com/${context.transform.width}x${context.transform.height}`;
    }
  }
  return {
    customCssClass: '',
    src,
    alt: 'an image',
    scaleContent: true,
    lockAspectRatio: true,
  };
};
