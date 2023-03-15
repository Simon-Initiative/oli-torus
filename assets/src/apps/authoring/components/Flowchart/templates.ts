import { Template } from './template-types';

export const templates: Template[] = [
  {
    name: 'Blank Screen',
    templateType: 'blank_screen',
    parts: [
      {
        id: '__default',
        inherited: false,
        owner: 'adaptive_activity_xo0bs_705283276',
        type: 'janus-text-flow',
      },
    ],
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
                      text: 'Unfinished Template',
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
          width: 322,
          x: 223,
          y: 227,
          z: 0,
        },
        id: 'janus-text-flow-261169992',
        type: 'janus-text-flow',
      },
    ],
  },
  {
    name: 'Template #1 - mc',
    templateType: 'multiple_choice',
    parts: [
      {
        id: 'janus_mcq-1507028084',
        inherited: false,
        owner: 'adaptive_activity_gu1ba_1084752856',
        type: 'janus-mcq',
      },
    ],
    partsLayout: [
      {
        custom: {
          customCssClass: '',
          height: 79,
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
                      text: 'Question #1',
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
          width: 429,
          x: 20,
          y: 18,
          z: 0,
        },
        id: 'text_211136769',
        type: 'janus-text-flow',
      },
      {
        custom: {
          customCssClass: '',
          enabled: true,
          height: 147,
          layoutType: 'verticalLayout',
          maxManualGrade: 0,
          mcqItems: [
            {
              nodes: [
                {
                  children: [
                    {
                      children: [
                        {
                          children: [],
                          tag: 'text',
                          text: 'Option 1',
                        },
                      ],
                      style: {},
                      tag: 'span',
                    },
                  ],
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
                          tag: 'text',
                          text: 'Option 2',
                        },
                      ],
                      style: {},
                      tag: 'span',
                    },
                  ],
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
                          tag: 'text',
                          text: 'Option 3',
                        },
                      ],
                      style: {},
                      tag: 'span',
                    },
                  ],
                  tag: 'p',
                },
              ],
              scoreValue: 2,
            },
          ],
          multipleSelection: false,
          overrideHeight: false,
          randomize: false,
          requireManualGrading: false,
          showLabel: true,
          showNumbering: false,
          showOnAnswersReport: false,
          verticalGap: 0,
          width: 349,
          x: 213,
          y: 225,
          z: 0,
        },
        id: 'janus_mcq-1507028084',
        type: 'janus-mcq',
      },
    ],
  },
  {
    name: 'Template #2 - mc',
    templateType: 'multiple_choice',
    parts: [
      {
        id: 'janus_mcq-2084727462',
        inherited: false,
        owner: 'adaptive_activity_txe2h_2117745269',
        type: 'janus-mcq',
      },
    ],
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
                      text: 'Question #1',
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
          width: 330,
          x: 10,
          y: 10,
          z: 0,
        },
        id: 'text_4027960624',
        type: 'janus-text-flow',
      },
      {
        custom: {
          customCssClass: '',
          enabled: true,
          height: 151,
          layoutType: 'verticalLayout',
          maxManualGrade: 0,
          mcqItems: [
            {
              nodes: [
                {
                  children: [
                    {
                      children: [
                        {
                          children: [],
                          tag: 'text',
                          text: 'Option 1',
                        },
                      ],
                      style: {},
                      tag: 'span',
                    },
                  ],
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
                          tag: 'text',
                          text: 'Option 2',
                        },
                      ],
                      style: {},
                      tag: 'span',
                    },
                  ],
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
                          tag: 'text',
                          text: 'Option 3',
                        },
                      ],
                      style: {},
                      tag: 'span',
                    },
                  ],
                  tag: 'p',
                },
              ],
              scoreValue: 2,
            },
          ],
          multipleSelection: false,
          overrideHeight: false,
          randomize: false,
          requireManualGrading: false,
          showLabel: true,
          showNumbering: false,
          showOnAnswersReport: false,
          verticalGap: 0,
          width: 247,
          x: 514,
          y: 107,
          z: 0,
        },
        id: 'janus_mcq-2084727462',
        type: 'janus-mcq',
      },
      {
        custom: {
          alt: 'an image',
          customCssClass: '',
          height: 439,
          lockAspectRatio: true,
          scaleContent: true,
          src: '/images/placeholder-image.svg',
          width: 462,
          x: 24,
          y: 100,
          z: 0,
        },
        id: 'janus_image-771750472',
        type: 'janus-image',
      },
    ],
  },
  {
    name: 'Template #3 - mlt',
    templateType: 'multiline_text',
    parts: [
      {
        id: 'janus_multi_line_text-4264269546',
        inherited: false,
        owner: 'adaptive_activity_rhvpa_355961482',
        type: 'janus-multi-line-text',
      },
    ],
    partsLayout: [
      {
        custom: {
          customCssClass: '',
          enabled: true,
          height: 157,
          label: '',
          prompt: '',
          showCharacterCount: true,
          showLabel: true,
          width: 744,
          x: 24,
          y: 390,
          z: 0,
        },
        id: 'janus_multi_line_text-4264269546',
        type: 'janus-multi-line-text',
      },
      {
        custom: {
          customCssClass: '',
          height: 79,
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
                      text: 'Question #1',
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
          width: 429,
          x: 20,
          y: 18,
          z: 0,
        },
        id: 'janus-text-flow-4109373493',
        type: 'janus-text-flow',
      },
      {
        custom: {
          customCssClass: '',
          height: 79,
          nodes: [
            {
              children: [
                {
                  children: [
                    {
                      children: [],
                      style: {},
                      tag: 'text',
                      text: 'Take a few moments, think about this thing, and then write what you think below.',
                    },
                  ],
                  style: {},
                  tag: 'span',
                },
              ],
              style: {},
              tag: 'h3',
            },
          ],
          overrideHeight: false,
          overrideWidth: true,
          visible: true,
          width: 616,
          x: 31,
          y: 265,
          z: 0,
        },
        id: 'janus_text_flow-3586568172',
        type: 'janus-text-flow',
      },
    ],
  },
  {
    name: 'Template #4 - mlt',
    templateType: 'multiline_text',
    parts: [
      {
        id: 'janus_multi_line_text-2580689779',
        inherited: false,
        owner: 'adaptive_activity_srufo_2784045236',
        type: 'janus-multi-line-text',
      },
    ],
    partsLayout: [
      {
        custom: {
          customCssClass: '',
          height: 79,
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
                      text: 'Question #1',
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
          width: 429,
          x: 20,
          y: 18,
          z: 0,
        },
        id: 'janus-text-flow-2642425973',
        type: 'janus-text-flow',
      },
      {
        custom: {
          customCssClass: '',
          enabled: true,
          height: 310,
          label: '',
          prompt: '',
          showCharacterCount: true,
          showLabel: true,
          width: 292,
          x: 32,
          y: 213,
          z: 0,
        },
        id: 'janus_multi_line_text-2580689779',
        type: 'janus-multi-line-text',
      },
      {
        custom: {
          alt: 'an image',
          customCssClass: '',
          height: 427,
          lockAspectRatio: true,
          scaleContent: true,
          src: '/images/placeholder-image.svg',
          width: 387,
          x: 388,
          y: 112,
          z: 0,
        },
        id: 'janus_image-2566111630',
        type: 'janus-image',
      },
      {
        custom: {
          customCssClass: '',
          height: 100,
          nodes: [
            {
              children: [
                {
                  children: [
                    {
                      children: [],
                      style: {},
                      tag: 'text',
                      text: "Look at the picture on the right and then type the answer to this question I'm asking you.",
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
          visible: true,
          width: 277,
          x: 43,
          y: 117,
          z: 0,
        },
        id: 'janus_text_flow-3859677576',
        type: 'janus-text-flow',
      },
    ],
  },
  {
    name: 'Welcome Screen #1',
    templateType: 'welcome_screen',
    parts: [
      {
        id: '__default',
        inherited: false,
        owner: 'adaptive_activity_mezaj_3768983041',
        type: 'janus-text-flow',
      },
    ],
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
                      text: 'Unfinished Template',
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
          width: 322,
          x: 223,
          y: 227,
          z: 0,
        },
        id: 'text_3455774304',
        type: 'janus-text-flow',
      },
    ],
  },
  {
    name: 'Slider #1',
    templateType: 'slider',
    parts: [
      {
        id: 'janus_slider-3523231781',
        inherited: false,
        owner: 'adaptive_activity_79chz_108985206',
        type: 'janus-slider',
      },
    ],
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
                      text: 'Unfinished Template',
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
          width: 322,
          x: 223,
          y: 227,
          z: 0,
        },
        id: 'text_3455774304',
        type: 'janus-text-flow',
      },
      {
        custom: {
          customCssClass: '',
          enabled: true,
          height: 100,
          invertScale: false,
          label: 'Slider',
          maximum: 100,
          minimum: 0,
          showDataTip: true,
          showLabel: true,
          showThumbByDefault: true,
          showTicks: true,
          showValueLabels: true,
          snapInterval: 1,
          width: 500,
          x: 144,
          y: 403,
          z: 0,
        },
        id: 'janus_slider-3523231781',
        type: 'janus-slider',
      },
    ],
  },
  {
    name: 'Hub and Spoke #1',
    templateType: 'hub_and',
    parts: [
      {
        id: '__default',
        inherited: false,
        owner: 'adaptive_activity_4kno9_1270100722',
        type: 'janus-text-flow',
      },
    ],
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
                      text: 'Unfinished Template',
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
          width: 322,
          x: 223,
          y: 227,
          z: 0,
        },
        id: 'janus-text-flow-1214868877',
        type: 'janus-text-flow',
      },
    ],
  },
  {
    name: 'End Screen #1',
    templateType: 'end_screen',
    parts: [
      {
        id: '__default',
        inherited: false,
        owner: 'adaptive_activity_1rzv6_3103093756',
        type: 'janus-text-flow',
      },
    ],
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
                      text: 'Unfinished Template',
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
          width: 322,
          x: 223,
          y: 227,
          z: 0,
        },
        id: 'janus-text-flow-4005843402',
        type: 'janus-text-flow',
      },
    ],
  },
  {
    name: 'Number Input #1',
    templateType: 'number_input',
    parts: [
      {
        id: 'janus_input_number-3365897146',
        inherited: false,
        owner: 'adaptive_activity_tv0hu_4259315798',
        type: 'janus-input-number',
      },
    ],
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
                      text: 'Unfinished Template',
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
          width: 322,
          x: 223,
          y: 227,
          z: 0,
        },
        id: 'janus-text-flow-2518792564',
        type: 'janus-text-flow',
      },
      {
        custom: {
          enabled: true,
          height: 100,
          label: 'How many?',
          maxManualGrade: 0,
          prompt: 'enter a number...',
          requireManualGrading: false,
          showIncrementArrows: false,
          showLabel: true,
          unitsLabel: 'units',
          width: 365,
          x: 236,
          y: 375,
          z: 0,
        },
        id: 'janus_input_number-3365897146',
        type: 'janus-input-number',
      },
    ],
  },
  {
    name: 'Text Input #1',
    templateType: 'text_input',
    parts: [
      {
        id: 'janus_input_text-2644161056',
        inherited: false,
        owner: 'adaptive_activity_kgzre_721721198',
        type: 'janus-input-text',
      },
    ],
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
                      text: 'Unfinished Template',
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
          width: 322,
          x: 223,
          y: 227,
          z: 0,
        },
        id: 'janus-text-flow-149881737',
        type: 'janus-text-flow',
      },
      {
        custom: {
          customCssClass: '',
          enabled: true,
          height: 100,
          label: 'Input',
          maxManualGrade: 0,
          prompt: 'enter some text',
          requireManualGrading: false,
          showLabel: true,
          showOnAnswersReport: false,
          width: 374,
          x: 207,
          y: 363,
          z: 0,
        },
        id: 'janus_input_text-2644161056',
        type: 'janus-input-text',
      },
    ],
  },
  {
    name: 'Template #5 - info',
    templateType: 'none',
    parts: [
      {
        id: '__default',
        inherited: false,
        owner: 'adaptive_activity_ez4ie_1509470502',
        type: 'janus-text-flow',
      },
    ],
    partsLayout: [
      {
        custom: {
          customCssClass: '',
          height: 79,
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
                      text: 'Info!',
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
          width: 429,
          x: 13,
          y: 15,
          z: 0,
        },
        id: 'janus-text-flow-270171210',
        type: 'janus-text-flow',
      },
      {
        custom: {
          customCssClass: '',
          height: 240,
          nodes: [
            {
              children: [
                {
                  children: [
                    {
                      children: [],
                      style: {},
                      tag: 'text',
                      text: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.',
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
          visible: true,
          width: 631,
          x: 74,
          y: 176,
          z: 0,
        },
        id: 'janus_text_flow-430687845',
        type: 'janus-text-flow',
      },
    ],
  },
  {
    name: 'Template #6 - info-pic',
    templateType: 'none',
    parts: [
      {
        id: '__default',
        inherited: false,
        owner: 'adaptive_activity_xh0vc_4202475077',
        type: 'janus-text-flow',
      },
    ],
    partsLayout: [
      {
        custom: {
          customCssClass: '',
          height: 79,
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
                      text: 'Info!',
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
          width: 429,
          x: 13,
          y: 15,
          z: 0,
        },
        id: 'janus-text-flow-2597146524',
        type: 'janus-text-flow',
      },
      {
        custom: {
          alt: 'an image',
          customCssClass: '',
          height: 427,
          lockAspectRatio: true,
          scaleContent: true,
          src: '/images/placeholder-image.svg',
          width: 492,
          x: 133,
          y: 105,
          z: 0,
        },
        id: 'janus_image-3637340744',
        type: 'janus-image',
      },
      {
        custom: {
          customCssClass: '',
          height: 27,
          nodes: [
            {
              children: [
                {
                  children: [
                    {
                      children: [],
                      style: {},
                      tag: 'text',
                      text: 'A caption for the image goes here.',
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
          visible: true,
          width: 664,
          x: 66,
          y: 546,
          z: 0,
        },
        id: 'janus_text_flow-2916346875',
        type: 'janus-text-flow',
      },
    ],
  },
  {
    name: 'Dropdown - big',
    templateType: 'dropdown',
    parts: [
      {
        gradingApproach: 'automatic',
        id: 'janus_dropdown-3278370476',
        inherited: false,
        outOf: 1,
        owner: 'adaptive_activity_c7gzm_3102712287',
        type: 'janus-dropdown',
      },
      {
        id: 'janus_dropdown-3284024410',
        type: 'janus-dropdown',
        owner: 'adaptive_activity_c7gzm_3102712287',
        inherited: false,
        gradingApproach: 'automatic',
        outOf: 1,
      },
    ],
    partsLayout: [
      {
        custom: {
          customCssClass: '',
          height: 79,
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
                      text: 'Question #1',
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
          width: 429,
          x: 20,
          y: 18,
          z: 0,
        },
        id: 'janus-text-flow-3670528086',
        type: 'janus-text-flow',
      },
      {
        custom: {
          customCssClass: '',
          height: 45,
          nodes: [
            {
              children: [
                {
                  children: [
                    {
                      children: [],
                      style: {},
                      tag: 'text',
                      text: 'What is the wingspeed velocity of an unladen swallow?',
                    },
                  ],
                  style: {},
                  tag: 'span',
                },
              ],
              style: {},
              tag: 'h3',
            },
          ],
          overrideHeight: false,
          overrideWidth: true,
          visible: true,
          width: 433,
          x: 163,
          y: 200,
          z: 0,
        },
        id: 'janus_text_flow-3123089286',
        type: 'janus-text-flow',
      },
      {
        id: 'janus_dropdown-3284024410',
        type: 'janus-dropdown',
        custom: {
          x: 169,
          y: 255,
          z: 0,
          width: 415,
          height: 100,
          customCssClass: '',
          showLabel: true,
          label: ' ',
          prompt: '',
          optionLabels: ['Option 1', 'Option 2'],
          enabled: true,
          correctAnswer: 0,
          fontSize: 12,
          requiresManualGrading: false,
          maxScore: 1,
        },
      },
    ],
  },
  {
    name: 'Dropdown - Image',
    templateType: 'dropdown',
    parts: [
      {
        gradingApproach: 'automatic',
        id: 'janus_dropdown-3278370476',
        inherited: false,
        outOf: 1,
        owner: 'adaptive_activity_ryrgz_1391702840',
        type: 'janus-dropdown',
      },
      {
        id: 'janus_dropdown-4031880054',
        type: 'janus-dropdown',
        owner: 'adaptive_activity_ryrgz_1391702840',
        inherited: false,
        gradingApproach: 'automatic',
        outOf: 1,
      },
    ],
    partsLayout: [
      {
        custom: {
          customCssClass: '',
          height: 79,
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
                      text: 'Question #1',
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
          width: 429,
          x: 20,
          y: 18,
          z: 0,
        },
        id: 'janus-text-flow-3670528086',
        type: 'janus-text-flow',
      },
      {
        custom: {
          customCssClass: '',
          height: 45,
          nodes: [
            {
              children: [
                {
                  children: [
                    {
                      children: [],
                      style: {},
                      tag: 'text',
                      text: 'What is the wingspeed velocity of an unladen swallow?',
                    },
                  ],
                  style: {},
                  tag: 'span',
                },
              ],
              style: {},
              tag: 'h3',
            },
          ],
          overrideHeight: false,
          overrideWidth: true,
          visible: true,
          width: 433,
          x: 28,
          y: 445,
          z: 0,
        },
        id: 'janus_text_flow-3123089286',
        type: 'janus-text-flow',
      },
      {
        custom: {
          alt: 'an image',
          customCssClass: '',
          height: 341,
          lockAspectRatio: true,
          scaleContent: true,
          src: '/images/placeholder-image.svg',
          width: 527,
          x: 118,
          y: 99,
          z: 0,
        },
        id: 'janus_image-3030745620',
        type: 'janus-image',
      },
      {
        id: 'janus_dropdown-4031880054',
        type: 'janus-dropdown',
        custom: {
          x: 35,
          y: 511,
          z: 0,
          width: 417,
          height: 45,
          customCssClass: '',
          showLabel: true,
          label: ' ',
          prompt: '',
          optionLabels: ['Option 1', 'Option 2'],
          enabled: true,
          correctAnswer: 0,
          fontSize: 12,
          requiresManualGrading: false,
          maxScore: 1,
        },
      },
    ],
  },
];
