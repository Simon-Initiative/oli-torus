import guid from 'utils/guid';
import * as ContentModel from 'data/content/model';
import { RichText, Choice, MultipleChoiceModelSchema } from './schema';

export const defaultMCModel : () => MultipleChoiceModelSchema = () => {
  const choiceA: Choice = fromText('Choice A');
  const choiceB: Choice = fromText('Choice B');

  const feedbackA = feedback('', choiceA.id, 1);
  const feedbackB = feedback('', choiceB.id, 0);

  return {
    stem: fromText(''),
    choices: [
      choiceA,
      choiceB,
    ],
    authoring: {
      feedback: [
        feedbackA,
        feedbackB,
      ],
      hints: [
        fromText(''),
        fromText(''),
        fromText(''),
      ],
    },
  };
};

export function fromText(text: string): { id: number, content: RichText } {
  return {
    id: guid(),
    content: [
      ContentModel.create<ContentModel.Paragraph>({
        type: 'p',
        children: [{ text }],
        id: guid(),
      }),
    ],
  };
}

export const feedback = (text: string, match: string | number, score: number = 0) => ({
  ...fromText(text),
  match,
  score,
});

// fisher-yates algo
export function shuffle<T>(arr: T[]): T[] {
  // inclusive min, max
  const randomNumber = (min: number, max: number) =>
    Math.floor(Math.random() * (Math.floor(max) - Math.ceil(min) + 1)) + Math.ceil(min);

  const swap = (arr: T[], i: number, j: number) => {
    const temp = arr[i];
    arr[i] = arr[j];
    arr[j] = temp;
  };

  for (let i = arr.length - 1; i > 0; i -= 1) {
    swap(arr, i, randomNumber(0, i));
  }
  return arr;
}
