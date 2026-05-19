import { JSONSchema7Object } from 'json-schema';
import CustomFieldTemplate from 'apps/authoring/components/PropertyEditor/custom/CustomFieldTemplate';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import { iso639_language_codes } from '../../../utils/language-codes-iso639';
import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export interface VideoModel extends JanusAbsolutePositioned, JanusCustomCss {
  src: string;
  alt: string;
  triggerCheck: boolean;
  autoPlay: boolean;
  startTime: number;
  endTime: number;
  enableReplay: boolean;
  subtitles: Array<{
    default?: boolean;
    label?: string;
    language_code?: string;
    src: string;
  }>;
}

const subtitleLanguageEnum = iso639_language_codes.map(({ code }) => code);
const subtitleLanguageEnumNames = iso639_language_codes.map(
  ({ code, name }) => `${name} [${code}]`,
);

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
    title: 'Audio Description (optional)',
    type: 'string',
  },
  triggerCheck: {
    title: 'Trigger Check',
    type: 'boolean',
    description: 'if set to true then once audio is played till end, it will fire a check event',
    default: false,
  },
  autoPlay: {
    title: 'Autoplay',
    type: 'boolean',
    description: 'if set to true then video player will play automatically',
    default: false,
  },
  startTime: {
    title: 'Start time(secs)',
    type: 'number',
    description: 'specifies the start time of the video',
    default: 0,
  },
  endTime: {
    title: 'End time(secs)',
    type: 'number',
    description: 'specifies the end time of the video',
    default: 0,
  },
  enableReplay: {
    title: 'Enable Replay',
    type: 'boolean',
    description: 'specifies whether user can replay the video once its played',
    default: true,
  },
  subtitles: {
    title: 'Subtitles',
    type: 'array',
    items: {
      type: 'object',
      properties: {
        label: { type: 'string', title: 'Label' },
        language_code: {
          type: 'string',
          title: 'Language',
          enum: subtitleLanguageEnum,
          enumNames: subtitleLanguageEnumNames,
        },
        src: { type: 'string', title: 'Caption URL' },
        default: { type: 'boolean', title: 'Default' },
      },
      required: ['src', 'language_code'],
    },
  },
};

export const simpleSchema: JSONSchema7Object = {
  src: {
    title: 'Source',
    type: 'string',
  },
  alt: {
    title: 'Audio Description (optional)',
    type: 'string',
  },
  autoPlay: {
    title: 'Autoplay',
    type: 'boolean',
    description: 'if set to true then video player will play automatically',
    default: false,
  },
  startTime: {
    title: 'Start time(secs)',
    type: 'number',
    description: 'specifies the start time of the video',
    default: 0,
  },
  endTime: {
    title: 'End time(secs)',
    type: 'number',
    description: 'specifies the end time of the video',
    default: 0,
  },
  enableReplay: {
    title: 'Enable Replay',
    type: 'boolean',
    description: 'specifies whether user can replay the video once its played',
    default: true,
  },
  subtitles: {
    title: 'Subtitles',
    type: 'array',
    items: {
      type: 'object',
      properties: {
        label: { type: 'string', title: 'Label' },
        language_code: {
          type: 'string',
          title: 'Language',
          enum: subtitleLanguageEnum,
          enumNames: subtitleLanguageEnumNames,
        },
        src: { type: 'string', title: 'Caption URL' },
        default: { type: 'boolean', title: 'Default' },
      },
      required: ['src', 'language_code'],
    },
  },
};

export const simpleUISchema = {
  'ui:ObjectFieldTemplate': CustomFieldTemplate,
  subtitles: {
    'ui:widget': 'JanusSubtitlesManager',
  },
  src: {
    'ui:widget': 'TorusVideoBrowser',
  },
  startTime: { classNames: 'col-span-6' },
  endTime: { classNames: 'col-span-6' },
};

export const uiSchema = {
  subtitles: {
    'ui:widget': 'JanusSubtitlesManager',
  },
  src: {
    'ui:widget': 'TorusVideoBrowser',
  },
};

export const adaptivitySchema = {
  hasStarted: CapiVariableTypes.BOOLEAN,
  autoPlay: CapiVariableTypes.BOOLEAN,
  currentTime: CapiVariableTypes.STRING,
  duration: CapiVariableTypes.STRING,
  endTime: CapiVariableTypes.STRING,
  exposureInSeconds: CapiVariableTypes.NUMBER,
  exposurePercentage: CapiVariableTypes.NUMBER,
  hasCompleted: CapiVariableTypes.BOOLEAN,
  startTime: CapiVariableTypes.STRING,
  state: CapiVariableTypes.STRING,
  totalSecondsWatched: CapiVariableTypes.STRING,
  enableReplay: CapiVariableTypes.BOOLEAN,
};

export const createSchema = (): Partial<VideoModel> => ({
  enabled: true,
  enableReplay: true,
  autoPlay: false,
  startTime: 0,
  endTime: 0,
  src: '',
  alt: '',
  customCssClass: '',
  triggerCheck: false,
  subtitles: [],
});
