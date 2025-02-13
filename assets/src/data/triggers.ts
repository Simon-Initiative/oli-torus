import guid from 'utils/guid';

/**
 * AI Trigger Types
 */

export interface IsTrigger {
  id: string;
  type: 'trigger';
  trigger_type: string;
  prompt: string;
}

export type Trigger = ActivityTrigger | ContentTrigger;

export type ActivityTrigger = SimpleActivityTrigger | HintTrigger | TargetedFeedbackTrigger;

export interface SimpleActivityTrigger extends IsTrigger {
  trigger_type: 'correct_answer' | 'incorrect_answer' | 'explanation';
}

export interface TargetedFeedbackTrigger extends IsTrigger {
  trigger_type: 'targeted_feedback';
  ref_id: string;
}

export interface HintTrigger extends IsTrigger {
  trigger_type: 'hint';
  ref_id: number; // 1-based ordinal
}

export type ContentTrigger = PageTrigger | GroupTrigger | ContentBlockTrigger;

export interface PageTrigger extends IsTrigger {
  trigger_type: 'page';
}

export interface GroupTrigger extends IsTrigger {
  trigger_type: 'group';
}

export interface ContentBlockTrigger extends IsTrigger {
  trigger_type: 'content';
}

export const makeTrigger = (trigger_type: string) => {
  return { id: guid(), type: 'trigger', trigger_type, prompt: '' };
};

export const makeHintTrigger = (hint_number: number) =>
  Object.assign(makeTrigger('hint'), { ref_id: hint_number });

export const makeTargetedTrigger = (response_id: string) =>
  Object.assign(makeTrigger('targeted_feedback'), { ref_id: response_id });

export const sameTrigger = (t1: Trigger, t2: Trigger) => {
  switch (t1.trigger_type) {
    case 'hint':
      return t2.trigger_type === 'hint' && t1.ref_id === t2.ref_id;
    case 'targeted_feedback':
      return t2.trigger_type === 'targeted_feedback' && t1.ref_id === t2.ref_id;
    default:
      return t1.trigger_type === t2.trigger_type;
  }
};
