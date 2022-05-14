import { ActivityModelSchema, Stem, Part, Choice, ChoiceIdsToResponseId } from '../types';

export interface LikertModelSchema extends ActivityModelSchema {
  stem: Stem;
  choices: Choice[]; // scale elements
  items: Choice[];
  authoring: {
    targeted: ChoiceIdsToResponseId[];
    parts: Part[];
    previewText: string;
  };
}

export interface ModelEditorProps {
  model: LikertModelSchema;
  editMode: boolean;
}
