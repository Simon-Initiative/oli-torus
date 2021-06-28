import { JSONSchema7 } from 'json-schema';
const screenSchema: JSONSchema7 = {
  type: 'object',
  properties: {
    width: { type: 'number' },
    height: { type: 'number' },
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
    showCheckBtn: {
      title: 'Show Check Button',
      type: 'boolean',
      format: 'checkbox',
      default: true,
    },
    checkButtonLabel: {
      title: 'Checkbutton Label',
      type: 'string',
    },
    maxAttempt: {
      title: 'Max Attempts',
      type: 'number',
    },
    maxScore: {
      title: 'Max Score',
      type: 'number',
    },
    screenButton: {
      title: 'Screen Button',
      type: 'boolean',
      format: 'checkbox',
      default: true,
    },
    combineFeedback: {
      title: 'Combine Feedback',
      type: 'boolean',
      format: 'checkbox',
      default: true,
    },
    customCssClass: {
      title: 'Custom CSS Class',
      type: 'string',
    },
  },
};

export default screenSchema;
