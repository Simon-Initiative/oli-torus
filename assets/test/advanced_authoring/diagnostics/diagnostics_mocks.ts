import { IActivity } from 'apps/delivery/store/features/activities/slice';

export const page = {
  graded: false,
  authorEmail: 'admin@example.edu',
  objectives: {
    attached: [],
  },
  title: 'Test Lesson',
  revisionSlug: 'test_lesson',
  resourceId: 2693,
  advancedAuthoring: true,
  advancedDelivery: true,
  displayApplicationChrome: false,
  additionalStylesheets: [
    'https://style.argos.education/default-viewer-themes/1.9.1/css/lesson-spr-theme-light-non-responsive.css',
    'https://someplace.com/custom.css',
  ],
  customCss:
    '.content * {text-decoration: none; padding: 0px; margin:0px;white-space: normal; font-family: Arial; font-size: 13px; font-style: normal;border: none; border-collapse: collapse; border-spacing: 0px;line-height: 1.4; color: black; font-weight:inherit;color: inherit; display: inline-block; -moz-binding: none; text-decoration: none; white-space: normal; border: 0px; max-width:none;}        .content sup {vertical-align: middle; font-size:65%; font-style:inherit;}        .content sub {vertical-align: middle; font-size:65%; font-style:inherit;}        .content em {font-style:italic; display:inline; font-size:inherit;}        .content strong {font-weight:bold; display:inline; font-size:inherit;}        .content label {margin-right:2px; display:inline-block; cursor:auto;}        .content div {display:inline-block; margin-top:1px}        .content input {margin:0px;}        .content span {display:inline; font-size:inherit;}        .content option {display:block;}        .content ul {display:block}        .content ol {display:block}',
  customScript: '',
  custom: {
    advancedAuthoring: true,
    allowBeagle: true,
    allowTreeNavigation: false,
    autoApplyInit: true,
    backgroundGradientBottom: 15921906,
    backgroundGradientTop: 15921906,
    backgroundImageMaintainAspectRatio: true,
    backgroundImageScaleContent: false,
    backgroundImageURL: '',
    chromelessFlag: false,
    customCssUrl: 'https://someplace.com/custom.css',
    defaultScreenHeight: 1000,
    defaultScreenWidth: 1000,
    defaultTextStyle: 5,
    enableHistory: true,
    everApps: [
      {
        iconUrl: 'https://some.ever.app/icons/Glossary.svg',
        id: 'Glossary',
        isVisible: true,
        name: 'Glossary',
        url: 'https://some.ever.app/glossary',
      },
    ],
    globalNumberFormat: 'none',
    headingStyleType: 'Title',
    hideOptionsMenu: false,
    logoutMessage:
      "<b>IMPORTANT:</b> You must close this notice to record your score. <br>Then you're done, congratulations!<br>",
    logoutPanelImageURL: 'https://someplace.com/logo.png',
    renderAccessibleOrderedList: false,
    scoreFixed: true,
    showScore: true,
    stageMaskContent: false,
    stageVerticalAlign: 'top',
    themeId: 'spr-theme-light-non-responsive',
    totalNumberOfQuestions: 80,
    totalScore: 12,
    variables: [
      {
        expression: 'fixedrndm(0,45873,6)+599',
        name: 'projectunlock',
      },
      {
        expression: 'fixedrndm(100,500)',
        name: 'observe1',
      },
      {
        expression: 'rndm(0,180,1)',
        name: 'random_incline',
      },
      {
        expression: 'rndm(-180,180,1)',
        name: 'random_long',
      },
      {
        expression: 'rndm(-30,30,1)',
        name: 'random_tilt',
      },
      {
        expression: 'fixedrndm(10000,50000,1)',
        name: 'hotjupiters',
      },
      {
        expression: 'fixedrndm(8000,48000,1)',
        name: 'awesomeearths',
      },
      {
        expression: 'fixedrndm(1000,300,1)',
        name: 'sofew',
      },
      {
        expression: 'fixedrndm(50000,100000,1)',
        name: 'somany',
      },
    ],
    viewerSkin: 'default',
    maxScore: 12,
  },
};

export const activityWithDuplicateParts: IActivity = {
  id: 29,
  resourceId: 29,
  tags: [],
  activitySlug: 'dupe_parts_abc',
  authoring: {
    activitiesRequiredForEvaluation: [],
    parts: [
      {
        id: 'part_1',
        inherited: false,
        owner: 'dupe_parts_abc_sequence',
        type: 'janus-capi-iframe',
      },
      {
        id: 'part_1',
        inherited: false,
        owner: 'dupe_parts_abc_sequence',
        type: 'janus-capi-iframe',
      },
    ],
    rules: [],
    variablesRequiredForEvaluation: [],
  },
  objectives: {
    part_1: [],
  },
  content: {
    custom: {
      // cut for brevity
      facts: [],
    },
    partsLayout: [
      {
        id: 'part_1',
        type: 'janus-capi-iframe',
        custom: {
          x: 10,
          y: 10,
          z: 10,
          width: 10,
          height: 10,
          enabled: true,
          requiresManualGrading: false,
        },
      },
      {
        id: 'part_1',
        type: 'janus-capi-iframe',
        custom: {
          x: 10,
          y: 10,
          z: 10,
          width: 10,
          height: 10,
          enabled: true,
          requiresManualGrading: false,
        },
      },
    ],
  },
  title: 'Duplicate Part Ids',
};

export const activityWithInvalidPartIds: IActivity = {
  id: 13,
  resourceId: 13,
  tags: [],
  activitySlug: 'bad_parts_abcd123',
  authoring: {
    activitiesRequiredForEvaluation: [],
    parts: [
      {
        id: 'part$$',
        inherited: false,
        owner: 'bad_parts_abcd123_sequenceId',
        type: 'janus-input-text',
      },
    ],
    rules: [],
    variablesRequiredForEvaluation: [],
  },
  objectives: {
    part$$: [],
  },
  content: {
    custom: {
      // cut for brevity
      facts: [],
    },
    partsLayout: [
      {
        id: 'part$$',
        type: 'janus-input-text',
        custom: {
          x: 10,
          y: 10,
          z: 10,
          width: 10,
          height: 10,
          enabled: true,
          requiresManualGrading: false,
        },
      },
    ],
  },
  title: 'Bad Parts',
};
