import { IActivity } from "apps/delivery/store/features/activities/slice";

export const screenSchema = {
  title: 'Customize Avatar',
  Size: { width: 1000, height: 500 },
  checkButton: { showCheckBtn: false, checkButtonLabel: '' },
  max: { maxAttempt: 0, maxScore: 0 },
  palette: {},
  customCssClass: '',
  combineFeedback: false,
  trapStateScoreScheme: true,
  negativeScoreAllowed: false,
  screenButton: false,
};

export const transformedSchema = {
  title: 'Customize Avatar',
  width: 1000,
  height: 500,
  customCssClass: '',
  combineFeedback: false,
  showCheckBtn: false,
  checkButtonLabel: '',
  maxAttempt: 0,
  maxScore: 0,
  palette: {},
  trapStateScoreScheme: true,
  negativeScoreAllowed: false,
  screenButton: false,
};

export const screen: IActivity = {
  id: 29,
  resourceId: 29,
  activitySlug: 'customize_avatar_5we6z',
  content: {
    custom: {
      applyBtnFlag: false,
      applyBtnLabel: '',
      combineFeedback: false,
      facts: [],
      lockCanvasSize: false,
      mainBtnLabel: '',
      negativeScoreAllowed: false,
      palette: {
        useHtmlProps: true,
      },
      panelHeaderColor: 0,
      panelTitleColor: 0,
      screenButton: false,
      showCheckBtn: false,
      checkButtonLabel: '',
      trapStateScoreScheme: true,
      width: 1000,
      height: 500,
      maxAttempt: 0,
      maxScore: 0,
      customCssClass: '',
      x: 0,
      y: 0,
      z: 0,
    },
    partsLayout: [{}],
  },
  title: 'Customize Avatar',
};
