import { ActivityUpdate } from '../../../../../data/persistence/activity';

/**
 * In the backend data model, objectives are attached to parts.
 * But in adaptive lessons, we want to attach them to an activity, so
 * we're going to "cheat" and attach them to the first part in the activity.
 * However there's a few use cases we need to handle:
 *
 * 1. If there are no parts, a __default part is created, so attach it to that.
 * 2. If the part that objectives are attached to is deleted, we should move the objectives
 *    to another part.
 * 3. If there were no parts, and objectives were attached, and later a part is added, that
 *    default part is deleted, so move the objectives to the newly created part.
 *
 * All three of these use cases can be handled with some logic of "if objectives are
 * attached to a missing part, move them to the first part" as long as we do that after
 * the __default part is added/removed. This function does just that.
 *
 */

export const fixObjectiveParts = (activity: ActivityUpdate): ActivityUpdate => {
  if (!activity.objectives) {
    console.info('fixObjectiveParts - No activity.objectives');
    return activity;
  }
  const keyCount = Object.keys(activity.objectives).length;

  if (keyCount === 0) {
    console.info('fixObjectiveParts - No objectives');
    // No objectives to worry about
    return activity;
  }

  const parts = activity.content?.authoring?.parts;
  if (!Array.isArray(parts)) {
    console.info('fixObjectiveParts - Parts not an array');
    return activity;
  }

  if (parts.length === 0) {
    // This really should never happen since the __default part would be generated beforehand
    console.error('fixObjectiveParts - No parts were present in the activity');
    return activity;
  }

  const targetKey =
    Object.values(parts)
      .map((p: { id: string }) => p.id)
      .filter((k) => k !== '__default')[0] || '__default';

  const allObjectives = Object.values(activity.objectives).flat();

  if (keyCount > 1) {
    // Somehow, we got more than 1 objective assignment, consolidate them onto the first non-default part
    console.warn(
      'fixObjectiveParts - Multiple parts had objectives assigned to them, consolidating.',
    );

    return {
      ...activity,
      objectives: {
        [targetKey]: allObjectives,
      },
    };
  }

  // At this point, we handled keyCount=0 and >1 so we have exactly 1 part key in objectives

  return {
    ...activity,
    objectives: {
      [targetKey]: allObjectives,
    },
  };
};
