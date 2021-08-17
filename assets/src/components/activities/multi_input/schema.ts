import {
  ActivityModelSchema,
  HasStem,
  HasParts,
  HasTransformations,
  HasPreviewText,
  HasChoices,
  ChoiceIdsToResponseId,
} from '../types';

export type MultiInputSchema = HasStem &
  HasChoices &
  HasParts &
  HasTransformations &
  HasPreviewText &
  ActivityModelSchema & {
    authoring: {
      targeted: ChoiceIdsToResponseId[];
    };
  };
