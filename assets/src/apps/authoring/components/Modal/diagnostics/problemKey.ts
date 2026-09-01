import {
  DiagnosticError,
  DiagnosticProblem,
} from 'apps/authoring/store/groups/layouts/deck/actions/validate';
import { DiagnosticTypes } from './DiagnosticTypes';

const getActivityResourceId = (activity: DiagnosticError['activity']): string => {
  if (activity && typeof activity === 'object' && 'resourceId' in activity) {
    const resourceId = (activity as { resourceId?: string | number }).resourceId;
    return resourceId !== undefined ? String(resourceId) : '';
  }
  return '';
};

export const getProblemKey = (problem: DiagnosticProblem, activityResourceId: string): string => {
  const { type, item } = problem;

  switch (type) {
    case DiagnosticTypes.INVALID_TARGET_COND:
      return `${type}:${activityResourceId}:${item.rule?.id}:${item.condition?.fact}`;
    case DiagnosticTypes.INVALID_TARGET_INIT:
      return `${type}:${activityResourceId}:${item.fact?.target}`;
    case DiagnosticTypes.INVALID_TARGET_MUTATE:
      return `${type}:${activityResourceId}:${item.id}:${item.action?.params?.target}`;
    case DiagnosticTypes.INVALID_VALUE:
    case DiagnosticTypes.INVALID_EXPRESSION_VALUE:
      return `${type}:${activityResourceId}:${item.rule?.id}:${item.condition?.fact}:${item.condition?.value}`;
    case DiagnosticTypes.INVALID_OWNER_INIT:
    case DiagnosticTypes.INVALID_OWNER_CONDITION:
    case DiagnosticTypes.INVALID_OWNER_MUTATE:
      return `${type}:${activityResourceId}:${item.rule?.id ?? item.id}:${
        item.owner?.custom?.sequenceId ?? ''
      }`;
    case DiagnosticTypes.BROKEN:
      return `${type}:${activityResourceId}:${item.id}:${item.action?.params?.target}`;
    case DiagnosticTypes.DUPLICATE:
    case DiagnosticTypes.PATTERN:
    case DiagnosticTypes.INVALID_EXPRESSION:
      return `${type}:${activityResourceId}:${item.id}`;
    case DiagnosticTypes.ACCESSIBILITY:
      return `${type}:${activityResourceId}:${item.id}:${item.issue}`;
    default:
      return `${type}:${activityResourceId}:${item?.id ?? ''}:${item?.issue ?? ''}`;
  }
};

export const problemExistsInErrors = (
  errors: DiagnosticError[],
  problemKey: string,
  activityResourceId: string,
): boolean =>
  errors.some(
    (err) =>
      getActivityResourceId(err.activity) === String(activityResourceId) &&
      err.problems.some((p) => getProblemKey(p, activityResourceId) === problemKey),
  );

export const removeProblemFromErrors = (
  errors: DiagnosticError[],
  problemKey: string,
  activityResourceId: string,
): DiagnosticError[] =>
  errors
    .map((err) => {
      if (getActivityResourceId(err.activity) !== String(activityResourceId)) {
        return err;
      }
      const problems = err.problems.filter(
        (p) => getProblemKey(p, activityResourceId) !== problemKey,
      );
      if (problems.length === 0) {
        return null;
      }
      return { ...err, problems };
    })
    .filter((err): err is NonNullable<typeof err> => err !== null);
