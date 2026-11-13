import { Objective } from 'data/content/objective';
import guid from 'utils/guid';
import { ScoringStrategy, makeStem } from '../types';
import { InteractiveModelSchema } from './schema';

/** Creates an unbuilt Interactive with one placeholder part for Torus attempts. */
export function defaultInteractiveModel(): InteractiveModelSchema {
  return {
    stem: makeStem(''),
    authoring: {
      prompt: '',
      revision_prompt: '',
      revision_prompts: [],
      selectedSkillIds: [],
      model: 'gpt-6-astra',
      reasoning: 'medium',
      previewText: '',
      parts: [
        {
          id: guid(),
          scoringStrategy: ScoringStrategy.average,
          responses: [],
          hints: [],
        },
      ],
    },
  };
}

/**
 * Torus represents skills as sub-objectives rather than a separate objective type.
 * Only direct children of top-level objectives are eligible Interactive targets.
 */
export function interactiveSkills(objectives: Objective[]): Objective[] {
  const rootIds = new Set(
    objectives.filter((objective) => !objective.parentIds?.length).map((objective) => objective.id),
  );
  return objectives.filter((objective) => objective.parentIds?.some((id) => rootIds.has(id)));
}
