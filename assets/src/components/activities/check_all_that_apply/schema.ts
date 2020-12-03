
import { Part, Transformation, ActivityModelSchema, Stem, ChoiceId, ResponseId, Choice } from '../types';

export type CheckAllThatApplyModelSchema = SimpleCATA | TargetedCATA;

interface BaseCATA extends ActivityModelSchema {
  stem: Stem;
  choices: Choice[];
  authoring: {
    // An association list of correct choice ids to the matching response id
    correct: ChoiceIdsToResponseId;
    // An association list of incorrect choice ids to the matching response id
    incorrect: ChoiceIdsToResponseId;
    parts: Part[];
    transformations: Transformation[];
    previewText: string;
  };
}

export type ChoiceIdsToResponseId = [ChoiceId[], ResponseId];

export type SimpleCATA = BaseCATA & {
  type: 'SimpleCATA';
};

export type TargetedCATA = BaseCATA & {
  type: 'TargetedCATA';
  authoring: {
    // An association list of choice ids to the matching targeted response id
    targeted: ChoiceIdsToResponseId[];
  }
};

export interface ModelEditorProps {
  model: CheckAllThatApplyModelSchema;
  editMode: boolean;
}
