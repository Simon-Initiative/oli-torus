import { JSONSchema7Object } from 'json-schema';
import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export interface CapiIframeModel extends JanusAbsolutePositioned, JanusCustomCss {
  src: string;
  configData: any;
}

export const schema: JSONSchema7Object = {
  customCssClass: {
    title: 'Custom CSS class',
    type: 'string',
  },
  src: {
    title: 'Source',
    type: 'string',
  },
};

export const getCapabilities = () => ({
  configure: true,
  capi: true,
});

export const uiSchema = {};

export const createSchema = (): Partial<CapiIframeModel> => ({
  customCssClass: '',
  src: '',
  configData: [],
  width: 400,
  height: 400,
});
