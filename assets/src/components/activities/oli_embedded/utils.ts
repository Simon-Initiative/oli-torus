import guid from 'utils/guid';
import * as ContentModel from 'data/content/model';
import { OliEmbeddedModelSchema } from './schema';
import { RichText, ScoringStrategy } from '../types';

export const defaultEmbeddedModel: () => OliEmbeddedModelSchema = () => {
  return {
    stem: fromText(''),
    title: 'Embedded activity',
    authoring: {
      parts: [{
        id: '1', // an embedded only has one part, so it is safe to hardcode the id
        scoringStrategy: ScoringStrategy.average,
        responses: [],
        hints: [],
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