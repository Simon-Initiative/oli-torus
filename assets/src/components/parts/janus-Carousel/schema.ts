import { CapiVariableTypes } from '../../../adaptivity/capi';
import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';
import { JSONSchema7Object } from 'json-schema';

export interface CarouselModel extends JanusAbsolutePositioned, JanusCustomCss {
  customCssClass: string;
  images: { url: string; caption: string; alt: string }[];
  zoom: boolean;
}

export const schema: JSONSchema7Object = {
  customCssClass: {
    title: 'Custom CSS Class',
    type: 'string',
  },
  zoom: {
    type: 'boolean',
    title: 'Enable Zoom',
    description: 'Enables image zoom on double-click',
    default: false,
  },
  images: {
    title: 'Images',
    type: 'array',
    description: 'Images to display in the carousel',
    items: {
      $ref: '#/definitions/image',
    },
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
  zoom: CapiVariableTypes.BOOLEAN,
};

export const createSchema = (): Partial<CarouselModel> => ({
  customCssClass: '',
  zoom: true,
  images: [{ url: '/images/placeholder-image.svg', caption: 'an image at night', alt: 'an image' }],
});
