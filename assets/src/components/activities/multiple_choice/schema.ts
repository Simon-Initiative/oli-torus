
import { ActivityModelSchema } from '../types';

export interface MultipleChoiceModelSchema extends ActivityModelSchema {
  stem: string;
  choices: string[];
  feedback: string[];
}

