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

// Choices
export const getChoice = (model: Ordering, id: string) => getByIdUnsafe(model.choices, id);
export const getChoiceIds = ([choiceIds]: ChoiceIdsToResponseId) => choiceIds;
export const getCorrectChoiceIds = (model: Ordering) => getChoiceIds(model.authoring.correct);
export const getIncorrectChoiceIds = (model: Ordering) => getChoiceIds(model.authoring.incorrect);
export const getTargetedChoiceIds = (model: TargetedOrdering) =>
  model.authoring.targeted.map(getChoiceIds);
export const isCorrectChoice = (model: Ordering, choiceId: ChoiceId) =>
  getCorrectChoiceIds(model).includes(choiceId);

// Responses
export const getResponses = (model: Ordering) => model.authoring.parts[0].responses;
export const getResponse = (model: Ordering, id: string) => getByIdUnsafe(getResponses(model), id);
export const getResponseId = ([, responseId]: ChoiceIdsToResponseId) => responseId;
export const getCorrectResponse = (model: Ordering) =>
  getResponse(model, getResponseId(model.authoring.correct));
export const getIncorrectResponse = (model: Ordering) =>
  getResponse(model, getResponseId(model.authoring.incorrect));
export const getTargetedResponses = (model: TargetedOrdering) =>
  model.authoring.targeted.map(assoc => getResponse(model, getResponseId(assoc)));

// Hints
export const getHints = (model: Ordering) => model.authoring.parts[0].hints;
export const getHint = (model: Ordering, id: ID) => getByIdUnsafe(getHints(model), id);

// Rules
export const createRuleForIds = (toMatch: ID[], notToMatch: ID[]) =>
  unionRules(
    toMatch.map(createMatchRule)
    .concat(notToMatch.map(id => invertRule(createMatchRule(id)))));
export const createMatchRule = (id: string) => `input like {${id}}`;
export const invertRule = (rule: string) => `(!(${rule}))`;
export const unionTwoRules = (rule1: string, rule2: string) => `${rule2} && (${rule1})`;
export const unionRules = (rules: string[]) => rules.reduce(unionTwoRules);

// Other
export function setDifference<T>(subtractedFrom: T[], toSubtract: T[]) {
  return subtractedFrom.filter(x => !toSubtract.includes(x));
}

// Model creation
export const defaultOrderingModel : () => Ordering = () => {
  const correctChoice: Choice = fromText('Choice 1');
  const incorrectChoice: Choice = fromText('Choice 2');

  const correctResponse = makeResponse(createRuleForIds(
    [correctChoice.id], [incorrectChoice.id]), 1, '');
  const incorrectResponse = makeResponse(invertRule(correctResponse.rule), 0, '');

  return {
    type: 'SimpleOrdering',
    stem: fromText(''),
    choices: [
      correctChoice,
      incorrectChoice,
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
      correct: [[correctChoice.id], correctResponse.id],
      incorrect: [[incorrectChoice.id], incorrectResponse.id],
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
