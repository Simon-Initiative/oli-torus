import { LikertModelSchema, makeLikertChoice, makeLikertItem, LikertChoice } from './schema';
import { makeStem, makeHint, makeChoice, makePart, Choice } from '../types';

import { Responses } from 'data/activities/model/responses';

export const defaultLikertModel: () => LikertModelSchema = () => {
  const choiceA: LikertChoice = makeLikertChoice('Agree');
  const choiceB: LikertChoice = makeLikertChoice('Neither Agree Nor Disagree');
  const choiceC: LikertChoice = makeLikertChoice('Disagree');
  const item1 = makeLikertItem('item 1');
  return {
    stem: makeStem('Prompt (optional)'),
    choices: [choiceA, choiceB, choiceC],
    items: [item1],
    authoring: {
      parts: [
        makePart(
          Responses.forMultipleChoice(choiceA.id),
          [makeHint(''), makeHint(''), makeHint('')],
          // partId is same as associated item's
          item1.id,
        ),
      ],
      targeted: [],
      previewText: '',
    },
  };
};
