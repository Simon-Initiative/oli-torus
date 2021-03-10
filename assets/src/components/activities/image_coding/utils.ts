import guid from 'utils/guid';
import * as ContentModel from 'data/content/model';
import { ImageCodingModelSchema } from './schema';
import { RichText, ScoringStrategy } from '../types';

export const defaultICModel : () => ImageCodingModelSchema = () => {

  return {
    stem: fromText(''),
    isExample: false,
    starterCode: 'Sample Starter Code',
    solutionCode: 'Sample Solution Code',
    imageURLs: [],
    tolerance: 1.0,
    regex: '',  // from original, not clear how used or if needed
    feedback: [ // order matters: feedback[score] is used for score in {0, 1}
      fromText('Incorrect'),
      fromText('Correct'),
    ],
    authoring: {
      parts: [{
        id: '1', // an IC only has one part, so it is safe to hardcode the id
        scoringStrategy: ScoringStrategy.average,
        responses: [],
        hints: [
          fromText(''),
          fromText(''),
          fromText(''),
        ],
      }],
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

export function lastPart(path: string): string {
  return path.substring(path.lastIndexOf('/') + 1);
}

export const feedback = (text: string, match: string | number, score: number = 0) => ({
  ...fromText(text),
  match,
  score,
});
