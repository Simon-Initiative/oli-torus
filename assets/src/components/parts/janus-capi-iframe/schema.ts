import { JSONSchema7Object } from 'json-schema';
import { formatExpression } from 'adaptivity/scripting';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import { Expression, JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export type IframeSourceMode = 'url' | 'page';

export interface IframeSourceEditorConfig {
  mode: IframeSourceMode;
  url: string;
  pageId: number | null;
  pageSlug: string;
}

export interface IframeDynamicLinkFallback {
  type: 'unresolved_internal_source';
  message: string;
  href: string;
}

export interface CapiIframeModel extends JanusAbsolutePositioned, JanusCustomCss {
  src: string;
  source?: string;
  sourceType?: IframeSourceMode;
  sourcePageSlug?: string;
  linkType?: 'page';
  idref?: number;
  resource_id?: number;
  dynamicLinkFallback?: IframeDynamicLinkFallback;
  configData: any;
  allowScrolling: boolean;
}

const SOURCE_PREFIX = '/course/link/';
const defaultSourceConfig = (): IframeSourceEditorConfig => ({
  mode: 'url',
  url: '',
  pageId: null,
  pageSlug: '',
});

const extractCourseLinkSlug = (value: string): string | null => {
  if (!value.startsWith(SOURCE_PREFIX)) {
    return null;
  }
  const slug = value.replace(SOURCE_PREFIX, '');
  return slug.length > 0 ? slug : null;
};

const normalizeSourceConfig = (raw: unknown): IframeSourceEditorConfig => {
  if (!raw || typeof raw !== 'object') {
    return defaultSourceConfig();
  }

  const maybe = raw as Partial<IframeSourceEditorConfig>;
  const mode: IframeSourceMode = maybe.mode === 'page' ? 'page' : 'url';
  const pageId = typeof maybe.pageId === 'number' ? maybe.pageId : null;
  const pageSlug = typeof maybe.pageSlug === 'string' ? maybe.pageSlug : '';
  const url = typeof maybe.url === 'string' ? maybe.url : '';

  return { mode, pageId, pageSlug, url };
};

export const decodeSourceConfig = (source: unknown, fallbackSrc = ''): IframeSourceEditorConfig => {
  if (typeof source === 'string') {
    const raw = source.trim();
    if (raw.length === 0) {
      const fallbackSlug = extractCourseLinkSlug(fallbackSrc);
      return fallbackSlug
        ? { mode: 'page', pageId: null, pageSlug: fallbackSlug, url: '' }
        : { ...defaultSourceConfig(), url: fallbackSrc || '' };
    }

    if (raw.startsWith('{')) {
      try {
        return normalizeSourceConfig(JSON.parse(raw));
      } catch (_e) {
        return { ...defaultSourceConfig(), url: raw };
      }
    }

    const internalSlug = extractCourseLinkSlug(raw);
    return internalSlug
      ? { mode: 'page', pageId: null, pageSlug: internalSlug, url: '' }
      : { ...defaultSourceConfig(), url: raw };
  }

  if (typeof source === 'object') {
    return normalizeSourceConfig(source);
  }

  const fallbackSlug = extractCourseLinkSlug(fallbackSrc);
  return fallbackSlug
    ? { mode: 'page', pageId: null, pageSlug: fallbackSlug, url: '' }
    : { ...defaultSourceConfig(), url: fallbackSrc || '' };
};

export const encodeSourceConfig = (config: IframeSourceEditorConfig): string =>
  JSON.stringify(config);

export const simpleSchema: JSONSchema7Object = {
  source: {
    title: 'Source',
    type: 'string',
  },
  allowScrolling: {
    title: 'Allow Scrolling',
    type: 'boolean',
  },
  description: {
    title: 'description',
    description: 'provides title and aria-label content',
    type: 'string',
  },
};

export const schema: JSONSchema7Object = {
  customCssClass: {
    title: 'Custom CSS class',
    type: 'string',
  },
  source: {
    title: 'Source',
    type: 'string',
  },
  description: {
    title: 'description',
    description: 'provides title and aria-label content',
    type: 'string',
  },
  allowScrolling: {
    title: 'Allow Scrolling',
    type: 'boolean',
  },
};

export const getCapabilities = () => ({
  configure: true,
  canUseExpression: true,
});

export const validateUserConfig = (part: any, owner: any): Expression[] => {
  const brokenExpressions: Expression[] = [];
  part.custom.configData.forEach((element: any) => {
    const evaluatedValue = formatExpression(element);
    if (evaluatedValue && evaluatedValue?.length) {
      brokenExpressions.push({
        key: element.key,
        owner,
        part,
        suggestedFix: evaluatedValue,
        formattedExpression: true,
        message: ` configData - "${element.key}" variable`,
      });
    }
  });
  return [...brokenExpressions];
};

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
      let finalType: CapiVariableTypes = typeToAdaptivitySchemaMap.type;
      if (finalType) {
        if (isNaN(finalType)) {
          console.warn('Type is not a valid CapiVariableType', typeToAdaptivitySchemaMap);
          // attempt to fix the bad type
          if (finalType.toString().toLowerCase() === 'number') {
            finalType = CapiVariableTypes.NUMBER;
          } else if (finalType.toString().toLowerCase() === 'string') {
            finalType = CapiVariableTypes.STRING;
          } else if (finalType.toString().toLowerCase() === 'array') {
            finalType = CapiVariableTypes.ARRAY;
          } else if (finalType.toString().toLowerCase() === 'boolean') {
            finalType = CapiVariableTypes.BOOLEAN;
          } else if (finalType.toString().toLowerCase() === 'enum') {
            finalType = CapiVariableTypes.ENUM;
          } else if (finalType.toString().toLowerCase() === 'math_expr') {
            finalType = CapiVariableTypes.MATH_EXPR;
          } else if (finalType.toString().toLowerCase() === 'array_point') {
            finalType = CapiVariableTypes.ARRAY_POINT;
          } else {
            // couldn't fix it, so just remove it
            return acc;
          }
        }
        if (context === 'mutate') {
          if (!typeToAdaptivitySchemaMap.readonly) {
            acc[typeToAdaptivitySchemaMap.key] = finalType;
          }
        } else {
          acc[typeToAdaptivitySchemaMap.key] = finalType;
        }
      }
      return acc;
    }, {});
  }
  return adaptivitySchema;
};

