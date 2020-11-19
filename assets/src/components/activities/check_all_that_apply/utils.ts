import guid from 'utils/guid';
import * as ContentModel from 'data/content/model';
import { Choice, CheckAllThatApplyModelSchema, CATACombinations, CATACombination } from './schema';
import { RichText, Operation, ScoringStrategy, Response } from '../types';
import { Maybe } from 'tsmonad';

export function getById<T extends ContentModel.Identifiable>(slice: T[], id: string): Maybe<T> {
  return Maybe.maybe(slice.find(c => c.id === id));
}
export function getChoice(model: CheckAllThatApplyModelSchema, id: string) {
  return getById(model.choices, id);
}
export function getResponses(model: CheckAllThatApplyModelSchema) {
  return model.authoring.parts[0].responses;
}
export function getResponse(model: CheckAllThatApplyModelSchema, id: string) {
  return getById(getResponses(model), id);
}
export function getCorrectResponse(model: CheckAllThatApplyModelSchema) {
  return getResponses(model).filter(r => r.score !== 0)[0];
}
export function getIncorrectResponses(model: CheckAllThatApplyModelSchema) {
  return getResponses(model).filter(r => r.score === 0);
}
export function getHints(model: CheckAllThatApplyModelSchema) {
  return model.authoring.parts[0].hints;
}
export function getHint(model: CheckAllThatApplyModelSchema, id: string) {
  return getById(getHints(model), id);
}
export function isCorrect(response: Response) {
  return response.score > 0;
}
// A choice can
export function getMatchingResponses(model: CheckAllThatApplyModelSchema, choice: Choice) {
  return Maybe.maybe(getResponses(model).find(response =>
    response.rule === `input like {${choice.id}}`));
}

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

export const defaultCATAModel : () => CheckAllThatApplyModelSchema = () => {
  const choiceA: Choice = fromText('Choice A');
  const choiceB: Choice = fromText('Choice B');

  // const allCombinations = combinations([choiceA, choiceB]);
  // const correctCombination: CATACombination = [choiceA];
  // const incorrectCombinations = combinationsWithout(allCombinations, correctCombination);

  // console.log('allCombinations', allCombinations)
  // console.log('correctCombination', correctCombination)
  // console.log('incorrectCombinations', incorrectCombinations)

  // ...incorrectCombinations.map(combo =>
  // combo.map(c => `input like ${c.id}`).join(' && ')),

  return {
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
          makeResponse(`input like {${choiceA.id}} && ! input like {${choiceB.id}}`, 1, ''),
          makeResponse(`input like {${choiceB.id}} && ! input like {${choiceA.id}}`, 0, ''),
        ],
        hints: [
          fromText(''),
          fromText(''),
          fromText(''),
        ],
      }],
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
