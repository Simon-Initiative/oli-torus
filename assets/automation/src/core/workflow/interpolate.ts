import { WorkflowParams, WorkflowState, WorkflowValue } from '@core/workflow/types';

const PLACEHOLDER_REGEX = /\$\{([^}]+)\}/g;

export function interpolateWorkflowParams<T extends WorkflowValue>(
  value: T,
  state: WorkflowState,
  stepId: string,
): T {
  if (typeof value === 'string') {
    return interpolateString(value, state, stepId) as T;
  }

  if (Array.isArray(value)) {
    return value.map((item) => interpolateWorkflowParams(item, state, stepId)) as T;
  }

  if (value != null && typeof value === 'object') {
    return Object.entries(value).reduce<Record<string, WorkflowValue>>(
      (acc, [key, nestedValue]) => {
        acc[key] = interpolateWorkflowParams(nestedValue as WorkflowValue, state, stepId);
        return acc;
      },
      {},
    ) as T;
  }

  return value;
}

function interpolateString(value: string, state: WorkflowState, stepId: string): WorkflowValue {
  const matches = collectMatches(value);

  if (matches.length === 0) {
    return value;
  }

  if (matches.length === 1 && matches[0][0] === value) {
    return resolveReference(matches[0][1], state, stepId);
  }

  return value.replace(PLACEHOLDER_REGEX, (_match, reference) => {
    const resolved = resolveReference(reference, state, stepId);
    return stringifyResolvedValue(reference, resolved, stepId);
  });
}

function collectMatches(value: string) {
  const matches: RegExpExecArray[] = [];
  const pattern = new RegExp(PLACEHOLDER_REGEX.source, 'g');

  let match = pattern.exec(value);

  while (match) {
    matches.push(match);
    match = pattern.exec(value);
  }

  return matches;
}

function resolveReference(reference: string, state: WorkflowState, stepId: string): WorkflowValue {
  const pathSegments = reference.split('.');

  if (pathSegments.length === 0) {
    throw new Error(`Workflow step "${stepId}" contains an empty interpolation reference`);
  }

  if (pathSegments[0] === 'params') {
    return resolveFromObject(state.params, pathSegments.slice(1), reference, stepId);
  }

  if (pathSegments.length >= 2 && pathSegments[1] === 'outputs') {
    const dependencyStepId = pathSegments[0];
    const dependency = state.steps[dependencyStepId];

    if (!dependency) {
      throw new Error(
        `Workflow step "${stepId}" references outputs from missing step "${dependencyStepId}"`,
      );
    }

    return resolveFromObject(dependency.outputs, pathSegments.slice(2), reference, stepId);
  }

  return resolveFromObject(state.params, pathSegments, reference, stepId);
}

function resolveFromObject(
  source: WorkflowParams,
  pathSegments: string[],
  reference: string,
  stepId: string,
): WorkflowValue {
  let current: unknown = source;

  for (const segment of pathSegments) {
    if (
      current == null ||
      typeof current !== 'object' ||
      !(segment in (current as Record<string, unknown>))
    ) {
      throw new Error(
        `Workflow step "${stepId}" could not resolve interpolation reference "${reference}"`,
      );
    }

    current = (current as Record<string, unknown>)[segment];
  }

  return current as WorkflowValue;
}

function stringifyResolvedValue(reference: string, value: WorkflowValue, stepId: string) {
  if (value == null) {
    return '';
  }

  if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') {
    return String(value);
  }

  throw new Error(
    `Workflow step "${stepId}" resolved "${reference}" to a non-scalar value that cannot be embedded in a string`,
  );
}
