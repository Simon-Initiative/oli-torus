import { getOrderedPath } from '../../../src/apps/authoring/components/Flowchart/screens/screen-utils';
import { IActivity } from '../../../src/apps/delivery/store/features/activities/slice';

describe('screen-utils', function () {
  describe('getOrderedPath', function () {
    it('should give me all paths out of the given screen', function () {
      const result = getOrderedPath(sampleScreen, screensLeft);
      expect(result.length).toEqual(3);
      expect(result.map((s) => s.activitySlug)).toEqual([
        'whats_your_favorite_cat',
        'orange_boy',
        'petting_cats',
      ]);
    });
  });
});

const sampleScreen: IActivity = {
  id: 24777,
  resourceId: 24777,
  activitySlug: 'welcome_screen_4vkip',
  activityType: {
    authoring_element: 'oli-adaptive-authoring',
    authoring_script: 'oli_adaptive_authoring.js',
    delivery_element: 'oli-adaptive-delivery',
    delivery_script: 'oli_adaptive_delivery.js',
    enabled: true,
    global: true,
    id: 1,
    petite_label: 'Adaptive',
    slug: 'oli_adaptive',
    title: 'Adaptive Activity',
  },
  content: {
    bibrefs: [],
    custom: {
      applyBtnFlag: false,
      applyBtnLabel: '',
      checkButtonLabel: 'Next',
      combineFeedback: false,
      customCssClass: '',
      facts: [],
      height: 540,
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
      width: 1000,
      x: 0,
      y: 0,
      z: 0,
    },
    partsLayout: [
      {
        custom: {
          customCssClass: '',
          height: 179,
          maxScore: 1,
          nodes: [
            {
              children: [
                {
                  children: [
                    {
                      children: [],
                      style: {},
                      tag: 'text',
                      text: 'Welcome to my sample lesson.',
                    },
                  ],
                  style: {},
                  tag: 'span',
                },
              ],
              style: {},
              tag: 'h1',
            },
            {
              children: [],
              style: {},
              tag: 'p',
            },
            {
              children: [
                {
                  children: [
                    {
                      children: [],
                      style: {},
                      tag: 'text',
                      text: "Over the next few minutes, you'll be asked a series of questions, receive feedback, and possibly re-teaching.",
                    },
                  ],
                  style: {},
                  tag: 'span',
                },
              ],
              style: {},
              tag: 'p',
            },
          ],
          overrideHeight: false,
          overrideWidth: true,
          palette: {
            backgroundColor: 'rgba(255,255,255,0)',
            borderColor: 'rgba(255,255,255,0)',
            borderRadius: 0,
            borderStyle: 'solid',
            borderWidth: '0.1px',
            fillAlpha: 0,
            fillColor: 16777215,
            lineAlpha: 0,
            lineColor: 16777215,
            lineStyle: 0,
            lineThickness: 0.1,
            useHtmlProps: true,
          },
          requiresManualGrading: false,
          visible: true,
          width: 446,
          x: 253,
          y: 30,
          z: 0,
        },
        id: '3459177434',
        type: 'janus-text-flow',
      },
      {
        custom: {
          alt: 'an image',
          customCssClass: '',
          height: 214,
          lockAspectRatio: true,
          maxScore: 1,
          requiresManualGrading: false,
          scaleContent: true,
          src: 'https://placekitten.com/200/139',
          width: 286,
          x: 31,
          y: 292,
          z: 0,
        },
        id: 'janus_image-3687867454',
        type: 'janus-image',
      },
    ],
  },
  authoring: {
    flowchart: {
      paths: [
        {
          completed: true,
          destinationScreenId: 24779,
          id: 'always-go-to',
          label: 'Always',
          priority: 12,
          ruleId: null,
          type: 'always-go-to',
        },
      ],
      screenType: 'welcome_screen',
      templateApplied: true,
    },
    parts: [
      {
        id: '__default',
        inherited: false,
        owner: 'aa_3131838746',
        type: 'janus-text-flow',
      },
    ],
    rules: [
      {
        additionalScore: 0,
        conditions: {
          all: [],
          id: 'b:312624865',
        },
        correct: true,
        default: false,
        disabled: false,
        event: {
          params: {
            actions: [
              {
                params: {
                  target: 'adaptive_activity_vc2i5_868716715',
                },
                type: 'navigation',
              },
            ],
          },
          type: 'r:3431872488.always',
        },
        forceProgress: false,
        id: 'r:1252690529.always',
        name: 'always',
        priority: 1,
      },
    ],
    variablesRequiredForEvaluation: [],
  },
  title: 'Welcome Screen',
  objectives: {
    __default: [],
  },
};

