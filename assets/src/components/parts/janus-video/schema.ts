import { CapiVariableTypes } from '../../../adaptivity/capi';
import CustomFieldTemplate from 'apps/authoring/components/PropertyEditor/custom/CustomFieldTemplate';
import { JSONSchema7Object } from 'json-schema';
import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export interface VideoModel extends JanusAbsolutePositioned, JanusCustomCss {
  src: string;
  alt: string;
  triggerCheck: boolean;
  autoPlay: boolean;
  startTime: number;
  endTime: number;
  enableReplay: boolean;
  subtitles: { default: boolean; language: string; src: string };
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
    title: 'Alternate Text',
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
    type: 'object',
    properties: {
      default: { type: 'boolean', title: 'Default' },
      language: { type: 'string', title: 'Language' },
      src: { type: 'string', title: 'Source' },
    },
    required: ['src', 'language'],
  },
};

export const uiSchema = {
  subtitles: {
    'ui:title': 'Subtitles',
    'ui:ObjectFieldTemplate': CustomFieldTemplate,
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
});
