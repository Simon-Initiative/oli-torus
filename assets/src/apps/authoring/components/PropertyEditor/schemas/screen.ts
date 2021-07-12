import CustomFieldTemplate from '../custom/CustomFieldTemplate';

const screenSchema = {
  type: 'object',
  properties: {
    Size: {
      type: 'object',
      title: 'Dimensions',
      properties: {
        width: { type: 'number' },
        height: { type: 'number' },
      },
    },
    palette: {
      type: 'object',
      properties: {
        backgroundColor: { type: 'string' },
        borderColor: { type: 'string' },
        borderRadius: { type: 'string' },
        borderStyle: { type: 'string' },
        borderWidth: { type: 'string' },
      },
    },
    customCssClass: {
      title: 'Custom CSS Class',
      type: 'string',
    },
    combineFeedback: {
      title: 'Combine Feedback',
      type: 'boolean',
      format: 'checkbox',
      default: true,
    },
    checkButton: {
      type: 'object',
      properties: {
        showCheckBtn: {
          title: 'Show Check Button',
          type: 'boolean',
          format: 'checkbox',
        },
        checkButtonLabel: {
          title: 'Check Button Label',
          type: 'string',
        },
      },
    },
    max: {
      type: 'object',
      properties: {
        maxAttempt: {
          title: 'Max Attempts',
          type: 'number',
        },
        maxScore: {
          title: 'Max Score',
          type: 'number',
        },
      },
    },
    trapStateScoring: {
      title: 'Trap State Scoring',
      type: 'boolean',
      format: 'checkbox',
      default: true,
    },
    negativeScoreAllowed: {
      title: 'Allow Negative Question Score',
      type: 'boolean',
      format: 'checkbox',
      default: true,
    },
    screenButton: {
      title: 'Screen Button',
      type: 'boolean',
      format: 'checkbox',
      default: true,
    },
  },
};

export const screenUiSchema = {
  Size: {
    'ui:ObjectFieldTemplate': CustomFieldTemplate,
    'ui:title': 'Dimensions',
    width: {
      classNames: 'col-6',
    },
    height: {
      classNames: 'col-6',
    },
  },
  max: {
    'ui:ObjectFieldTemplate': CustomFieldTemplate,
    maxAttempt: {
      classNames: 'col-6',
    },
    maxScore: {
      classNames: 'col-6',
    },
  },
  palette: {
    'ui:ObjectFieldTemplate': CustomFieldTemplate,
    'ui:title': 'Palette',
    borderStyle: { classNames: 'col-6' },
    borderWidth: { classNames: 'col-6' },
  },
  checkButton: {
    'ui:ObjectFieldTemplate': CustomFieldTemplate,
    showCheckBtn: {
      classNames: 'col-12',
    },
    checkButtonLabel: {
      classNames: 'col-12',
    },
  },
};

export const getScreenData = (data: any) => {
  if (data) {
    return {
      ...data,
      useHtmlProps: data.palette.useHtmlProps,
      Size: { width: data.width, height: data.height },
      checkButton: { showCheckBtn: data.showCheckBtn, checkButtonLabel: data.checkButtonLabel },
      max: { maxAttempt: data.maxAttempt, maxScore: data.maxScore },
    };
  }
};

export default screenSchema;
