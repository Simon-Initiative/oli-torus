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
  },
  autoPlay: {
    title: 'Auto Play',
    type: 'boolean',
    description: 'if set to true then audio player will play automatically',
    default: false,
  },
  startTime: {
    title: 'Start time',
    type: 'number',
    description: 'specifies the start time of the audio',
    default: 0,
  },
  endTime: {
    title: 'End time',
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

export const createSchema = () => ({
  src: '',
  customCssClass: '',
  triggerCheck: false,
  autoPlay: false,
  startTime: 0,
  endTime: 0,
  enableReplay: true,
  subtitles: [],
});
