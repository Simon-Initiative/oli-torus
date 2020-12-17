
import { Part, Transformation, ActivityModelSchema, Stem, ChoiceId, ResponseId, Choice } from '../types';

export type OrderingModelSchema = SimpleOrdering | TargetedOrdering;

export type ChoiceIdsToResponseId = [ChoiceId[], ResponseId];

interface BaseOrdering extends ActivityModelSchema {
  stem: Stem;
  choices: Choice[];
  authoring: {
    // An association list of the choice ids in the correct order to the matching response id
    correct: ChoiceIdsToResponseId;
    parts: Part[];
    transformations: Transformation[];
    previewText: string;
  };
}

export type SimpleOrdering = BaseOrdering & {
  type: 'SimpleOrdering';
};

export type TargetedOrdering = BaseOrdering & {
  type: 'TargetedOrdering';
  authoring: {
    // An association list of choice id orderings to matching targeted response ids
    targeted: ChoiceIdsToResponseId[];
  }
};

export interface ModelEditorProps {
  model: OrderingModelSchema;
  editMode: boolean;
}