export const transformModelToSchema = (model: Partial<CapiIframeModel>) => {
  const sourceConfig = decodeSourceConfig(model.source, model.src || '');
  if (model.sourceType === 'page') {
    sourceConfig.mode = 'page';
  } else if (model.sourceType === 'url') {
    sourceConfig.mode = 'url';
  } else if (model.linkType === 'page') {
    // Legacy fallback when explicit sourceType is not available.
    sourceConfig.mode = 'page';
  }
  if (typeof model.idref === 'number') {
    sourceConfig.pageId = model.idref;
  } else if (typeof model.resource_id === 'number') {
    sourceConfig.pageId = model.resource_id;
  }
  if (model.sourcePageSlug && typeof model.sourcePageSlug === 'string') {
    sourceConfig.pageSlug = model.sourcePageSlug;
  }

  return {
    ...model,
    source: encodeSourceConfig(sourceConfig),
  };
};

export const transformSchemaToModel = (schema: Partial<CapiIframeModel>) => {
  const sourceConfig = decodeSourceConfig(schema.source, schema.src || '');
  const {
    source: _source,
    sourceType: _sourceType,
    sourcePageSlug: _sourcePageSlug,
    linkType: _linkType,
    idref: _idref,
    resource_id: _resourceId,
    ...rest
  } = schema;

  if (sourceConfig.mode === 'page') {
    return {
      ...rest,
      src: sourceConfig.pageSlug ? `${SOURCE_PREFIX}${sourceConfig.pageSlug}` : '',
      sourceType: 'page' as const,
      sourcePageSlug: sourceConfig.pageSlug,
      linkType: 'page' as const,
      idref: sourceConfig.pageId ?? undefined,
      resource_id: sourceConfig.pageId ?? undefined,
    };
  }

  return {
    ...rest,
    src: sourceConfig.url,
    sourceType: 'url' as const,
    sourcePageSlug: undefined,
    linkType: undefined,
    idref: undefined,
    resource_id: undefined,
    dynamicLinkFallback: undefined,
  };
};

export const uiSchema = {
  source: {
    'ui:widget': 'IframeSourceEditor',
  },
};

export const simpleUISchema = {
  source: {
    'ui:widget': 'IframeSourceEditor',
  },
};

export const createSchema = (): Partial<CapiIframeModel> => ({
  customCssClass: '',
  src: '',
  source: encodeSourceConfig(defaultSourceConfig()),
  sourceType: 'url',
  allowScrolling: true,
  configData: [],
  width: 400,
  height: 400,
});
