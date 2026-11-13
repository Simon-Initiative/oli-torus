import { ActivityModelSchema, Part, Stem } from '../types';

export interface InteractiveModelSchema extends ActivityModelSchema {
  stem: Stem;
  bundle?: { buildId: string; bucket: string; prefix: string; indexUrl: string };
  authoring: {
    prompt: string;
    revision_prompt?: string;
    revision_prompts?: string[];
    selectedSkillIds: number[];
    model?: 'gpt-6-astra' | 'gpt-6-sol';
    reasoning?: 'low' | 'medium' | 'high';
    parts: Part[];
    previewText: string;
  };
}
