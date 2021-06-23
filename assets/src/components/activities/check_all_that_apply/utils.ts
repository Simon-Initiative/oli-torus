import guid from 'utils/guid';
import {
  CheckAllThatApplyModelSchema as CATA,
  ChoiceIdsToResponseId,
  TargetedCATA,
  SimpleCATA,
} from './schema';
import { ID, Identifiable } from 'data/content/model';
import {
  ChoiceId,
  makeChoice,
  makeHint,
  makeResponse,
  makeStem,
  makeTransformation,
  Operation,
  ScoringStrategy,
} from 'components/activities/types';

// Helper. Assumes a correct ID is given
export function getByIdUnsafe<T extends Identifiable>(slice: T[], id: string): T {
  return slice.find((c) => c.id === id) || slice[0];
}

// Types
export function isSimpleCATA(model: CATA): model is SimpleCATA {
  return model.type === 'SimpleCATA';
}
export function isTargetedCATA(model: CATA): model is TargetedCATA {
  return model.type === 'TargetedCATA';
}

// Choices
export const getChoice = (model: CATA, id: string) => getByIdUnsafe(model.choices, id);
export const getChoiceIds = ([choiceIds]: ChoiceIdsToResponseId) => choiceIds;
export const getCorrectChoiceIds = (model: CATA) => getChoiceIds(model.authoring.correct);
export const getIncorrectChoiceIds = (model: CATA) => getChoiceIds(model.authoring.incorrect);
export const getTargetedChoiceIds = (model: TargetedCATA) =>
  model.authoring.targeted.map(getChoiceIds);
export const isCorrectChoice = (model: CATA, choiceId: ChoiceId) =>
  getCorrectChoiceIds(model).includes(choiceId);

// Responses
export const getResponses = (model: CATA) => model.authoring.parts[0].responses;
export const getResponse = (model: CATA, id: string) => getByIdUnsafe(getResponses(model), id);
export const getResponseId = ([, responseId]: ChoiceIdsToResponseId) => responseId;
export const getCorrectResponse = (model: CATA) =>
  getResponse(model, getResponseId(model.authoring.correct));
export const getIncorrectResponse = (model: CATA) =>
  getResponse(model, getResponseId(model.authoring.incorrect));
export const getTargetedResponses = (model: TargetedCATA) =>
  model.authoring.targeted.map((assoc) => getResponse(model, getResponseId(assoc)));

// Hints
export const getHints = (model: CATA) => model.authoring.parts[0].hints;
export const getHint = (model: CATA, id: ID) => getByIdUnsafe(getHints(model), id);

// Rules
export const createRuleForIds = (toMatch: ID[], notToMatch: ID[]) =>
  unionRules(
    toMatch.map(createMatchRule).concat(notToMatch.map((id) => invertRule(createMatchRule(id)))),
  );
export const createMatchRule = (id: string) => `input like {${id}}`;
export const invertRule = (rule: string) => `(!(${rule}))`;
export const unionTwoRules = (rule1: string, rule2: string) => `${rule2} && (${rule1})`;
export const unionRules = (rules: string[]) => rules.reduce(unionTwoRules);

// Other
export function setDifference<T>(subtractedFrom: T[], toSubtract: T[]) {
  return subtractedFrom.filter((x) => !toSubtract.includes(x));
}

// Model creation
export const defaultCATAModel: () => CATA = () => {
  const correctChoice = makeChoice('Choice 1');
  const incorrectChoice = makeChoice('Choice 2');

  const correctResponse = makeResponse(
    createRuleForIds([correctChoice.id], [incorrectChoice.id]),
    1,
    '',
  );
  const incorrectResponse = makeResponse(invertRule(correctResponse.rule), 0, '');

  return {
    type: 'SimpleCATA',
    stem: makeStem(''),
    choices: [correctChoice, incorrectChoice],
    authoring: {
      parts: [
        {
          id: '1', // a only has one part, so it is safe to hardcode the id
          scoringStrategy: ScoringStrategy.average,
          responses: [correctResponse, incorrectResponse],
          hints: [makeHint(''), makeHint(''), makeHint('')],
        },
      ],
      correct: [[correctChoice.id], correctResponse.id],
      incorrect: [[incorrectChoice.id], incorrectResponse.id],
      transformations: [makeTransformation('choices', Operation.shuffle)],
      previewText: '',
    },
  };
};
