import guid from 'utils/guid';
import { OrderingModelSchema as Ordering, ChoiceIdsToResponseId,
  TargetedOrdering, SimpleOrdering } from './schema';
import { RichText, Operation, ScoringStrategy, ChoiceId, Choice } from '../types';
import { create, ID, Identifiable, Paragraph } from 'data/content/model';

// Helper. Assumes a correct ID is given
export function getByIdUnsafe<T extends Identifiable>(slice: T[], id: string): T {
  return slice.find(c => c.id === id) || slice[0];
}

// Types
export function isSimpleOrdering(model: Ordering): model is SimpleOrdering {
  return model.type === 'SimpleOrdering';
}
export function isTargetedOrdering(model: Ordering): model is TargetedOrdering {
  return model.type === 'TargetedOrdering';
}

export type ChoiceMoveDirection = 'up' | 'down';

// Choices
export const canMoveChoice = (model: Ordering, id: ChoiceId, direction: ChoiceMoveDirection) => {
  const firstChoiceIndex = 0;
  const lastChoiceIndex = model.choices.length - 1;
  const thisChoiceIndex = getChoiceIndex(model, id);

  const canMoveUp = thisChoiceIndex > firstChoiceIndex;
  const canMoveDown = thisChoiceIndex < lastChoiceIndex;

  switch (direction) {
    case 'up': return canMoveUp;
    case 'down': return canMoveDown;
  }
};
export const canMoveChoiceUp = (model: Ordering, id: ChoiceId) =>
  canMoveChoice(model, id, 'up');
export const canMoveChoiceDown = (model: Ordering, id: ChoiceId) =>
  canMoveChoice(model, id, 'down');
export const getChoiceIndex = (model: Ordering, id: ChoiceId) =>
  model.choices.findIndex(choice => choice.id === id);
export const getChoice = (model: Ordering, id: ChoiceId) => getByIdUnsafe(model.choices, id);
// FIX
export const getChoiceIds = ([choiceIds]: ChoiceIdsToResponseId) => choiceIds;
export const getCorrectOrdering = (model: Ordering) => getChoiceIds(model.authoring.correct);
export const getTargetedChoiceIds = (model: TargetedOrdering) =>
  model.authoring.targeted.map(getChoiceIds);

// Responses
export const getResponses = (model: Ordering) => model.authoring.parts[0].responses;
export const getResponse = (model: Ordering, id: string) => getByIdUnsafe(getResponses(model), id);
export const getResponseId = ([, responseId]: ChoiceIdsToResponseId) => responseId;
export const getCorrectResponse = (model: Ordering) =>
  getResponse(model, getResponseId(model.authoring.correct));
export const getIncorrectResponse = (model: Ordering) => {
  const responsesWithoutCorrect = getResponses(model)
    .filter(response => response.id !== getCorrectResponse(model).id);

  switch (model.type) {
    case 'SimpleOrdering':
      return responsesWithoutCorrect[0];
    case 'TargetedOrdering':
      return responsesWithoutCorrect
        .filter(r1 => !getTargetedResponses(model).find(r2 => r1.id === r2.id))[0];
  }
};
export const getTargetedResponses = (model: TargetedOrdering) =>
  model.authoring.targeted.map(assoc => getResponse(model, getResponseId(assoc)));

// Hints
export const getHints = (model: Ordering) => model.authoring.parts[0].hints;
export const getHint = (model: Ordering, id: ID) => getByIdUnsafe(getHints(model), id);

// Rules
export const createMatchRule = (id: ID) => `input like {${id}}`;
export const createRuleForIds = (orderedIds: ID[]) => `input like {${orderedIds.join(' ')}}`;
export const invertRule = (rule: string) => `(!(${rule}))`;
export const unionTwoRules = (rule1: string, rule2: string) => `${rule2} && (${rule1})`;
export const unionRules = (rules: string[]) => rules.reduce(unionTwoRules);

// Other
export function setDifference<T>(subtractedFrom: T[], toSubtract: T[]) {
  return subtractedFrom.filter(x => !toSubtract.includes(x));
}

// Model creation
export const defaultOrderingModel : () => Ordering = () => {
  const choice1: Choice = fromText('Choice 1');
  const choice2: Choice = fromText('Choice 2');

  const correctResponse = makeResponse(createRuleForIds([choice1.id, choice2.id]), 1, '');
  const incorrectResponse = makeResponse(invertRule(correctResponse.rule), 0, '');

  return {
    type: 'SimpleOrdering',
    stem: fromText(''),
    choices: [
      choice1,
      choice2,
    ],
    authoring: {
      parts: [{
        id: '1', // a only has one part, so it is safe to hardcode the id
        scoringStrategy: ScoringStrategy.average,
        responses: [
          correctResponse,
          incorrectResponse,
        ],
        hints: [
          fromText(''),
          fromText(''),
          fromText(''),
        ],
      }],
      correct: [[choice1.id, choice2.id], correctResponse.id],
      transformations: [
        { id: guid(), path: 'choices', operation: Operation.shuffle },
      ],
      previewText: '',
    },
  };
};

export const makeResponse = (rule: string, score: number, text: '') =>
  ({ id: guid(), rule, score, feedback: fromText(text) });

export function fromText(text: string): { id: string, content: RichText } {
  return {
    id: guid() + '',
    content: {
      model: [
        create<Paragraph>({
          type: 'p',
          children: [{ text }],
          id: guid() + '',
        }),
      ],
      selection: null,
    },
  };
}

export const feedback = (text: string, match: string | number, score: number = 0) => ({
  ...fromText(text),
  match,
  score,
});
