import { clone } from '../../../../../utils/common';
import guid from '../../../../../utils/guid';
import { IAction } from '../../../../delivery/store/features/activities/slice';

const template: IAction = {
  type: 'feedback',
  params: {
    id: '',
    feedback: {
      custom: {
        facts: [],
        rules: [],
        width: 350,
        height: 100,
        palette: {
          fillAlpha: 0,
          fillColor: 16777215,
          lineAlpha: 0,
          lineColor: 16777215,
          lineStyle: 0,
          lineThickness: 0.1,
        },
        applyBtnFlag: false,
        mainBtnLabel: 'Next',
        applyBtnLabel: 'Show Solution',
        lockCanvasSize: true,
        panelTitleColor: 16777215,
        panelHeaderColor: 10027008,
      },
      partsLayout: [
        {
          id: '',
          type: 'janus-text-flow',
          custom: {
            x: 4,
            y: 5,
            z: 0,
            nodes: [
              {
                tag: 'p',
                style: {
                  textAlign: 'center',
                },
                children: [
                  {
                    tag: 'span',
                    style: {},
                    children: [
                      {
                        tag: 'text',
                        text: 'Feedback goes here.',
                        style: {},
                        children: [],
                      },
                    ],
                  },
                ],
              },
            ],
            width: 340,
            height: 91,
            palette: {
              borderColor: 'rgba(255,255,255,0)',
              borderStyle: 'solid',
              borderWidth: '0.1px',
              borderRadius: 0,
              useHtmlProps: true,
              backgroundColor: 'rgba(255,255,255,0)',
            },
            visible: true,
            maxScore: 1,
            overrideWidth: true,
            customCssClass: '',
            overrideHeight: false,
            requiresManualGrading: false,
          },
        },
      ],
    },
  },
};

export const createFeedbackAction = (message: string): IAction => {
  const feedback = clone(template);
  feedback.id = guid();
  feedback.params.feedback.partsLayout.id = guid();
  feedback.params.feedback.partsLayout[0].custom.nodes[0].children[0].children[0].text = message;
  return feedback;
};
