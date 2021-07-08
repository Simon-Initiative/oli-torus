import guid from 'utils/guid';
import { OrderingModelSchema as Ordering, TargetedOrdering, SimpleOrdering } from './schema';
import { Operation, ScoringStrategy, makeStem, makeHint, makeChoice, makeResponse } from '../types';
import {
  createRuleForIds,
  invertRule,
} from 'components/activities/common/responses/authoring/rules';

// Types
export function isSimpleOrdering(model: Ordering): model is SimpleOrdering {
  return model.type === 'SimpleOrdering';
}
export function isTargetedOrdering(model: Ordering): model is TargetedOrdering {
  return model.type === 'TargetedOrdering';
}

// Model creation
export const defaultOrderingModel: () => Ordering = () => {
  const choice1 = makeChoice('Choice 1');
  const choice2 = makeChoice('Choice 2');

  const correctResponse = makeResponse(createRuleForIds([choice1.id, choice2.id], []), 1, '');
  const incorrectResponse = makeResponse(invertRule(correctResponse.rule), 0, '');

  return {
    type: 'SimpleOrdering',
    stem: makeStem(''),
    choices: [choice1, choice2],
    authoring: {
      parts: [
        {
          id: '1', // a only has one part, so it is safe to hardcode the id
          scoringStrategy: ScoringStrategy.average,
          responses: [correctResponse, incorrectResponse],
          hints: [makeHint(''), makeHint(''), makeHint('')],
        },
      ],
      correct: [[choice1.id, choice2.id], correctResponse.id],
      transformations: [{ id: guid(), path: 'choices', operation: Operation.shuffle }],
      previewText: '',
    },
  };
};
