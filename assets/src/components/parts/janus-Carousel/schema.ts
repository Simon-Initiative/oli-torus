import { CapiVariableTypes } from '../../../adaptivity/capi';
import { JSONSchema7Object } from 'json-schema';
import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export interface CarouselModel extends JanusAbsolutePositioned, JanusCustomCss {
  cssClasses: string;
  images: { url: string; caption: string; alt: string }[];
  zoom: boolean;
}

export const schema: JSONSchema7Object = {
  customCss: {
    title: 'Custom CSS',
    type: 'string',
  },
  cssClasses: {
    title: 'Custom CSS Class',
    type: 'string',
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

export const adaptivitySchema = {
  'Current Image': CapiVariableTypes.NUMBER,
  'Viewed Images Count': CapiVariableTypes.NUMBER,
  customCss: CapiVariableTypes.STRING,
  zoom: CapiVariableTypes.BOOLEAN,
};

export const createSchema = (): Partial<CarouselModel> => ({
  customCss: '',
  cssClasses: '',
  zoom: true,
  images: [{ url: '/images/placeholder-image.svg', caption: 'an image at night', alt: 'an image' }],
});
