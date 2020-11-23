
import { HasContent, Part, Transformation, ActivityModelSchema, Stem, ChoiceId, ResponseId } from '../types';
import { ID, Identifiable } from 'data/content/model';

export interface Choice extends Identifiable, HasContent {}

export type CATACombination = Identifiable[];
export type CATACombinations = CATACombination[];

export type CheckAllThatApplyModelSchema = SimpleCATA | TargetedCATA

interface BaseCATA {
  stem: Stem;
  choices: Choice[];
  authoring: {
    correct: ChoiceIdsToResponseId;
    incorrect: ChoiceIdsToResponseId;
    parts: Part[];
    transformations: Transformation[];
    previewText: string;
  }
}

export type ChoiceIdsToResponseId = [ChoiceId[], ResponseId]

export type SimpleCATA = BaseCATA & {
  type: 'SimpleCATA';
}

export type TargetedCATA = BaseCATA & {
  type: 'TargetedCATA';
  authoring: {
    targeted: ChoiceIdsToResponseId[];
  }
}

export interface ModelEditorProps {
  model: CheckAllThatApplyModelSchema;
  editMode: boolean;
}
