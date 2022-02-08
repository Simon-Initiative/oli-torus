import { ImageCodingModelSchema } from './schema';
import { ScoringStrategy, makeFeedback, makeStem, makeHint } from '../types';
import { DEFAULT_PART_ID } from 'components/activities/common/utils';

export const defaultICModel: () => ImageCodingModelSchema = () => {
  return {
    stem: makeStem(''),
    isExample: false,
    starterCode: 'Sample Starter Code',
    solutionCode: 'Sample Solution Code',
    resourceURLs: [],
    tolerance: 1.0,
    regex: '', // from original, not clear how used or if needed
    feedback: [
      // order matters: feedback[score] is used for score in {0, 1}
      makeFeedback('Incorrect'),
      makeFeedback('Correct'),
    ],
    authoring: {
      parts: [
        {
          id: DEFAULT_PART_ID,
          scoringStrategy: ScoringStrategy.average,
          responses: [],
          hints: [makeHint(''), makeHint(''), makeHint('')],
        },
      ],
      previewText: '',
    },
  };
};

export function lastPart(path: string): string {
  return path.substring(path.lastIndexOf('/') + 1);
}
