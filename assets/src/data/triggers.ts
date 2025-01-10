/**
 * AI Trigger Types
 */

export interface IsTrigger {
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
  response_id: string;
}

export interface HintTrigger extends IsTrigger {
  trigger_type: 'hint';
  hint_number: number; // 1-based ordinal
}

export type ContentTrigger = PageTrigger | GroupTrigger | BlockTrigger;

export interface PageTrigger extends IsTrigger {
  trigger_type: 'page';
}

export interface GroupTrigger extends IsTrigger {
  trigger_type: 'group';
}

export interface BlockTrigger extends IsTrigger {
  trigger_type: 'content';
}
