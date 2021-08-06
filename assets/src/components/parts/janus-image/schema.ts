import { CreationContext } from "../types/parts";

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

export const createSchema = (context?: CreationContext) => {
  // maybe use the context to know the path of the images?
  // or bundle data url?
  const src = '/images/placeholder-image.svg';

  return {
    customCssClass: '',
    src,
    alt: 'an image',
    scaleContent: true,
    lockAspectRatio: true,
  };
};
