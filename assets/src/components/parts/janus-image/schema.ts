import { JSONSchema7Object } from 'json-schema';
import { CreationContext, JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export interface ImageModel extends JanusAbsolutePositioned, JanusCustomCss {
  src: string;
  alt: string;
  scaleContent: boolean;
  lockAspectRatio: boolean;
  defaultHeight?: number;
  defaultWidth?: number;
  defaultSrc?: string;
}

export const schema: JSONSchema7Object = {
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
    description: 'specifies whether the image scales responsively',
    default: true,
  },
  lockAspectRatio: {
    title: 'Lock Aspect Ratio',
    type: 'boolean',
    description: 'specifies whether image aspect ratio is locked',
    default: true,
  },
};

export const simpleSchema: JSONSchema7Object = {
  src: {
    title: 'Source',
    type: 'string',
  },
  alt: {
    title: 'Alternate text',
    type: 'string',
    description: 'image description text for SEO/accessibility',
  },
};

export const uiSchema = {
  src: {
    'ui:widget': 'TorusImageBrowser',
  },
};

export const transformModelToSchema = (model: Partial<ImageModel>) => {
  /* console.log('Image Model -> Schema transformer', model); */
  // nothing to do for now
  return model;
};

export const transformSchemaToModel = (schema: any) => {
  /* console.log('Image Schema -> Model transformer', schema); */
  // nothing to do for now
  return schema;
};

export const createSchema = (context?: CreationContext): Partial<ImageModel> => {
  // maybe use the context to know the path of the images?
  // or bundle data url?
  const src = '/images/placeholder-image.svg';

  return {
    customCssClass: '',
    src,
    alt: 'an image',
    scaleContent: true,
    lockAspectRatio: true,
    defaultSrc: src,
  };
};
