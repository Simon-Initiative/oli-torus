import { HasParts, Part, RichText } from 'components/activities/types';
import { toSimpleText } from 'components/editing/slateUtils';
import { findTargetedResponses } from 'data/activities/model/responses';
import { getPartById } from 'data/activities/model/utils';
import {
  ActivityTrigger,
  makeHintTrigger,
  makeTargetedTrigger,
  makeTrigger,
  sameTrigger,
} from 'data/triggers';

export const getPossibleTriggers = (model: HasParts, partId: string): ActivityTrigger[] => {
  const part = getPartById(model, partId);

  const triggers = [makeTrigger('correct_answer'), makeTrigger('incorrect_answer')];
  const hint_triggers = part.hints.map((_h, i) => makeHintTrigger(i + 1));
  const targeted_triggers = findTargetedResponses(model, partId).map((r: any) =>
    makeTargetedTrigger(r.id),
  );
  const explanation_triggers = part.explanation ? [makeTrigger('explanation')] : [];

  return triggers.concat(
    hint_triggers,
    targeted_triggers,
    explanation_triggers,
  ) as ActivityTrigger[];
};

export const getAvailableTriggers = (model: HasParts, partId: string) => {
  const all_triggers = getPossibleTriggers(model, partId);
  const has_trigger = (t: ActivityTrigger) =>
    getPartById(model, partId).triggers?.some((existing) => sameTrigger(t, existing));

  return all_triggers.filter((t: ActivityTrigger) => !has_trigger(t));
};

export const describeTrigger = (t: ActivityTrigger, part: Part) => {
  const nth = [
    'zeroth',
    'first',
    'second',
    'third',
    'fourth',
    'fifth',
    'sixth',
    'seventh',
    'eighth',
  ];

  const shortText = (content: RichText) => {
    const MAX = 30;
    const full = toSimpleText(content);
    return full.length < MAX ? full : full.slice(0, MAX - 3) + '...';
  };

  switch (t.trigger_type) {
    case 'correct_answer':
      return 'Student submits correct answer';
    case 'incorrect_answer':
      return 'Student submits incorrect answer';
    case 'explanation':
      return `Student triggers explanation (${shortText(part.explanation!.content)})`;
    case 'hint':
      const hint = shortText(part.hints[t.hint_number - 1].content);
      return `Student requests ${nth[t.hint_number]} hint (${hint})`;
    case 'targeted_feedback':
      const response = part.responses.find((r) => r.id == t.response_id);
      const feedback = response ? shortText(response.feedback.content) : 'not found';
      return `Student triggers targeted feedback (${feedback})`;
    default:
      console.error('unrecognized activity trigger type');
      return '[unknown]';
  }
};
