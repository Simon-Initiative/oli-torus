export const schema = {
  src: {
    title: 'Source',
    type: 'string',
  },
  customCssClass: {
    title: 'Custom CSS Class',
    type: 'string',
  },
  palette: {
    type: 'object',
    properties: {
      backgroundColor: { type: 'string', title: 'Background Color' },
      borderColor: { type: 'string', title: 'Border Color' },
      borderRadius: { type: 'string', title: 'Border Radius' },
      borderStyle: { type: 'string', title: 'Border Style' },
      borderWidth: { type: 'string', title: 'Border Width' },
    },
  },
  triggerCheck: {
    title: 'Trigger Check',
    type: 'boolean',
    description: 'if set to true then once audio is played till end, it will fire a check event',
    default: false,
    isVisibleInTrapState: false,
  },
  autoPlay: {
    title: 'Auto Play',
    type: 'boolean',
    description: 'if set to true then audio player will play automatically',
    default: false,
    isVisibleInTrapState: true,
  },
  startTime: {
    title: 'Start time',
    type: 'number',
    description: 'specifies the start time of the audio',
    default: 0,
    isVisibleInTrapState: true,
  },
  endTime: {
    title: 'End time',
    type: 'number',
    description: 'specifies the end time of the audio',
    default: 0,
    isVisibleInTrapState: true,
  },
  enableReplay: {
    title: 'Enable Replay',
    type: 'boolean',
    description: "specifies whether user can replay the audio once it's played",
    default: true,
    isVisibleInTrapState: false,
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
