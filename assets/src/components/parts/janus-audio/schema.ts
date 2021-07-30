export const schema = {
  src: {
    type: 'string',
  },
  customCssClass: {
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
  fontSize: {
    type: 'number',
    default: 12,
  },
  triggerCheck: {
    type: 'boolean',
    description: 'if set to true then once audio is played till end, it will fire a check event',
    default: false,
    isVisibleInTrapState: false,
  },
  autoPlay: {
    type: 'boolean',
    description: 'if set to true then audio player will play automatically',
    default: false,
    isVisibleInTrapState: true,
  },
  startTime: {
    type: 'number',
    description: 'specifies the start time of the audio',
    default: 0,
    isVisibleInTrapState: true,
  },
  endTime: {
    type: 'number',
    description: 'specifies the end time of the audio',
    default: 0,
    isVisibleInTrapState: true,
  },
  enableReplay: {
    type: 'boolean',
    description: "specifies whether user can replay the audio once it's played",
    default: true,
    isVisibleInTrapState: false,
  },
  subtitles: {
    type: 'array',
    items: {
      $ref: '../utility/subtitles.schema.json',
    },
  },
  hasStarted: {
    type: 'boolean',
    description: 'specifies whether user has started playing the audio or not',
    default: false,
    isVisibleInTrapState: true,
  },
  currentTime: {
    type: 'number',
    description: 'specifies the current time of the audio player in seconds',
    default: 0,
    isVisibleInTrapState: true,
  },
  duration: {
    type: 'number',
    description: 'specifies total duration of the audio in seconds',
    default: 0,
    isVisibleInTrapState: true,
  },
  exposureInSeconds: {
    type: 'number',
    description: 'specifies how much of the audio has been played, measured in seconds',
    default: 0.0,
    isVisibleInTrapState: true,
  },
  exposureInPercentage: {
    type: 'number',
    description:
      'specifies, how much of the audio has been played as a percentage of its full run-time',
    default: 0,
    isVisibleInTrapState: true,
  },
  hasCompleted: {
    type: 'boolean',
    description: 'specifies whether audio was played till end',
    default: false,
    isVisibleInTrapState: true,
  },
  state: {
    type: 'string',
    description:
      "specifies whether user can replay the audio once it's played. Values can be notStarted/playing/paused/completed",
    default: 'notStarted',
    isVisibleInTrapState: true,
  }
};

export const uiSchema = {};