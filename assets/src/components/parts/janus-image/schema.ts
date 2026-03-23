import { JSONSchema7Object } from 'json-schema';
import { CreationContext, JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export interface ImageModel extends JanusAbsolutePositioned, JanusCustomCss {
  src: string;
  imageSrc: string;
  alt: string;
  scaleContent: boolean;
  lockAspectRatio: boolean;
  enableAiTrigger?: boolean;
  aiTriggerPrompt?: string;
  defaultSrc?: string;
}

const baseSchema: JSONSchema7Object = {
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

const baseSimpleSchema: JSONSchema7Object = {
  src: {
    title: 'Source',
    type: 'string',
  },
  alt: {
    title: 'Alternate text',
    type: 'string',
    description: 'image description text for SEO/accessibility',
  },
  lockAspectRatio: {
    title: 'Lock Aspect Ratio',
    type: 'boolean',
    description: 'specifies whether image aspect ratio is locked',
    default: true,
  },
};

const aiTriggerSchema: JSONSchema7Object = {
  enableAiTrigger: {
    title: 'Enable AI Activation Point',
    type: 'boolean',
    default: false,
  },
  aiTriggerPrompt: {
    title: 'AI Activation Prompt',
    type: 'string',
  },
};

export const uiSchema = {
  src: {
    'ui:widget': 'TorusImageBrowser',
  },
  aiTriggerPrompt: {
    'ui:widget': 'textarea',
    'ui:options': {
      rows: 4,
    },
  },
};

export const getSchema = (allowAiTriggers: boolean) =>
  allowAiTriggers ? { ...baseSchema, ...aiTriggerSchema } : baseSchema;

export const getSimpleSchema = (allowAiTriggers: boolean) =>
  allowAiTriggers ? { ...baseSimpleSchema, ...aiTriggerSchema } : baseSimpleSchema;

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
    imageSrc: src,
    alt: 'an image',
    scaleContent: true,
    lockAspectRatio: true,
    enableAiTrigger: false,
    aiTriggerPrompt: '',
    defaultSrc: src,
  };
};
