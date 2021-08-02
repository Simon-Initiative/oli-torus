export const schema = {

  customCssClass: {
    type: 'string'
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
    default: 12
},
maxManualGrade: {
    type: 'number'
},
showOnAnswersReport: {
    type: 'boolean',
    format: 'checkbox',
    default: false
},
requireManualGrading: {
    type: 'boolean',
    format: 'checkbox',
    default: false
},
description: {
    type: 'string',
    default: 'Additional Information',
    description: 'provides alt text and aria-label content'
},
questionFlow: {
    type: 'string',
    description: 'specifies the layout of the questions',
    default: 'LRTB'
},
showLabel: {
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether label is visible',
    default: true
},
openByDefault: {
    type: 'boolean',
    description: 'specifies whether popup should open by default',
    default: false,
    isVisibleInTrapState: true,
    format: 'checkbox'
},
defaultID: {
    type: 'string',
    options: {
        hidden: true
    }
},
defaultURL: {
    type: 'string',
    description: 'default URL for the button icon',
    default: '/repo/icons/question_mark_orange_32x32.png',
    enum: [
        '/repo/icons/question_mark_orange_32x32.png',
       '/repo/icons/question_mark_red_32x32.png',
       '/repo/icons/question_mark_green_32x32.png',
       '/repo/icons/question_mark_blue_32x32.png',
       '/repo/icons/information_mark_orange_32x32.png',
       '/repo/icons/information_mark_red_32x32.png',
       '/repo/icons/information_mark_green_32x32.png',
       '/repo/icons/information_mark_blue_32x32.png',
       '/repo/icons/exclamation_mark_orange_32x32.png',
       '/repo/icons/exclamation_mark_red_32x32.png',
       '/repo/icons/exclamation_mark_green_32x32.png',
       '/repo/icons/exclamation_mark_blue_32x32.png'
    ]
},
iconURL: {
    type: 'string',
    description: 'Custom URL for the button icon'
},
useToggleBehavior: {
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether popup toggles open/closed on click or on mouse hover',
    default: true
},
isOpen: {
    type: 'boolean',
    description: 'specifies whether popup is opened',
    default: false,
    isVisibleInTrapState: true,
    format: 'checkbox'
},
visible: {
    type: 'boolean',
    description: 'specifies whether popup will be visible on the screen',
    default: true,
    isVisibleInTrapState: true,
    format: 'checkbox'
}
};

export const uiSchema = {};