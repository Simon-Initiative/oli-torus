import { Maybe } from 'tsmonad';
import { Responses } from 'data/activities/model/responses';
import { makeHint, makePart, makeStem } from '../types';
import { LikertChoice, LikertModelSchema, makeLikertChoice, makeLikertItem } from './schema';

export const defaultLikertModel: () => LikertModelSchema = () => {
  const choiceA: LikertChoice = makeLikertChoice('Agree');
  const choiceB: LikertChoice = makeLikertChoice('Neither Agree Nor Disagree');
  const choiceC: LikertChoice = makeLikertChoice('Disagree');
  const item1 = makeLikertItem('item 1');
  return {
    stem: makeStem('Prompt (optional)'),
    choices: [choiceA, choiceB, choiceC],
    orderDescending: false,
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
      transformations: [],
      targeted: [],
      previewText: '',
    },
  };
};

export const getChoiceValue = (model: LikertModelSchema, i: number): number => {
  // TODO: use optional custom value if it is specified
  return model.orderDescending ? model.choices.length - i : i + 1;
};
