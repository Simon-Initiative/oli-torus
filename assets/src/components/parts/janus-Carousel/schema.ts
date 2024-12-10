import { JSONSchema7Object } from 'json-schema';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

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
          description: '',
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

export const uiSchema = {
  images: {
    items: {
      url: {
        'ui:widget': 'TorusImageBrowser',
      },
    },
  },
};

export const adaptivitySchema = {
  'Current Image': CapiVariableTypes.NUMBER,
  'Viewed Images Count': CapiVariableTypes.NUMBER,
  zoom: CapiVariableTypes.BOOLEAN,
};

export const createSchema = (): Partial<CarouselModel> => ({
  customCssClass: '',
  zoom: true,
  images: [{ url: '/images/placeholder-image.svg', caption: 'an image at night', alt: 'an image' }],
  width: 400,
  height: 400,
});
