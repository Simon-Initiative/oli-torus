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

  const nonBlank = (o: { content: RichText }) => toSimpleText(o.content) != '';

  const triggers = [makeTrigger('correct_answer'), makeTrigger('incorrect_answer')];
  const hint_triggers = part.hints.filter(nonBlank).map((_h, i) => makeHintTrigger(i + 1));
  const targeted_triggers = findTargetedResponses(model, partId).map((r: any) =>
    makeTargetedTrigger(r.id),
  );
  const explanation_triggers =
    part.explanation && nonBlank(part.explanation) ? [makeTrigger('explanation')] : [];

  return triggers.concat(
    hint_triggers,
    targeted_triggers,
    explanation_triggers,
  ) as ActivityTrigger[];
};

export const findTrigger = (model: HasParts, partId: string, trigger: ActivityTrigger) =>
  getPartById(model, partId).triggers?.find((t) => sameTrigger(t, trigger));

export const hasTrigger = (model: HasParts, partId: string, trigger: ActivityTrigger) =>
  findTrigger(model, partId, trigger) != null;

const nth = ['zeroth', 'first', 'second', 'third', 'fourth', 'fifth', 'sixth', 'seventh', 'eighth'];

export const describeTrigger = (t: ActivityTrigger, part: Part, maxchars: number | null = 80) => {
  const addContent = (prefix: string, content: RichText | undefined) => {
    const textContent = content ? toSimpleText(content) : 'not found';
    const full = `${prefix} (${textContent})`;
    if (maxchars == null || full.length <= maxchars) return full;

    return full.slice(0, maxchars - 4) + '...)';
  };

  switch (t.trigger_type) {
    case 'correct_answer':
      return 'Student submits correct answer';

    case 'incorrect_answer':
      return 'Student submits incorrect answer';

    case 'explanation':
      const explanation = part.explanation!.content;
      return addContent('Student triggers explanation', explanation);

    case 'hint':
      const hint = part.hints[t.ref_id - 1].content;
      return addContent(`Student requests ${nth[t.ref_id]} hint`, hint);

    case 'targeted_feedback':
      const response = part.responses.find((r) => r.id == t.ref_id);
      const feedback = response?.feedback.content;
      return addContent('Student triggers targeted feedback', feedback);

    default:
      console.error('unrecognized activity trigger type');
      return '[unknown]';
  }
};
