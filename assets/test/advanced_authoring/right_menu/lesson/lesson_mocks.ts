export const lessonSchema = {
  Properties: {
    Size: {
      width:1000,
      height: 500,
    },
    Appearance: {
      theme: 'default',
      customCssUrl: 'https://etx-nec.s3-us-west-2.amazonaws.com/css/etx/styles/style_season.css',
    },
    ScoreOverview: {
      enableLessonMax: true,
      lessonMax: 0,
    },
    FinishPanel: {
      logoutMessage: '',
      logoutPanelImageURL: '',
    },
    title: 'Seasons',
    customCSS: '',
    enableHistory: true,
  },
  CustomLogic: {
    variables: JSON.stringify([]),
    customScript: '',
  },
};

export const transformedSchema = {
  custom: {
    defaultScreenWidth: 1000,
    defaultScreenHeight: 500,
    enableLessonMax: true,
    lessonMax: 0,
    enableHistory: true,
    variables: [],
    logoutMessage: '',
    logoutPanelImageURL: '',
  },
  additionalStylesheets: [
    'default',
    'https://etx-nec.s3-us-west-2.amazonaws.com/css/etx/styles/style_season.css',],
  title: 'Seasons',
  customCss: '',
  customScript: '',
};

export const lesson = {
  graded: false,
  authorEmail: 'admin@example.edu',
  objectives: {
    attached: [],
  },
  title: 'Seasons',
  revisionSlug: 'seasons',
  resourceId: 93,
  advancedAuthoring: true,
  advancedDelivery: true,
  displayApplicationChrome: false,
  additionalStylesheets: [
    'default',
    'https://etx-nec.s3-us-west-2.amazonaws.com/css/etx/styles/style_season.css',
  ],
  customCss:
    '',
  customScript: '',
  custom: {
    advancedAuthoring: false,
    allowBeagle: false,
    allowTreeNavigation: false,
    autoApplyInit: false,
    backgroundGradientBottom: 0,
    backgroundGradientTop: 0,
    backgroundImageMaintainAspectRatio: false,
    backgroundImageScaleContent: false,
    backgroundImageURL: '',
    chromelessFlag: false,
    customCssUrl: 'https://etx-nec.s3-us-west-2.amazonaws.com/css/etx/styles/style_season.css',
    defaultScreenHeight: 500,
    defaultScreenWidth: 1000,
    defaultTextStyle: 0,
    enableHistory: true,
    enableLessonMax: true,
    lessonMax: 0,
    globalActivities: [],
    globalNumberFormat: '',
    headingStyleType: '',
    hideOptionsMenu: false,
    logoutMessage: '',
    logoutPanelImageURL: '',
    renderAccessibleOrderedList: false,
    scoreFixed: false,
    showScore: false,
    stageMaskContent: false,
    stageVerticalAlign: '',
    themeId: 'spr-theme-light',
    totalNumberOfQuestions: 0,
    totalScore: 0,
    variables: [],
    viewerSkin: 'default',
  },
};
