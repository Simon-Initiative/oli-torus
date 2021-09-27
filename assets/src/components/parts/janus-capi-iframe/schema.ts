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
});

export const adaptivitySchema = ({
  currentModel,
  editorContext,
}: {
  currentModel: any;
  editorContext: string;
}) => {
  const context = editorContext;
  let adaptivitySchema = {};
  const configData: any = currentModel?.custom?.configData;
  if (configData && Array.isArray(configData)) {
    adaptivitySchema = configData.reduce((acc: any, typeToAdaptivitySchemaMap: any) => {
      if (typeToAdaptivitySchemaMap.type) {
        if (context === 'mutate') {
          if (!typeToAdaptivitySchemaMap.readonly) {
            acc[typeToAdaptivitySchemaMap.key] = typeToAdaptivitySchemaMap.type;
          }
        } else {
          acc[typeToAdaptivitySchemaMap.key] = typeToAdaptivitySchemaMap.type;
        }
      }
      return acc;
    }, {});
  }
  return adaptivitySchema;
};

export const uiSchema = {};

export const createSchema = (): Partial<CapiIframeModel> => ({
  customCssClass: '',
  src: '',
  configData: [],
  width: 400,
  height: 400,
});
