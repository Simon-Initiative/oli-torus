import {
  LearningObjectiveConfig,
  LearningObjectivesContent,
  ResolvedLearningObjective,
  ResourceContent,
} from 'data/content/resource';
import { PageEditorContent } from 'data/editor/PageEditorContent';

export type LearningObjectivesReconciliationResult = {
  content: PageEditorContent;
  changed: boolean;
};

type LearningObjectivesContentReconciliationResult = {
  content: LearningObjectivesContent;
  changed: boolean;
};

const defaultConfig = (resourceId: number): LearningObjectiveConfig => ({
  resource_id: resourceId,
  enabled: true,
  revisit_pages: [],
  practice_pages: [],
});

const sameNumberArray = (a: number[], b: number[]) =>
  a.length === b.length && a.every((value, index) => value === b[index]);

const sameConfig = (a: LearningObjectiveConfig, b: LearningObjectiveConfig) =>
  a.resource_id === b.resource_id &&
  a.enabled === b.enabled &&
  sameNumberArray(a.revisit_pages, b.revisit_pages) &&
  sameNumberArray(a.practice_pages, b.practice_pages);

export function reconcileLearningObjectivesContent(
  content: LearningObjectivesContent,
  resolvedObjectives: ResolvedLearningObjective[],
): LearningObjectivesContentReconciliationResult {
  const existingConfigs = new Map(
    content.learning_objectives.map((config) => [config.resource_id, config]),
  );

  const nextConfigs = resolvedObjectives.map(({ resource_id }) => {
    const existing = existingConfigs.get(resource_id);

    return existing
      ? {
          ...existing,
          revisit_pages: [...existing.revisit_pages],
          practice_pages: [...existing.practice_pages],
        }
      : defaultConfig(resource_id);
  });

  const changed =
    content.learning_objectives.length !== nextConfigs.length ||
    content.learning_objectives.some((config, index) => !sameConfig(config, nextConfigs[index]));

  return {
    content: changed ? { ...content, learning_objectives: nextConfigs } : content,
    changed,
  };
}

export function reconcileLearningObjectivesInPageContent(
  content: PageEditorContent,
  resolvedObjectives?: ResolvedLearningObjective[],
): LearningObjectivesReconciliationResult {
  if (
    resolvedObjectives === undefined ||
    !content.flatten().some((item) => item.type === 'learning_objectives')
  ) {
    return { content, changed: false };
  }

  let changed = false;

  // Learning Objectives element membership is refreshed on authoring page load.
  // The stored rows are advisory display config, not the source of truth for
  // which objectives are attached to activities in the current container.
  const reconciled = content.updateAll((item: ResourceContent) => {
    if (item.type !== 'learning_objectives') {
      return item;
    }

    const result = reconcileLearningObjectivesContent(item, resolvedObjectives);
    changed = changed || result.changed;

    return result.content;
  });

  return { content: changed ? reconciled : content, changed };
}