const screensLeft: IActivity[] = [
  {
    id: 24778,
    resourceId: 24778,
    activitySlug: 'end_of_lesson_flnzz',
    activityType: {
      authoring_element: 'oli-adaptive-authoring',
      authoring_script: 'oli_adaptive_authoring.js',
      delivery_element: 'oli-adaptive-delivery',
      delivery_script: 'oli_adaptive_delivery.js',
      enabled: true,
      global: true,
      id: 1,
      petite_label: 'Adaptive',
      slug: 'oli_adaptive',
      title: 'Adaptive Activity',
    },
    content: {
      bibrefs: [],
      custom: {
        applyBtnFlag: false,
        applyBtnLabel: '',
        checkButtonLabel: 'Next',
        combineFeedback: false,
        customCssClass: '',
        facts: [],
        height: 540,
        lockCanvasSize: false,
        mainBtnLabel: '',
        maxAttempt: 3,
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
        width: 1000,
        x: 0,
        y: 0,
        z: 0,
      },
      partsLayout: [
        {
          custom: {
            customCssClass: '',
            height: 77,
            maxScore: 1,
            nodes: [
              {
                children: [
                  {
                    children: [
                      {
                        children: [],
                        style: {},
                        tag: 'text',
                        text: 'Great Job, I hope you scored well.',
                      },
                    ],
                    style: {},
                    tag: 'span',
                  },
                ],
                style: {},
                tag: 'h1',
              },
            ],
            overrideHeight: false,
            overrideWidth: true,
            palette: {
              backgroundColor: 'rgba(255,255,255,0)',
              borderColor: 'rgba(255,255,255,0)',
              borderRadius: 0,
              borderStyle: 'solid',
              borderWidth: '0.1px',
              fillAlpha: 0,
              fillColor: 16777215,
              lineAlpha: 0,
              lineColor: 16777215,
              lineStyle: 0,
              lineThickness: 0.1,
              useHtmlProps: true,
            },
            requiresManualGrading: false,
            visible: true,
            width: 532,
            x: 237,
            y: 188,
            z: 0,
          },
          id: '3306647977',
          type: 'janus-text-flow',
        },
      ],
    },
    authoring: {
      flowchart: {
        paths: [
          {
            completed: true,
            id: 'exit-activity',
            label: 'Exit Activity',
            priority: 20,
            ruleId: null,
            type: 'exit-activity',
          },
        ],
        screenType: 'end_screen',
        templateApplied: true,
      },
      parts: [
        {
          id: '__default',
          inherited: false,
          owner: 'adaptive_activity_9bcmt_1454817970',
          type: 'janus-text-flow',
        },
      ],
      rules: [
        {
          additionalScore: 0,
          conditions: {
            all: [],
            id: 'b:763729395',
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
            type: 'r:232440562.default',
          },
          forceProgress: false,
          id: 'r:3183414881.default',
          name: 'default',
          priority: 1,
        },
      ],
      variablesRequiredForEvaluation: [],
    },
    title: 'End of Lesson',
    objectives: {},
  },
  {
    id: 24780,
    resourceId: 24780,
    activitySlug: 'orange_boy',
    activityType: {
      authoring_element: 'oli-adaptive-authoring',
      authoring_script: 'oli_adaptive_authoring.js',
      delivery_element: 'oli-adaptive-delivery',
      delivery_script: 'oli_adaptive_delivery.js',
      enabled: true,
      global: true,
      id: 1,
      petite_label: 'Adaptive',
      slug: 'oli_adaptive',
      title: 'Adaptive Activity',
    },
    content: {
      bibrefs: [],
      custom: {
        applyBtnFlag: false,
        applyBtnLabel: '',
        checkButtonLabel: 'Next',
        combineFeedback: false,
        customCssClass: '',
        facts: [],
        height: 540,
        lockCanvasSize: false,
        mainBtnLabel: '',
        maxAttempt: 3,
        maxScore: 2,
        negativeScoreAllowed: false,
        objectives: [],
        palette: {
          backgroundColor: 'rgba(255,255,255,0)',
          borderColor: 'rgba(255, 255, 255,100)',
          borderRadius: '10px',
          borderStyle: 'solid',
          borderWidth: '1px',
          useHtmlProps: true,
        },
        panelHeaderColor: 0,
        panelTitleColor: 0,
        showCheckBtn: true,
        trapStateScoreScheme: false,
        width: 1000,
        x: 0,
        y: 0,
        z: 0,
      },
      partsLayout: [
        {
          custom: {
            customCssClass: '',
            height: 98,
            maxScore: 1,
            nodes: [
              {
                children: [
                  {
                    children: [
                      {
                        children: [],
                        style: {},
                        tag: 'text',
                        text: 'Orange Cats',
                      },
                    ],
                    style: {},
                    tag: 'span',
                  },
                ],
                style: {},
                tag: 'h1',
              },
              {
                children: [
                  {
                    children: [
                      {
                        children: [],
                        style: {},
                        tag: 'text',
                        text: "Listen, I know orange cats are great. But aren't all cats great?",
                      },
                    ],
                    style: {},
                    tag: 'span',
                  },
                ],
                style: {},
                tag: 'p',
              },
            ],
            overrideHeight: false,
            overrideWidth: true,
            palette: {
              backgroundColor: 'rgba(255,255,255,0)',
              borderColor: 'rgba(255,255,255,0)',
              borderRadius: 0,
              borderStyle: 'solid',
              borderWidth: '0.1px',
              fillAlpha: 0,
              fillColor: 16777215,
              lineAlpha: 0,
              lineColor: 16777215,
              lineStyle: 0,
              lineThickness: 0.1,
              useHtmlProps: true,
            },
            requiresManualGrading: false,
            visible: true,
            width: 478,
            x: 37,
            y: 23,
            z: 0,
          },
          id: '1946084182',
          type: 'janus-text-flow',
        },
        {
          custom: {
            alt: 'an image',
            customCssClass: '',
            height: 313,
            lockAspectRatio: true,
            maxScore: 1,
            requiresManualGrading: false,
            scaleContent: true,
            src: 'https://placekitten.com/420/420',
            width: 333,
            x: 29,
            y: 197,
            z: 0,
          },
          id: 'janus_image-393411418',
          type: 'janus-image',
        },
        {
          custom: {
            commonErrorFeedback: [],
            correctAnswer: 0,
            correctFeedback: "Great, let's move on!",
            customCssClass: '',
            enabled: true,
            fontSize: 12,
            height: 100,
            incorrectFeedback: 'You monster.',
            label: 'Choose',
            maxScore: 1,
            optionLabels: ['Yes!', 'No!'],
            prompt: '',
            requiresManualGrading: false,
            showLabel: true,
            width: 418,
            x: 401,
            y: 227,
            z: 0,
          },
          id: 'janus_dropdown-1213141000',
          type: 'janus-dropdown',
        },
      ],
    },
    authoring: {
      flowchart: {
        paths: [
          {
            completed: false,
            id: 'end-of-activity',
            label: 'Go To End Screen',
            priority: 16,
            ruleId: null,
            type: 'end-of-activity',
          },
        ],
        screenType: 'blank_screen',
        templateApplied: true,
      },
      parts: [
        {
          gradingApproach: 'automatic',
          id: 'janus_dropdown-1213141000',
          inherited: false,
          outOf: 1,
          owner: 'adaptive_activity_xtgzh_3892286377',
          type: 'janus-dropdown',
        },
      ],
      rules: [
        {
          additionalScore: 0,
          conditions: {
            all: [
              {
                fact: 'stage.janus_dropdown-1213141000.selectedIndex',
                id: '2569490686',
                operator: 'equal',
                type: 1,
                value: '0',
              },
            ],
            id: 'b:3036759945',
          },
          correct: true,
          default: true,
          disabled: false,
          event: {
            params: {
              actions: [
                {
                  params: {
                    target: 'adaptive_activity_9bcmt_1454817970',
                  },
                  type: 'navigation',
                },
                {
                  id: '2296201303',
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
                            height: 91,
                            maxScore: 1,
                            nodes: [
                              {
                                children: [
                                  {
                                    children: [
                                      {
                                        children: [],
                                        style: {},
                                        tag: 'text',
                                        text: "Great, let's move on!",
                                      },
                                    ],
                                    style: {},
                                    tag: 'span',
                                  },
                                ],
                                style: {
                                  textAlign: 'center',
                                },
                                tag: 'p',
                              },
                            ],
                            overrideHeight: false,
                            overrideWidth: true,
                            palette: {
                              backgroundColor: 'rgba(255,255,255,0)',
                              borderColor: 'rgba(255,255,255,0)',
                              borderRadius: 0,
                              borderStyle: 'solid',
                              borderWidth: '0.1px',
                              useHtmlProps: true,
                            },
                            requiresManualGrading: false,
                            visible: true,
                            width: 340,
                            x: 4,
                            y: 5,
                            z: 0,
                          },
                          id: '',
                          type: 'janus-text-flow',
                        },
                      ],
                    },
                    id: '',
                  },
                  type: 'feedback',
                },
                {
                  params: {
                    operator: '=',
                    target: 'stage.janus_dropdown-1213141000.enabled',
                    targetType: 4,
                    value: 'false',
                  },
                  type: 'mutateState',
                },
              ],
            },
            type: 'r:1338073054.correct',
          },
          forceProgress: false,
          id: 'r:1189933513.correct',
          name: 'correct',
          priority: 10,
        },
        {
          additionalScore: 0,
          conditions: {
            all: [
              {
                fact: 'stage.janus_dropdown-1213141000.selectedItem',
                id: '3636754426',
                operator: 'equal',
                type: 2,
                value: '',
              },
            ],
            id: 'b:2508139376',
          },
          correct: false,
          default: false,
          disabled: false,
          event: {
            params: {
              actions: [
                {
                  id: '732483643',
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
                            height: 91,
                            maxScore: 1,
                            nodes: [
                              {
                                children: [
                                  {
                                    children: [
                                      {
                                        children: [],
                                        style: {},
                                        tag: 'text',
                                        text: 'Please choose an answer.',
                                      },
                                    ],
                                    style: {},
                                    tag: 'span',
                                  },
                                ],
                                style: {
                                  textAlign: 'center',
                                },
                                tag: 'p',
                              },
                            ],
                            overrideHeight: false,
                            overrideWidth: true,
                            palette: {
                              backgroundColor: 'rgba(255,255,255,0)',
                              borderColor: 'rgba(255,255,255,0)',
                              borderRadius: 0,
                              borderStyle: 'solid',
                              borderWidth: '0.1px',
                              useHtmlProps: true,
                            },
                            requiresManualGrading: false,
                            visible: true,
                            width: 340,
                            x: 4,
                            y: 5,
                            z: 0,
                          },
                          id: '',
                          type: 'janus-text-flow',
                        },
                      ],
                    },
                    id: '',
                  },
                  type: 'feedback',
                },
                {
                  params: {
                    operator: 'setting to',
                    target: 'session.attemptNumber',
                    targetType: 1,
                    value: '1',
                  },
                  type: 'mutateState',
                },
              ],
            },
            type: 'r:1606742759.blank',
          },
          forceProgress: false,
          id: 'r:7229243.blank',
          name: 'blank',
          priority: 20,
        },
        {
          additionalScore: 0,
          conditions: {
            all: [
              {
                fact: 'session.attemptNumber',
                id: '3082911423',
                operator: 'greaterThan',
                type: 1,
                value: '2',
              },
              {
                fact: 'stage.janus_dropdown-1213141000.selectedIndex',
                id: '479321304',
                operator: 'notEqual',
                type: 1,
                value: '0',
              },
            ],
            id: 'b:3276963259',
          },
          correct: false,
          default: false,
          disabled: false,
          event: {
            params: {
              actions: [
                {
                  params: {
                    target: 'adaptive_activity_9bcmt_1454817970',
                  },
                  type: 'navigation',
                },
                {
                  id: '2097228887',
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
                            height: 91,
                            maxScore: 1,
                            nodes: [
                              {
                                children: [
                                  {
                                    children: [
                                      {
                                        children: [],
                                        style: {},
                                        tag: 'text',
                                        text: 'You seem to be having trouble. We have filled in the correct answer for you. Click next to continue.',
                                      },
                                    ],
                                    style: {},
                                    tag: 'span',
                                  },
                                ],
                                style: {
                                  textAlign: 'center',
                                },
                                tag: 'p',
                              },
                            ],
                            overrideHeight: false,
                            overrideWidth: true,
                            palette: {
                              backgroundColor: 'rgba(255,255,255,0)',
                              borderColor: 'rgba(255,255,255,0)',
                              borderRadius: 0,
                              borderStyle: 'solid',
                              borderWidth: '0.1px',
                              useHtmlProps: true,
                            },
                            requiresManualGrading: false,
                            visible: true,
                            width: 340,
                            x: 4,
                            y: 5,
                            z: 0,
                          },
                          id: '',
                          type: 'janus-text-flow',
                        },
                      ],
                    },
                    id: '',
                  },
                  type: 'feedback',
                },
                {
                  params: {
                    operator: '=',
                    target: 'stage.janus_dropdown-1213141000.selectedIndex',
                    targetType: 1,
                    value: '0',
                  },
                  type: 'mutateState',
                },
                {
                  params: {
                    operator: '=',
                    target: 'stage.janus_dropdown-1213141000.enabled',
                    targetType: 4,
                    value: 'false',
                  },
                  type: 'mutateState',
                },
              ],
            },
            type: 'r:1039546168.incorrect-3-times',
          },
          forceProgress: false,
          id: 'r:2898677058.incorrect-3-times',
          name: 'incorrect-3-times',
          priority: 40,
        },
        {
          additionalScore: 0,
          conditions: {
            all: [],
            id: 'b:740199880',
          },
          correct: false,
          default: true,
          disabled: false,
          event: {
            params: {
              actions: [
                {
                  id: '3109620666',
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
                            height: 91,
                            maxScore: 1,
                            nodes: [
                              {
                                children: [
                                  {
                                    children: [
                                      {
                                        children: [],
                                        style: {},
                                        tag: 'text',
                                        text: 'You monster.',
                                      },
                                    ],
                                    style: {},
                                    tag: 'span',
                                  },
                                ],
                                style: {
                                  textAlign: 'center',
                                },
                                tag: 'p',
                              },
                            ],
                            overrideHeight: false,
                            overrideWidth: true,
                            palette: {
                              backgroundColor: 'rgba(255,255,255,0)',
                              borderColor: 'rgba(255,255,255,0)',
                              borderRadius: 0,
                              borderStyle: 'solid',
                              borderWidth: '0.1px',
                              useHtmlProps: true,
                            },
                            requiresManualGrading: false,
                            visible: true,
                            width: 340,
                            x: 4,
                            y: 5,
                            z: 0,
                          },
                          id: '',
                          type: 'janus-text-flow',
                        },
                      ],
                    },
                    id: '',
                  },
                  type: 'feedback',
                },
              ],
            },
            type: 'r:682741240.default-incorrect',
          },
          forceProgress: false,
          id: 'r:1377044684.default-incorrect',
          name: 'default-incorrect',
          priority: 70,
        },
      ],
      variablesRequiredForEvaluation: [
        'stage.janus_dropdown-1213141000.selectedItem',
        'session.attemptNumber',
        'stage.janus_dropdown-1213141000.selectedIndex',
        'stage.janus_dropdown-1213141000.enabled',
      ],
    },
    title: 'Orange Boy',
    objectives: {},
  },
  {
    id: 24781,
    resourceId: 24781,
    activitySlug: 'petting_cats',
    activityType: {
      authoring_element: 'oli-adaptive-authoring',
      authoring_script: 'oli_adaptive_authoring.js',
      delivery_element: 'oli-adaptive-delivery',
      delivery_script: 'oli_adaptive_delivery.js',
      enabled: true,
      global: true,
      id: 1,
      petite_label: 'Adaptive',
      slug: 'oli_adaptive',
      title: 'Adaptive Activity',
    },
    content: {
      bibrefs: [],
      custom: {
        applyBtnFlag: false,
        applyBtnLabel: '',
        checkButtonLabel: 'Next',
        combineFeedback: false,
        customCssClass: '',
        facts: [],
        height: 540,
        lockCanvasSize: false,
        mainBtnLabel: '',
        maxAttempt: 3,
        maxScore: 4,
        negativeScoreAllowed: false,
        objectives: [],
        palette: {
          backgroundColor: 'rgba(255,255,255,0)',
          borderColor: 'rgba(255, 255, 255,100)',
          borderRadius: '10px',
          borderStyle: 'solid',
          borderWidth: '1px',
          useHtmlProps: true,
        },
        panelHeaderColor: 0,
        panelTitleColor: 0,
        showCheckBtn: true,
        trapStateScoreScheme: false,
        width: 1000,
        x: 0,
        y: 0,
        z: 0,
      },
      partsLayout: [
        {
          custom: {
            customCssClass: '',
            height: 77,
            maxScore: 1,
            nodes: [
              {
                children: [
                  {
                    children: [
                      {
                        children: [],
                        style: {},
                        tag: 'text',
                        text: 'How often should you pet your cat?',
                      },
                    ],
                    style: {},
                    tag: 'span',
                  },
                ],
                style: {},
                tag: 'h1',
              },
            ],
            overrideHeight: false,
            overrideWidth: true,
            palette: {
              backgroundColor: 'rgba(255,255,255,0)',
              borderColor: 'rgba(255,255,255,0)',
              borderRadius: 0,
              borderStyle: 'solid',
              borderWidth: '0.1px',
              fillAlpha: 0,
              fillColor: 16777215,
              lineAlpha: 0,
              lineColor: 16777215,
              lineStyle: 0,
              lineThickness: 0.1,
              useHtmlProps: true,
            },
            requiresManualGrading: false,
            visible: true,
            width: 513,
            x: 43,
            y: 36,
            z: 0,
          },
          id: '3126220925',
          type: 'janus-text-flow',
        },
        {
          custom: {
            commonErrorFeedback: ['', 'You Monster!'],
            correctAnswer: 0,
            correctFeedback: "Yup, you don't get a choice here.",
            customCssClass: '',
            enabled: true,
            fontSize: 12,
            height: 100,
            incorrectFeedback: '',
            label: 'Choose',
            maxScore: 1,
            optionLabels: [
              'As often as you want',
              "Never, they don't deserve it",
              'As often as the cat demands',
            ],
            prompt: '',
            requiresManualGrading: false,
            showLabel: true,
            width: 427,
            x: 253,
            y: 189,
            z: 0,
          },
          id: 'janus_dropdown-1305650307',
          type: 'janus-dropdown',
        },
      ],
    },
    authoring: {
      flowchart: {
        paths: [
          {
            completed: false,
            id: 'end-of-activity',
            label: 'Go To End Screen',
            priority: 16,
            ruleId: null,
            type: 'end-of-activity',
          },
        ],
        screenType: 'blank_screen',
        templateApplied: true,
      },
      parts: [
        {
          gradingApproach: 'automatic',
          id: 'janus_dropdown-1305650307',
          inherited: false,
          outOf: 1,
          owner: 'adaptive_activity_p63f3_3073022023',
          type: 'janus-dropdown',
        },
      ],
      rules: [
        {
          additionalScore: 0,
          conditions: {
            all: [
              {
                fact: 'stage.janus_dropdown-1305650307.selectedIndex',
                id: '2079075165',
                operator: 'equal',
                type: 1,
                value: '0',
              },
            ],
            id: 'b:71645194',
          },
          correct: true,
          default: true,
          disabled: false,
          event: {
            params: {
              actions: [
                {
                  params: {
                    target: 'adaptive_activity_9bcmt_1454817970',
                  },
                  type: 'navigation',
                },
                {
                  id: '3186178295',
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
                            height: 91,
                            maxScore: 1,
                            nodes: [
                              {
                                children: [
                                  {
                                    children: [
                                      {
                                        children: [],
                                        style: {},
                                        tag: 'text',
                                        text: "Yup, you don't get a choice here.",
                                      },
                                    ],
                                    style: {},
                                    tag: 'span',
                                  },
                                ],
                                style: {
                                  textAlign: 'center',
                                },
                                tag: 'p',
                              },
                            ],
                            overrideHeight: false,
                            overrideWidth: true,
                            palette: {
                              backgroundColor: 'rgba(255,255,255,0)',
                              borderColor: 'rgba(255,255,255,0)',
                              borderRadius: 0,
                              borderStyle: 'solid',
                              borderWidth: '0.1px',
                              useHtmlProps: true,
                            },
                            requiresManualGrading: false,
                            visible: true,
                            width: 340,
                            x: 4,
                            y: 5,
                            z: 0,
                          },
                          id: '',
                          type: 'janus-text-flow',
                        },
                      ],
                    },
                    id: '',
                  },
                  type: 'feedback',
                },
                {
                  params: {
                    operator: '=',
                    target: 'stage.janus_dropdown-1305650307.enabled',
                    targetType: 4,
                    value: 'false',
                  },
                  type: 'mutateState',
                },
              ],
            },
            type: 'r:3942952687.correct',
          },
          forceProgress: false,
          id: 'r:2508139770.correct',
          name: 'correct',
          priority: 10,
        },
        {
          additionalScore: 0,
          conditions: {
            all: [
              {
                fact: 'stage.janus_dropdown-1305650307.selectedItem',
                id: '3965368988',
                operator: 'equal',
                type: 2,
                value: '',
              },
            ],
            id: 'b:1226132798',
          },
          correct: false,
          default: false,
          disabled: false,
          event: {
            params: {
              actions: [
                {
                  id: '3046413984',
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
                            height: 91,
                            maxScore: 1,
                            nodes: [
                              {
                                children: [
                                  {
                                    children: [
                                      {
                                        children: [],
                                        style: {},
                                        tag: 'text',
                                        text: 'Please choose an answer.',
                                      },
                                    ],
                                    style: {},
                                    tag: 'span',
                                  },
                                ],
                                style: {
                                  textAlign: 'center',
                                },
                                tag: 'p',
                              },
                            ],
                            overrideHeight: false,
                            overrideWidth: true,
                            palette: {
                              backgroundColor: 'rgba(255,255,255,0)',
                              borderColor: 'rgba(255,255,255,0)',
                              borderRadius: 0,
                              borderStyle: 'solid',
                              borderWidth: '0.1px',
                              useHtmlProps: true,
                            },
                            requiresManualGrading: false,
                            visible: true,
                            width: 340,
                            x: 4,
                            y: 5,
                            z: 0,
                          },
                          id: '',
                          type: 'janus-text-flow',
                        },
                      ],
                    },
                    id: '',
                  },
                  type: 'feedback',
                },
                {
                  params: {
                    operator: 'setting to',
                    target: 'session.attemptNumber',
                    targetType: 1,
                    value: '1',
                  },
                  type: 'mutateState',
                },
              ],
            },
            type: 'r:97180799.blank',
          },
          forceProgress: false,
          id: 'r:1738486243.blank',
          name: 'blank',
          priority: 20,
        },
        {
          additionalScore: 0,
          conditions: {
            all: [
              {
                fact: 'session.attemptNumber',
                id: '4191090726',
                operator: 'greaterThan',
                type: 1,
                value: '2',
              },
              {
                fact: 'stage.janus_dropdown-1305650307.selectedIndex',
                id: '3969137579',
                operator: 'notEqual',
                type: 1,
                value: '0',
              },
            ],
            id: 'b:2721449432',
          },
          correct: false,
          default: false,
          disabled: false,
          event: {
            params: {
              actions: [
                {
                  params: {
                    target: 'adaptive_activity_9bcmt_1454817970',
                  },
                  type: 'navigation',
                },
                {
                  id: '349970127',
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
                            height: 91,
                            maxScore: 1,
                            nodes: [
                              {
                                children: [
                                  {
                                    children: [
                                      {
                                        children: [],
                                        style: {},
                                        tag: 'text',
                                        text: 'You seem to be having trouble. We have filled in the correct answer for you. Click next to continue.',
                                      },
                                    ],
                                    style: {},
                                    tag: 'span',
                                  },
                                ],
                                style: {
                                  textAlign: 'center',
                                },
                                tag: 'p',
                              },
                            ],
                            overrideHeight: false,
                            overrideWidth: true,
                            palette: {
                              backgroundColor: 'rgba(255,255,255,0)',
                              borderColor: 'rgba(255,255,255,0)',
                              borderRadius: 0,
                              borderStyle: 'solid',
                              borderWidth: '0.1px',
                              useHtmlProps: true,
                            },
                            requiresManualGrading: false,
                            visible: true,
                            width: 340,
                            x: 4,
                            y: 5,
                            z: 0,
                          },
                          id: '',
                          type: 'janus-text-flow',
                        },
                      ],
                    },
                    id: '',
                  },
                  type: 'feedback',
                },
                {
                  params: {
                    operator: '=',
                    target: 'stage.janus_dropdown-1305650307.selectedIndex',
                    targetType: 1,
                    value: '0',
                  },
                  type: 'mutateState',
                },
                {
                  params: {
                    operator: '=',
                    target: 'stage.janus_dropdown-1305650307.enabled',
                    targetType: 4,
                    value: 'false',
                  },
                  type: 'mutateState',
                },
              ],
            },
            type: 'r:1578527526.incorrect-3-times',
          },
          forceProgress: false,
          id: 'r:99270868.incorrect-3-times',
          name: 'incorrect-3-times',
          priority: 40,
        },
        {
          additionalScore: 0,
          conditions: {
            all: [
              {
                fact: 'stage.janus_dropdown-1305650307.selectedIndex',
                id: '1911728242',
                operator: 'equal',
                type: 1,
                value: '2',
              },
            ],
            id: 'b:1916736237',
          },
          correct: false,
          default: false,
          disabled: false,
          event: {
            params: {
              actions: [
                {
                  id: '3883434567',
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
                            height: 91,
                            maxScore: 1,
                            nodes: [
                              {
                                children: [
                                  {
                                    children: [
                                      {
                                        children: [],
                                        style: {},
                                        tag: 'text',
                                        text: 'You Monster!',
                                      },
                                    ],
                                    style: {},
                                    tag: 'span',
                                  },
                                ],
                                style: {
                                  textAlign: 'center',
                                },
                                tag: 'p',
                              },
                            ],
                            overrideHeight: false,
                            overrideWidth: true,
                            palette: {
                              backgroundColor: 'rgba(255,255,255,0)',
                              borderColor: 'rgba(255,255,255,0)',
                              borderRadius: 0,
                              borderStyle: 'solid',
                              borderWidth: '0.1px',
                              useHtmlProps: true,
                            },
                            requiresManualGrading: false,
                            visible: true,
                            width: 340,
                            x: 4,
                            y: 5,
                            z: 0,
                          },
                          id: '',
                          type: 'janus-text-flow',
                        },
                      ],
                    },
                    id: '',
                  },
                  type: 'feedback',
                },
              ],
            },
            type: 'r:1526652368.common-error-3',
          },
          forceProgress: false,
          id: 'r:1347681753.common-error-3',
          name: 'common-error-3',
          priority: 50,
        },
        {
          additionalScore: 0,
          conditions: {
            all: [],
            id: 'b:715729582',
          },
          correct: false,
          default: true,
          disabled: false,
          event: {
            params: {
              actions: [
                {
                  id: '1609038592',
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
                            height: 91,
                            maxScore: 1,
                            nodes: [
                              {
                                children: [
                                  {
                                    children: [
                                      {
                                        children: [],
                                        style: {},
                                        tag: 'text',
                                        text: "That's incorrect. Please try again.",
                                      },
                                    ],
                                    style: {},
                                    tag: 'span',
                                  },
                                ],
                                style: {
                                  textAlign: 'center',
                                },
                                tag: 'p',
                              },
                            ],
                            overrideHeight: false,
                            overrideWidth: true,
                            palette: {
                              backgroundColor: 'rgba(255,255,255,0)',
                              borderColor: 'rgba(255,255,255,0)',
                              borderRadius: 0,
                              borderStyle: 'solid',
                              borderWidth: '0.1px',
                              useHtmlProps: true,
                            },
                            requiresManualGrading: false,
                            visible: true,
                            width: 340,
                            x: 4,
                            y: 5,
                            z: 0,
                          },
                          id: '',
                          type: 'janus-text-flow',
                        },
                      ],
                    },
                    id: '',
                  },
                  type: 'feedback',
                },
              ],
            },
            type: 'r:3420262501.default-incorrect',
          },
          forceProgress: false,
          id: 'r:3705021521.default-incorrect',
          name: 'default-incorrect',
          priority: 70,
        },
      ],
      variablesRequiredForEvaluation: [
        'stage.janus_dropdown-1305650307.selectedItem',
        'session.attemptNumber',
        'stage.janus_dropdown-1305650307.selectedIndex',
        'stage.janus_dropdown-1305650307.enabled',
      ],
    },
    title: 'Petting Cats',
    objectives: {},
  },
  {
    id: 24779,
    resourceId: 24779,
    activitySlug: 'whats_your_favorite_cat',
    activityType: {
      authoring_element: 'oli-adaptive-authoring',
      authoring_script: 'oli_adaptive_authoring.js',
      delivery_element: 'oli-adaptive-delivery',
      delivery_script: 'oli_adaptive_delivery.js',
      enabled: true,
      global: true,
      id: 1,
      petite_label: 'Adaptive',
      slug: 'oli_adaptive',
      title: 'Adaptive Activity',
    },
    content: {
      bibrefs: [],
      custom: {
        applyBtnFlag: false,
        applyBtnLabel: '',
        checkButtonLabel: 'Next',
        combineFeedback: false,
        customCssClass: '',
        facts: [],
        height: 540,
        lockCanvasSize: false,
        mainBtnLabel: '',
        maxAttempt: 3,
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
        width: 1000,
        x: 0,
        y: 0,
        z: 0,
      },
      partsLayout: [
        {
          custom: {
            customCssClass: '',
            height: 76,
            maxScore: 1,
            nodes: [
              {
                children: [
                  {
                    children: [
                      {
                        children: [],
                        style: {},
                        tag: 'text',
                        text: 'What is your favorite kind of cat?',
                      },
                    ],
                    style: {},
                    tag: 'span',
                  },
                ],
                style: {},
                tag: 'h1',
              },
            ],
            overrideHeight: false,
            overrideWidth: true,
            palette: {
              backgroundColor: 'rgba(255,255,255,0)',
              borderColor: 'rgba(255,255,255,0)',
              borderRadius: 0,
              borderStyle: 'solid',
              borderWidth: '0.1px',
              fillAlpha: 0,
              fillColor: 16777215,
              lineAlpha: 0,
              lineColor: 16777215,
              lineStyle: 0,
              lineThickness: 0.1,
              useHtmlProps: true,
            },
            requiresManualGrading: false,
            visible: true,
            width: 919,
            x: 10,
            y: 10,
            z: 0,
          },
          id: '3915225150',
          type: 'janus-text-flow',
        },
        {
          custom: {
            commonErrorFeedback: ["Why don't you like Cute or Orange cats too?"],
            correctAnswer: [false, false, false, true],
            correctFeedback: 'Good Choice, all cats are great.',
            customCssClass: '',
            enabled: true,
            fontSize: 12,
            height: 151,
            incorrectFeedback:
              'This is not an opinion question, there is exactly one correct answer.',
            layoutType: 'verticalLayout',
            maxManualGrade: 0,
            maxScore: 1,
            mcqItems: [
              {
                nodes: [
                  {
                    children: [
                      {
                        children: [
                          {
                            children: [],
                            style: {},
                            tag: 'text',
                            text: 'Snuggly Cats',
                          },
                        ],
                        style: {},
                        tag: 'span',
                      },
                    ],
                    style: {},
                    tag: 'p',
                  },
                ],
                scoreValue: 0,
              },
              {
                nodes: [
                  {
                    children: [
                      {
                        children: [
                          {
                            children: [],
                            style: {},
                            tag: 'text',
                            text: 'Cute Cats',
                          },
                        ],
                        style: {},
                        tag: 'span',
                      },
                    ],
                    style: {},
                    tag: 'p',
                  },
                ],
                scoreValue: 1,
              },
              {
                nodes: [
                  {
                    children: [
                      {
                        children: [
                          {
                            children: [],
                            style: {},
                            tag: 'text',
                            text: 'Orange ',
                          },
                        ],
                        style: {
                          color: '#ff9900',
                        },
                        tag: 'span',
                      },
                      {
                        children: [
                          {
                            children: [],
                            style: {},
                            tag: 'text',
                            text: 'cats',
                          },
                        ],
                        style: {},
                        tag: 'span',
                      },
                    ],
                    style: {},
                    tag: 'p',
                  },
                ],
                scoreValue: 2,
              },
              {
                nodes: [
                  {
                    children: [
                      {
                        children: [
                          {
                            children: [],
                            style: {},
                            tag: 'text',
                            text: 'All of the above',
                          },
                        ],
                        style: {},
                        tag: 'span',
                      },
                    ],
                    style: {},
                    tag: 'p',
                  },
                ],
                scoreValue: 0,
              },
            ],
            multipleSelection: false,
            overrideHeight: false,
            randomize: false,
            requireManualGrading: false,
            requiresManualGrading: false,
            showLabel: true,
            showNumbering: false,
            showOnAnswersReport: false,
            verticalGap: 0,
            width: 247,
            x: 512,
            y: 201,
            z: 0,
          },
          id: '795269988',
          type: 'janus-mcq',
        },
        {
          custom: {
            alt: 'an image',
            customCssClass: '',
            height: 321,
            lockAspectRatio: true,
            maxScore: 1,
            requiresManualGrading: false,
            scaleContent: true,
            src: 'https://torus-media-dev.s3.amazonaws.com/media/E2/E2AFE2C76AD0482811F108DDC143C92F/cats.jfif',
            width: 462,
            x: 16,
            y: 196,
            z: 0,
          },
          id: '1865150112',
          type: 'janus-image',
        },
        {
          custom: {
            customCssClass: '',
            height: 54,
            nodes: [
              {
                children: [
                  {
                    children: [
                      {
                        children: [],
                        style: {},
                        tag: 'text',
                        text: 'There is specific feedback for Snuggly Cats, and an alternate path for Orange cats',
                      },
                    ],
                    style: {
                      fontStyle: 'italic',
                    },
                    tag: 'span',
                  },
                ],
                style: {},
                tag: 'p',
              },
            ],
            overrideHeight: false,
            overrideWidth: true,
            visible: true,
            width: 430,
            x: 515,
            y: 470,
            z: 0,
          },
          id: 'janus_text_flow-1207106857',
          type: 'janus-text-flow',
        },
      ],
    },
    authoring: {
      flowchart: {
        paths: [
          {
            completed: true,
            componentId: '795269988',
            destinationScreenId: 24780,
            id: 'mcq-common-error-2',
            label: 'Incorrect option: Orange cats',
            priority: 4,
            ruleId: null,
            selectedOption: 3,
            type: 'option-common-error',
          },
          {
            completed: true,
            componentId: '795269988',
            destinationScreenId: 24781,
            id: 'correct',
            label: 'Correct',
            priority: 8,
            ruleId: null,
            type: 'correct',
          },
          {
            completed: true,
            componentId: '795269988',
            destinationScreenId: 24781,
            id: 'incorrect',
            label: 'Any Incorrect',
            priority: 8,
            ruleId: null,
            type: 'incorrect',
          },
        ],
        screenType: 'multiple_choice',
        templateApplied: true,
      },
      parts: [
        {
          gradingApproach: 'automatic',
          id: '795269988',
          inherited: false,
          outOf: 1,
          owner: 'adaptive_activity_vc2i5_868716715',
          type: 'janus-mcq',
        },
      ],
      rules: [
        {
          additionalScore: 0,
          conditions: {
            all: [
              {
                fact: 'stage.795269988.selectedChoice',
                id: '3919480794',
                operator: 'equal',
                type: 1,
                value: '4',
              },
            ],
            id: 'b:2534492216',
          },
          correct: true,
          default: true,
          disabled: false,
          event: {
            params: {
              actions: [
                {
                  params: {
                    target: 'adaptive_activity_p63f3_3073022023',
                  },
                  type: 'navigation',
                },
                {
                  id: '2395296831',
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
                            height: 91,
                            maxScore: 1,
                            nodes: [
                              {
                                children: [
                                  {
                                    children: [
                                      {
                                        children: [],
                                        style: {},
                                        tag: 'text',
                                        text: 'Good Choice, all cats are great.',
                                      },
                                    ],
                                    style: {},
                                    tag: 'span',
                                  },
                                ],
                                style: {
                                  textAlign: 'center',
                                },
                                tag: 'p',
                              },
                            ],
                            overrideHeight: false,
                            overrideWidth: true,
                            palette: {
                              backgroundColor: 'rgba(255,255,255,0)',
                              borderColor: 'rgba(255,255,255,0)',
                              borderRadius: 0,
                              borderStyle: 'solid',
                              borderWidth: '0.1px',
                              useHtmlProps: true,
                            },
                            requiresManualGrading: false,
                            visible: true,
                            width: 340,
                            x: 4,
                            y: 5,
                            z: 0,
                          },
                          id: '',
                          type: 'janus-text-flow',
                        },
                      ],
                    },
                    id: '',
                  },
                  type: 'feedback',
                },
                {
                  params: {
                    operator: '=',
                    target: 'stage.795269988.enabled',
                    targetType: 4,
                    value: 'false',
                  },
                  type: 'mutateState',
                },
              ],
            },
            type: 'r:3905910760.correct',
          },
          forceProgress: false,
          id: 'r:799533587.correct',
          name: 'correct',
          priority: 10,
        },
        {
          additionalScore: 0,
          conditions: {
            all: [
              {
                fact: 'stage.795269988.selectedChoice',
                id: '2978125954',
                operator: 'equal',
                type: 1,
                value: '0',
              },
            ],
            id: 'b:1034879394',
          },
          correct: false,
          default: false,
          disabled: false,
          event: {
            params: {
              actions: [
                {
                  id: '2488362518',
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
                            height: 91,
                            maxScore: 1,
                            nodes: [
                              {
                                children: [
                                  {
                                    children: [
                                      {
                                        children: [],
                                        style: {},
                                        tag: 'text',
                                        text: 'Please choose an answer.',
                                      },
                                    ],
                                    style: {},
                                    tag: 'span',
                                  },
                                ],
                                style: {
                                  textAlign: 'center',
                                },
                                tag: 'p',
                              },
                            ],
                            overrideHeight: false,
                            overrideWidth: true,
                            palette: {
                              backgroundColor: 'rgba(255,255,255,0)',
                              borderColor: 'rgba(255,255,255,0)',
                              borderRadius: 0,
                              borderStyle: 'solid',
                              borderWidth: '0.1px',
                              useHtmlProps: true,
                            },
                            requiresManualGrading: false,
                            visible: true,
                            width: 340,
                            x: 4,
                            y: 5,
                            z: 0,
                          },
                          id: '',
                          type: 'janus-text-flow',
                        },
                      ],
                    },
                    id: '',
                  },
                  type: 'feedback',
                },
                {
                  params: {
                    operator: 'setting to',
                    target: 'session.attemptNumber',
                    targetType: 1,
                    value: '1',
                  },
                  type: 'mutateState',
                },
              ],
            },
            type: 'r:2422554989.blank',
          },
          forceProgress: false,
          id: 'r:455095155.blank',
          name: 'blank',
          priority: 20,
        },
        {
          additionalScore: 0,
          conditions: {
            all: [
              {
                fact: 'stage.795269988.selectedChoice',
                id: '1302783871',
                operator: 'equal',
                type: 1,
                value: '3',
              },
            ],
            id: 'b:2981896174',
          },
          correct: false,
          default: false,
          disabled: false,
          event: {
            params: {
              actions: [
                {
                  params: {
                    target: 'adaptive_activity_xtgzh_3892286377',
                  },
                  type: 'navigation',
                },
                {
                  id: '94678894',
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
                            height: 91,
                            maxScore: 1,
                            nodes: [
                              {
                                children: [
                                  {
                                    children: [
                                      {
                                        children: [],
                                        style: {},
                                        tag: 'text',
                                        text: "That's incorrect. Please try again.",
                                      },
                                    ],
                                    style: {},
                                    tag: 'span',
                                  },
                                ],
                                style: {
                                  textAlign: 'center',
                                },
                                tag: 'p',
                              },
                            ],
                            overrideHeight: false,
                            overrideWidth: true,
                            palette: {
                              backgroundColor: 'rgba(255,255,255,0)',
                              borderColor: 'rgba(255,255,255,0)',
                              borderRadius: 0,
                              borderStyle: 'solid',
                              borderWidth: '0.1px',
                              useHtmlProps: true,
                            },
                            requiresManualGrading: false,
                            visible: true,
                            width: 340,
                            x: 4,
                            y: 5,
                            z: 0,
                          },
                          id: '',
                          type: 'janus-text-flow',
                        },
                      ],
                    },
                    id: '',
                  },
                  type: 'feedback',
                },
                {
                  params: {
                    operator: '=',
                    target: 'stage.795269988.enabled',
                    targetType: 4,
                    value: 'false',
                  },
                  type: 'mutateState',
                },
              ],
            },
            type: 'r:463136168.common-error-2',
          },
          forceProgress: false,
          id: 'r:4036713845.common-error-2',
          name: 'common-error-2',
          priority: 30,
        },
        {
          additionalScore: 0,
          conditions: {
            all: [
              {
                fact: 'session.attemptNumber',
                id: '972452537',
                operator: 'greaterThan',
                type: 1,
                value: '2',
              },
              {
                fact: 'stage.795269988.selectedChoice',
                id: '483658695',
                operator: 'notEqual',
                type: 1,
                value: '4',
              },
            ],
            id: 'b:657765362',
          },
          correct: false,
          default: false,
          disabled: false,
          event: {
            params: {
              actions: [
                {
                  params: {
                    target: 'adaptive_activity_p63f3_3073022023',
                  },
                  type: 'navigation',
                },
                {
                  id: '2515496010',
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
                            height: 91,
                            maxScore: 1,
                            nodes: [
                              {
                                children: [
                                  {
                                    children: [
                                      {
                                        children: [],
                                        style: {},
                                        tag: 'text',
                                        text: 'You seem to be having trouble. We have filled in the correct answer for you. Click next to continue.',
                                      },
                                    ],
                                    style: {},
                                    tag: 'span',
                                  },
                                ],
                                style: {
                                  textAlign: 'center',
                                },
                                tag: 'p',
                              },
                            ],
                            overrideHeight: false,
                            overrideWidth: true,
                            palette: {
                              backgroundColor: 'rgba(255,255,255,0)',
                              borderColor: 'rgba(255,255,255,0)',
                              borderRadius: 0,
                              borderStyle: 'solid',
                              borderWidth: '0.1px',
                              useHtmlProps: true,
                            },
                            requiresManualGrading: false,
                            visible: true,
                            width: 340,
                            x: 4,
                            y: 5,
                            z: 0,
                          },
                          id: '',
                          type: 'janus-text-flow',
                        },
                      ],
                    },
                    id: '',
                  },
                  type: 'feedback',
                },
                {
                  params: {
                    operator: '=',
                    target: 'stage.795269988.selectedChoice',
                    targetType: 1,
                    value: '4',
                  },
                  type: 'mutateState',
                },
                {
                  params: {
                    operator: '=',
                    target: 'stage.795269988.enabled',
                    targetType: 4,
                    value: 'false',
                  },
                  type: 'mutateState',
                },
              ],
            },
            type: 'r:2732668911.incorrect-3-times',
          },
          forceProgress: false,
          id: 'r:3125482193.incorrect-3-times',
          name: 'incorrect-3-times',
          priority: 40,
        },
        {
          additionalScore: 0,
          conditions: {
            all: [
              {
                fact: 'stage.795269988.selectedChoice',
                id: '1881437284',
                operator: 'equal',
                type: 1,
                value: '1',
              },
            ],
            id: 'b:350025798',
          },
          correct: false,
          default: false,
          disabled: false,
          event: {
            params: {
              actions: [
                {
                  id: '175738995',
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
                            height: 91,
                            maxScore: 1,
                            nodes: [
                              {
                                children: [
                                  {
                                    children: [
                                      {
                                        children: [],
                                        style: {},
                                        tag: 'text',
                                        text: "Why don't you like Cute or Orange cats too?",
                                      },
                                    ],
                                    style: {},
                                    tag: 'span',
                                  },
                                ],
                                style: {
                                  textAlign: 'center',
                                },
                                tag: 'p',
                              },
                            ],
                            overrideHeight: false,
                            overrideWidth: true,
                            palette: {
                              backgroundColor: 'rgba(255,255,255,0)',
                              borderColor: 'rgba(255,255,255,0)',
                              borderRadius: 0,
                              borderStyle: 'solid',
                              borderWidth: '0.1px',
                              useHtmlProps: true,
                            },
                            requiresManualGrading: false,
                            visible: true,
                            width: 340,
                            x: 4,
                            y: 5,
                            z: 0,
                          },
                          id: '',
                          type: 'janus-text-flow',
                        },
                      ],
                    },
                    id: '',
                  },
                  type: 'feedback',
                },
              ],
            },
            type: 'r:1490028475.common-error-4',
          },
          forceProgress: false,
          id: 'r:501326832.common-error-4',
          name: 'common-error-4',
          priority: 50,
        },
        {
          additionalScore: 0,
          conditions: {
            all: [],
            id: 'b:2411054290',
          },
          correct: false,
          default: true,
          disabled: false,
          event: {
            params: {
              actions: [
                {
                  id: '3413938881',
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
                            height: 91,
                            maxScore: 1,
                            nodes: [
                              {
                                children: [
                                  {
                                    children: [
                                      {
                                        children: [],
                                        style: {},
                                        tag: 'text',
                                        text: 'This is not an opinion question, there is exactly one correct answer.',
                                      },
                                    ],
                                    style: {},
                                    tag: 'span',
                                  },
                                ],
                                style: {
                                  textAlign: 'center',
                                },
                                tag: 'p',
                              },
                            ],
                            overrideHeight: false,
                            overrideWidth: true,
                            palette: {
                              backgroundColor: 'rgba(255,255,255,0)',
                              borderColor: 'rgba(255,255,255,0)',
                              borderRadius: 0,
                              borderStyle: 'solid',
                              borderWidth: '0.1px',
                              useHtmlProps: true,
                            },
                            requiresManualGrading: false,
                            visible: true,
                            width: 340,
                            x: 4,
                            y: 5,
                            z: 0,
                          },
                          id: '',
                          type: 'janus-text-flow',
                        },
                      ],
                    },
                    id: '',
                  },
                  type: 'feedback',
                },
              ],
            },
            type: 'r:3279805980.default-incorrect',
          },
          forceProgress: false,
          id: 'r:2777316984.default-incorrect',
          name: 'default-incorrect',
          priority: 70,
        },
      ],
      variablesRequiredForEvaluation: [
        'stage.795269988.selectedChoice',
        'stage.795269988.enabled',
        'session.attemptNumber',
      ],
    },
    title: "What's your favorite cat?",
    objectives: {},
  },
];
