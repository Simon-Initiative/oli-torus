export const schema = {
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
    format: 'checkbox',
    description: 'if set to true then once audio is played till end, it will fire a check event',
    default: false,
    isVisibleInTrapState: false,
  },
  autoPlay: {
    title: 'Autoplay',
    type: 'boolean',
    format: 'checkbox',
    description: 'if set to true then video player will play automatically',
    default: false,
    isVisibleInTrapState: true,
  },
  startTime: {
    title: 'Starttime',
    type: 'number',
    description: 'specifies the start time of the video',
    default: 0,
    isVisibleInTrapState: true,
  },
  endTime: {
    title: 'Endtime',
    type: 'number',
    description: 'specifies the end time of the video',
    default: 0,
    isVisibleInTrapState: true,
  },
  enableReplay: {
    title: 'Enable Replay',
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether user can replay the video once its played',
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

export const createSchema = () => ({
  enabled: true,
  subtitles: [],
  enableReplay: true,
  autoPlay: false,
  startTime: 0,
  endTime: 0,
  src: '',
  alt: '',
  customCssClass: '',
  triggerCheck: false,
});
