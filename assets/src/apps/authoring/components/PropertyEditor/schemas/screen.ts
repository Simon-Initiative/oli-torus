import { JSONSchema7 } from 'json-schema';
import customFieldTemplate from '../custom/CustomFieldTemplate';
const screenSchema: JSONSchema7 = {
  type: 'object',
  properties: {
    Size: {
      type: "object",
      title: "Dimensions",
      properties: {
        width: { type: 'number' },
        height: { type: 'number' }
      }
    },
    Position: {
      type: "object",
      title: "Position",
      properties: {
        x: { type: 'number' },
        y: { type: 'number' },
        z: { type: 'number' }
      }
    },
    palette: {
      type: 'object',
      properties: {
        useHtmlProps: {
          type: 'boolean',
          format: 'checkbox',
          title: 'Use HTML Properties'
        },
      }
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
      }
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
        }
      }
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
    'ui:ObjectFieldTemplate': customFieldTemplate,
    'ui:title': 'Dimensions',
    width: {
      classNames: 'col-6'
    },
    height: {
      classNames: 'col-6'
    }
  },
  Position: {
    'ui:ObjectFieldTemplate': customFieldTemplate,
    'ui:title': 'Position',
    x: {
      classNames: 'col-4 pr-1'
    },
    y: {
      classNames: 'col-4 px-2'
    },
    z: {
      classNames: 'col-4 pl-1'
    }
  },
  max: {
    'ui:ObjectFieldTemplate': customFieldTemplate,
    maxAttempt: {
      classNames: 'col-6'
    },
    maxScore: {
      classNames: 'col-6'
    }
  },
  checkButton: {
    'ui:ObjectFieldTemplate': customFieldTemplate,
    showCheckBtn: {
      classNames: 'col-12'
    },
    checkButtonLabel: {
      classNames: 'col-12'
    }
  },
  palette: {
    'ui:ObjectFieldTemplate': customFieldTemplate,
    'ui:title': 'Palette',
    borderStyle: { classNames: 'col-6' },
    borderWidth: { classNames: 'col-6' },
    fillAlpha: { classNames: 'col-6' },
    fillColor: { classNames: 'col-6' },
    lineAlpha: { classNames: 'col-6' },
    lineColor: { classNames: 'col-6' },
    lineStyle: { classNames: 'col-6' },
    lineThickness: { classNames: 'col-6' },
  }
};

export const getScreenData = (data: any) => {
  if (data) {
    return {
      ...data,
      Size: { width: data.width, height: data.height },
      Position: { x: data.x, y: data.y, z: data.z },
      checkButton: { showCheckBtn: data.showCheckBtn, checkButtonLabel: data.checkButtonLabel },
      max: { maxAttempt: data.maxAttempt, maxScore: data.maxScore }
    };
  }
}
export default screenSchema;
