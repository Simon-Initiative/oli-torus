import { IActivity } from '../../../../delivery/store/features/activities/slice';

export type IActivityTemplate = Omit<IActivity, 'id'>;

export const createActivityTemplate = (): IActivityTemplate => ({
  type: 'activity',
  typeSlug: 'oli_adaptive',
  title: '',
  objectives: { attached: [] },
  tags: [],
  model: {
    authoring: {
      parts: [],
      rules: [],
    },
    custom: {
      applyBtnFlag: false,
      applyBtnLabel: '',
      checkButtonLabel: 'Next',
      combineFeedback: false,
      customCssClass: '',
      facts: [],
      lockCanvasSize: false,
      mainBtnLabel: '',
      maxAttempt: 0,
      maxScore: 0,
      negativeScoreAllowed: false,
      palette: {
        backgroundColor: 'rgba(255,255,255,0)',
        borderColor: 'rgba(255,255,255,0)',
        borderRadius: '',
        borderStyle: 'solid',
        borderWidth: '1px',
      },
      panelHeaderColor: 0,
      panelTitleColor: 0,
      showCheckBtn: true,
      trapStateScoreScheme: false,
      width: 800,
      height: 600,
      x: 0,
      y: 0,
      z: 0,
    },
    partsLayout: [],
  },
});
