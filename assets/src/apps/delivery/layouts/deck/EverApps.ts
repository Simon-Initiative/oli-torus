import { clone } from 'utils/common';
import { ActivityState } from 'components/activities/types';

export const everAppActivityState: ActivityState = {
  attemptGuid: 'preview_2946819616',
  attemptNumber: 1,
  dateEvaluated: null,
  dateSubmitted: null,
  score: null,
  outOf: null,
  parts: [
    {
      attemptGuid: 'sampleIframeGuid',
      attemptNumber: 1,
      dateEvaluated: null,
      dateSubmitted: null,
      score: null,
      outOf: null,
      response: null,
      feedback: null,
      hints: [],
      partId: 'janus_capi_iframe-3311152192',
      hasMoreAttempts: false,
      hasMoreHints: false,
    },
  ],
  hasMoreAttempts: true,
  hasMoreHints: true,
};

export const EverAppActivity = {
  id: 'aa_3864718503',
  // resourceId: 150,
  content: {
    custom: {
      applyBtnFlag: false,
      applyBtnLabel: '',
      checkButtonLabel: 'Next',
      combineFeedback: false,
      customCssClass: 'everapp-activity',
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
      x: 0,
      y: 0,
      z: 0,
    },
    partsLayout: [
      {
        custom: {
          allowScrolling: true,
          configData: [],
          customCssClass: '',
          height: '100%',
          src: 'https://www.github.com/Simon-Initiative/oli-torus',
          width: '100%',
          x: 0,
          y: 0,
          z: 0,
        },
        id: 'janus_capi_iframe-3311152192',
        type: 'janus-capi-iframe',
      },
    ],
  },
  authoring: {
    parts: [
      {
        id: 'janus_capi_iframe-3311152192',
        inherited: false,
        owner: 'aa_3864718503',
        type: 'janus-capi-iframe',
      },
    ],
    rules: [
      {
        additionalScore: 0,
        conditions: {
          all: [],
          id: 'b:822350168',
        },
        correct: true,
        default: true,
        disabled: false,
        event: {
          params: {
            actions: [
              {
                params: {
                  target: 'next',
                },
                type: 'navigation',
              },
            ],
          },
          type: 'r:1460991306.correct',
        },
        forceProgress: false,
        id: 'r:1460991306.correct',
        name: 'correct',
      },
      {
        additionalScore: 0,
        conditions: {
          all: [],
          id: 'b:2479296787',
        },
        correct: false,
        default: true,
        disabled: false,
        event: {
          params: {
            actions: [
              {
                params: {
                  feedback: {
                    custom: {
                      applyBtnFlag: false,
                      applyBtnLabel: 'Show Solution',
                      facts: [],
                      height: 100,
                      lockCanvasSize: true,
                      mainBtnLabel: 'Next',
                      palette: {
                        fillAlpha: 0,
                        fillColor: 16777215,
                        lineAlpha: 0,
                        lineColor: 16777215,
                        lineStyle: 0,
                        lineThickness: 0.1,
                      },
                      panelHeaderColor: 10027008,
                      panelTitleColor: 16777215,
                      rules: [],
                      width: 350,
                    },
                    partsLayout: [
                      {
                        custom: {
                          customCssClass: '',
                          height: 22,
                          nodes: [
                            {
                              children: [
                                {
                                  children: [
                                    {
                                      children: [],
                                      tag: 'text',
                                      text: 'Incorrect, please try again.',
                                    },
                                  ],
                                  style: {},
                                  tag: 'span',
                                },
                              ],
                              tag: 'p',
                            },
                          ],
                          palette: {
                            fillAlpha: 0,
                            fillColor: 16777215,
                            lineAlpha: 0,
                            lineColor: 16777215,
                            lineStyle: 0,
                            lineThickness: 0.1,
                          },
                          width: 330,
                          x: 10,
                          y: 10,
                          z: 0,
                        },
                        id: 'text_1157879304',
                        type: 'janus-text-flow',
                      },
                    ],
                  },
                  id: 'a_f_2309458557',
                },
                type: 'feedback',
              },
            ],
          },
          type: 'r:962034711.defaultWrong',
        },
        forceProgress: false,
        id: 'r:962034711.defaultWrong',
        name: 'defaultWrong',
      },
    ],
  },
  activityType: {
    authoring_element: 'oli-adaptive-authoring',
    delivery_element: 'oli-adaptive-delivery',
    enabled: true,
    global: false,
    id: 2,
    slug: 'oli_adaptive',
    title: 'Adaptive Activity',
  },
  title: 'EverApp Renderer',
  attemptGuid: 'preview_2946819616',
};

export const getEverAppActivity = (everAppObj: any, url: string, index: number) => {
  const updatedObject = clone(EverAppActivity);
  updatedObject.id = everAppObj.id + index;
  updatedObject.content.partsLayout[0].id = everAppObj.id;
  updatedObject.authoring.parts[0].id = everAppObj.id;
  updatedObject.attemptGuid = everAppObj.attemptGuid + index;
  updatedObject.content.partsLayout[0].custom.src = url;
  return updatedObject;
};

export const updateAttemptGuid = (index: number, everAppObj: any) => {
  const updatedObject = clone(everAppActivityState);
  updatedObject.attemptGuid = `${everAppActivityState.attemptGuid}_${index}`;
  updatedObject.parts[0].partId = everAppObj.id;
  updatedObject.parts[0].attemptGuid = `${everAppObj.id}_${updatedObject.attemptGuid}`;
  return updatedObject;
};

export default EverAppActivity;
