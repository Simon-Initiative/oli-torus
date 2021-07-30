export const schema = {
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
  id: {
    type: 'string',
  },
  src: {
    type: 'string',
  },
  alt: {
    type: 'string',
  },
  triggerCheck: {
    type: 'boolean',
    format: 'checkbox',
    description: 'if set to true then once audio is played till end, it will fire a check event',
    default: false,
    isVisibleInTrapState: false,
  },
  autoPlay: {
    type: 'boolean',
    format: 'checkbox',
    description: 'if set to true then video player will play automatically',
    default: false,
    isVisibleInTrapState: true,
  },
  startTime: {
    type: 'number',
    description: 'specifies the start time of the video',
    default: 0,
    isVisibleInTrapState: true,
  },
  endTime: {
    type: 'number',
    description: 'specifies the end time of the video',
    default: 0,
    isVisibleInTrapState: true,
  },
  enableReplay: {
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether user can replay the video once its played',
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
    format: 'checkbox',
    description: 'specifies whether user has started playing the video or not',
    default: false,
    isVisibleInTrapState: true,
  },
  currentTime: {
    type: 'number',
    description: 'specifies the current time of the video player in seconds',
    default: 0,
    isVisibleInTrapState: true,
  },
  duration: {
    type: 'number',
    description: 'specifies total duration of the video in seconds',
    default: 0,
    isVisibleInTrapState: true,
  },
  exposureInSeconds: {
    type: 'number',
    description: 'specifies how much of the video has been played, measured in seconds',
    default: 0,
    isVisibleInTrapState: true,
  },
  exposureInPercentage: {
    type: 'number',
    description:
      'specifies, how much of the video has been played as a percentage of its full run-time',
    default: 0,
    isVisibleInTrapState: true,
  },
  hasCompleted: {
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether video was played till end',
    default: false,
    isVisibleInTrapState: true,
  },
  state: {
    type: 'string',
    description:
      'specifies whether user can replay the video once its played. Values can be notStarted/playing/paused/completed',
    default: 'notStarted',
    isVisibleInTrapState: true,
  },
  totalSecondsWatched: {
    type: 'number',
    description: 'specifies total time video was played in second',
    default: 0,
    isVisibleInTrapState: true,
  },
};

export const uiSchema = {};