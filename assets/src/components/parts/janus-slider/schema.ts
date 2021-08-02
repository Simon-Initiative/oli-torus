export const schema = {
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
customCssClass: {
    type: 'string'
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
showLabel: {
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether label is visible',
    default: true
},
label: {
    type: 'string',
    description: 'text label for the slider'
},
value: {
    type: 'number',
    description: 'specifies the current value of slider',
    isVisibleInTrapState: true,
    default: 0
},
showDataTip: {
    type: 'boolean',
    format: 'checkbox'
},
showValueLabels: {
    type: 'boolean',
    format: 'checkbox'
},
showTicks: {
    type: 'boolean',
    format: 'checkbox'
},
showThumbByDefault: {
    type: 'boolean',
    format: 'checkbox'
},
invertScale: {
    type: 'boolean',
    format: 'checkbox'
},
minimum: {
    type: 'number'
},
maximum: {
    type: 'number'
},
snapInterval: {
    type: 'number'
},
enabled: {
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether slider is enabled',
    isVisibleInTrapState: true,
    default: true
},
userModified: {
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether user has interacted with slider',
    isVisibleInTrapState: true,
    default: false
}
};

export const uiSchema = {};