import { ImageCodingModelSchema } from './schema';
import { ScoringStrategy } from '../types';
import { DEFAULT_PART_ID } from 'components/activities/common/utils';
import { fromText } from 'components/activities/adaptive/utils';

export const defaultICModel: () => ImageCodingModelSchema = () => {
  return {
    stem: fromText(''),
    isExample: false,
    starterCode: 'Sample Starter Code',
    solutionCode: 'Sample Solution Code',
    resourceURLs: [],
    tolerance: 1.0,
    regex: '', // from original, not clear how used or if needed
    feedback: [
      // order matters: feedback[score] is used for score in {0, 1}
      fromText('Incorrect'),
      fromText('Correct'),
    ],
    authoring: {
      parts: [
        {
          id: DEFAULT_PART_ID,
          scoringStrategy: ScoringStrategy.average,
          responses: [],
          hints: [fromText(''), fromText(''), fromText('')],
        },
      ],
      previewText: '',
    },
  };
};

export function lastPart(path: string): string {
  return path.substring(path.lastIndexOf('/') + 1);
}

export const feedback = (text: string, match: string | number, score = 0) => ({
  ...fromText(text),
  match,
  score,
});
