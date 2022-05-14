import { LikertModelSchema } from './schema';
import { makeStem, makeHint, makeChoice, makePart, Choice } from '../types';

import { Responses } from 'data/activities/model/responses';

export const defaultLikertModel: () => LikertModelSchema = () => {
  const choiceA: Choice = makeChoice('Agree');
  const choiceB: Choice = makeChoice('Neither Agree Nor Disagree');
  const choiceC: Choice = makeChoice('Disagree');
  const item1 = makeChoice('item 1');
  return {
    stem: makeStem('Prompt (optional)'),
    choices: [choiceA, choiceB, choiceC],
    items: [item1],
    authoring: {
      parts: [
        makePart(
          Responses.forMultipleChoice(choiceA.id),
          [makeHint(''), makeHint(''), makeHint('')],
          item1.id,
        ),
      ],
      targeted: [],
      previewText: '',
    },
  };
};
