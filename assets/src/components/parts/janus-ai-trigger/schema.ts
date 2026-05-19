import { JSONSchema7Object } from 'json-schema';
import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export type AITriggerLaunchMode = 'auto' | 'click';

export interface AITriggerModel extends JanusAbsolutePositioned, JanusCustomCss {
  launchMode: AITriggerLaunchMode;
  prompt: string;
  ariaLabel?: string;
}

export const schema: JSONSchema7Object = {
  launchMode: {
    title: 'Activation Mode',
    type: 'string',
    enum: ['auto', 'click'],
    default: 'click',
  },
  prompt: {
    title: 'AI Activation Prompt',
    type: 'string',
  },
  ariaLabel: {
    title: 'Accessible Label',
    type: 'string',
  },
  customCssClass: {
    title: 'Custom CSS Class',
    type: 'string',
  },
};

export const uiSchema = {
  launchMode: {
    'ui:enumNames': ['Auto Activated', 'User Activated'],
  },
  prompt: {
    'ui:widget': 'textarea',
    'ui:options': {
      rows: 5,
    },
  },
};

export const createSchema = (): Partial<AITriggerModel> => ({
  width: 56,
  height: 56,
  launchMode: 'click',
  prompt: '',
  ariaLabel: 'Open DOT AI assistant',
  customCssClass: '',
});
