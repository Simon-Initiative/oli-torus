import { CapiVariableTypes } from '../../../adaptivity/capi';
import { JSONSchema7Object } from 'json-schema';
import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export interface AudioModel extends JanusAbsolutePositioned, JanusCustomCss {
  src: string;
  customCssClass: string;
  triggerCheck: boolean;
  autoPlay: boolean;
  startTime: number;
  endTime: number;
  enableReplay: boolean;
  subtitles: any;
}

export const schema: JSONSchema7Object = {
  src: {
    title: 'Source',
    type: 'string',
  },
  customCssClass: {
    title: 'Custom CSS Class',
    type: 'string',
  },
  triggerCheck: {
    title: 'Trigger Check',
    type: 'boolean',
    description: 'if set to true then once audio is played till end, it will fire a check event',
    default: false,
  },
  autoPlay: {
    title: 'Auto Play',
    type: 'boolean',
    description: 'if set to true then audio player will play automatically',
    default: false,
  },
  startTime: {
    title: 'Start time(secs)',
    type: 'number',
    description: 'specifies the start time of the audio',
    default: 0,
  },
  endTime: {
    title: 'End time(secs)',
    type: 'number',
    description: 'specifies the end time of the audio',
    default: 0,
  },
  enableReplay: {
    title: 'Enable Replay',
    type: 'boolean',
    description: "specifies whether user can replay the audio once it's played",
    default: true,
  },
  subtitles: {
    title: 'Subtitles',
    type: 'array',
    items: {
      type: 'object',
      properties: {
        default: { type: 'boolean' },
        language: { type: 'string' },
        src: { type: 'string' },
      },
      required: ['src', 'language'],
    },
  },
};

export const uiSchema = {};

export const adaptivitySchema = {
  exposureInSeconds: CapiVariableTypes.NUMBER,
  exposurePercentage: CapiVariableTypes.NUMBER,
  hasStarted: CapiVariableTypes.BOOLEAN,
  hasCompleted: CapiVariableTypes.BOOLEAN,
  totalSecondsWatched: CapiVariableTypes.NUMBER,
  duration: CapiVariableTypes.NUMBER,
  autoPlay: CapiVariableTypes.BOOLEAN,
  state: CapiVariableTypes.ENUM,
  startTime: CapiVariableTypes.NUMBER,
  endTime: CapiVariableTypes.NUMBER,
  currentTime: CapiVariableTypes.NUMBER,
};

export const createSchema = (): Partial<AudioModel> => ({
  src: '',
  customCssClass: '',
  triggerCheck: false,
  autoPlay: false,
  startTime: 0,
  endTime: 0,
  enableReplay: true,
  subtitles: [],
});
