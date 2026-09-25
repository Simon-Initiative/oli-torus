import type { Objective } from 'data/content/objective';

export type AttachmentType = 'page' | 'activity';
export type ObjectiveOption = Objective & { disabled?: boolean };

export const objectivesForAttachment = (
  objectives: Objective[],
  attachmentType?: AttachmentType,
  loWellFormed?: boolean,
): ObjectiveOption[] => {
  if (!loWellFormed) return objectives;

  switch (attachmentType) {
    case 'page':
      return objectives.filter(
        (objective) => objective.objectiveType !== 'sub_objective' && !objective.parentIds?.length,
      );
    case 'activity':
      return objectives.map((objective) => ({
        ...objective,
        disabled: !objective.parentIds?.length,
      }));
    default:
      return objectives;
  }
};

export const canCreateObjective = (
  onRegisterNewObjective?: (objective: Objective) => void,
  attachmentType?: AttachmentType,
  loWellFormed?: boolean,
) => !!onRegisterNewObjective && !(loWellFormed === true && attachmentType === 'activity');

export const isSearchOnly = (attachmentType?: AttachmentType, loWellFormed?: boolean) =>
  loWellFormed === true && attachmentType === 'activity';

export const getPlaceholderLabel = (editMode: boolean, searchOnly: boolean) => {
  if (editMode && searchOnly) return 'Select sub-objectives...';

  if (editMode) return 'Select or create learning objectives...';

  return 'Select a learning objective';
};
