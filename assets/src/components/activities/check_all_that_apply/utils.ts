import guid from 'utils/guid';
import * as ContentModel from 'data/content/model';
import { Choice, CheckAllThatApplyModelSchema as CATA, CATACombinations, CATACombination, ChoiceIdsToResponseId, TargetedCATA } from './schema';
import { RichText, Operation, ScoringStrategy, Response, ChoiceId } from '../types';
import { Maybe } from 'tsmonad';

// Assumes a correct ID is given
export function getByIdUnsafe<T extends ContentModel.Identifiable>(slice: T[], id: string): T {
  return slice.find(c => c.id === id) || slice[0];
}
export function getChoice(model: CATA, id: string) {
  return getByIdUnsafe(model.choices, id);
}
export function getResponses(model: CATA) {
  return model.authoring.parts[0].responses;
}
export function getResponse(model: CATA, id: string) {
  return getByIdUnsafe(getResponses(model), id);
}
// Assumes there is one correct response. Change to support partial credit.
export function getCorrectResponse(model: CATA) {
  return getResponse(model, getResponseId(model.authoring.correct));
}
export function getIncorrectResponse(model: CATA) {
  return getResponse(model, getResponseId(model.authoring.incorrect));
}
export function getCorrectChoiceIds(model: CATA): ChoiceId[] {
  return getChoiceIds(model.authoring.correct);
}
export function getIncorrectChoiceIds(model: CATA): ChoiceId[] {
  return getChoiceIds(model.authoring.incorrect);
}
export function getTargetedChoiceIds(model: TargetedCATA): ChoiceId[][] {
  return model.authoring.targeted.map(getChoiceIds);
}
export function getTargetedResponses(model: TargetedCATA): Response[] {
  return model.authoring.targeted.map(assoc => getResponse(model, getResponseId(assoc)));
}
export function getHints(model: CATA) {
  return model.authoring.parts[0].hints;
}
export function getHint(model: CATA, id: string) {
  return getByIdUnsafe(getHints(model), id);
}
export function getChoiceIds(assoc: ChoiceIdsToResponseId) {
  return assoc[0];
}
export function getResponseId(assoc: ChoiceIdsToResponseId) {
  return assoc[1];
}
export function setDifference<T>(subtractedFrom: T[], toSubtract: T[]) {
  return subtractedFrom.filter(x => !toSubtract.includes(x));
}
// export function getMatchingResponse(model: CATA, choiceIds: string[]) {
//   return Maybe.maybe(model.authoring.choiceIdsToResponses.find(association => {
//     // Matching response is found when the choiceIds has a perfect intersection
//     // with a choiceIdsToResponses choiceId association list item
//     return getChoiceIdsFromAssociation(association).every(id => choiceIds.includes(id))
//       && choiceIds.every(id => getChoiceIdsFromAssociation(association).includes(id));
//   }))
//     .lift(association => getResponse(model, getResponseIdFromAssociation(association)));
// }
// export function getChoicesForResponse(model: CATA, response: Response) {
//   return Maybe.maybe(model.authoring.choiceIdsToResponses.find(association =>
//     response.id === getResponseIdFromAssociation(association)))
//   .lift(association => getChoiceIdsFromAssociation(association))
// }
export function isCorrectChoice(model: CATA, choiceId: ChoiceId) {
  return getCorrectChoiceIds(model).includes(choiceId);
}

// mutable, for use in immer actions
export function addOrRemoveFromList<T>(item: T, list: T[]) {
  if (list.find(x => x === item)) {
    return removeFromList(item, list);
  }
  return list.push(item);
}
// mutable, for use in immer actions
export function removeFromList<T>(item: T, list: T[]) {
  const index = list.findIndex(x => x === item);
  if (index > -1) {
    list.splice(index, 1);
  }
}

export function createRuleForIds(toMatch: string[], notToMatch: string[]) {
  return unionRules(
    toMatch.map(createMatchRule)
    .concat(notToMatch.map(id => invertRule(createMatchRule(id)))));
}
export function createMatchRule(id: string) {
  return `input like {${id}}`;
}
export function invertRule(rule: string) {
  return `!(${rule})`;
}
export function unionRules(rules: string[]) {
  return rules.join(' && ');
}

// correct response rule: input like {A} && input like {B} && ! input like {C}
// write a rule matcher
// [id] =>

/*
Simple:
A, B, C
Correct: A, B
Incorrect: any other combinations

Correct Submission: { input: "A B" }
  input like {A} && input like {B} && ! input like {C}

Incorrect Submission: { input: "A" }, { input: "A C" }
  ! (input like {A} && input like {B} && ! input like {C})
    Invert correct submission


Targeted:
Correct Submission: { input: "A B" }
  input like {A} && input like {B} && ! input like {C}

Targeted 1:
  input like {A} && ! input like {B} && ! input like {C}
    each targeted input needs a full set of conditions

Incorrect Submission: { input: "A" }
  ! correctInput && ! targeted1 && ! targeted2

There's only one correct submission.
Add option for partial scoring
Partial Score = # correct / # total correct


*/


// combinations of ids. e.g. combinations([1, 2]) == [[], [1], [1, 2], [2]]
// Θ(2ⁿ)
export function combinations([first, ...rest]: ContentModel.Identifiable[]): CATACombinations {
  if (first === undefined) return [[]];
  const withouts = combinations(rest);
  return withouts.concat(withouts.map(without => without.concat(first)));
}
export function combinationsWithout(
  combinations: CATACombinations, toRemove: CATACombination): CATACombinations {
  const combosMatch = (combo1: CATACombination, combo2: CATACombination) =>
    combo1.every(c1 => combo2.includes(c1)) && combo2.every(c2 => combo1.includes(c2));

  return combinations.filter(combo => !combosMatch(combo, toRemove));
}

export const makeResponse = (rule: string, score: number, text: '') =>
  ({ id: guid(), rule, score, feedback: fromText(text) });

export const defaultCATAModel : () => CATA = () => {
  const choiceA: Choice = fromText('Choice A');
  const choiceB: Choice = fromText('Choice B');

  const correctResponse = makeResponse(`input like {${choiceA.id}} && ! input like {${choiceB.id}}`, 1, '');
  const incorrectResponse = makeResponse(`input like {${choiceB.id}} && ! input like {${choiceA.id}}`, 0, '');

  // const allCombinations = combinations([choiceA, choiceB]);
  // const correctCombination: CATACombination = [choiceA];
  // const incorrectCombinations = combinationsWithout(allCombinations, correctCombination);

  // console.log('allCombinations', allCombinations)
  // console.log('correctCombination', correctCombination)
  // console.log('incorrectCombinations', incorrectCombinations)

  // ...incorrectCombinations.map(combo =>
  // combo.map(c => `input like ${c.id}`).join(' && ')),

  return {
    type: 'SimpleCATA',
    stem: fromText(''),
    choices: [
      choiceA,
      choiceB,
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
      correct: [[choiceA.id], correctResponse.id],
      incorrect: [[choiceB.id], incorrectResponse.id],
      transformations: [
        { id: guid(), path: 'choices', operation: Operation.shuffle },
      ],
      previewText: '',
    },
  };
};

export function fromText(text: string): { id: string, content: RichText } {
  return {
    id: guid() + '',
    content: {
      model: [
        ContentModel.create<ContentModel.Paragraph>({
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
