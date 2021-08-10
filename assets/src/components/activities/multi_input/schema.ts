import {
  ActivityModelSchema,
  HasChoices,
  HasParts,
  HasPreviewText,
  HasStem,
  HasTransformations,
} from 'components/activities/types';

export type MultiInputSchema = HasStem &
  HasPreviewText &
  HasParts &
  HasTransformations &
  ActivityModelSchema;

// export interface ShortAnswerModelSchema extends ActivityModelSchema {
//   stem: Stem;
//   inputType: InputType;
//   authoring: {
//     parts: Part[];
//     transformations: Transformation[];
//     previewText: string;
//   };
// }

// numeric, input, dropdown, math
