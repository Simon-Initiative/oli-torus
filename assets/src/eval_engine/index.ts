import {
  EvalHandlerError,
  EvalRequest,
  EvalVariables,
  Evaluation,
  EvaluationResult,
  Variable,
} from './contracts';
import { em } from './em';
import { convertStringToNumber, createVmOptions, evaluate, normalizeForJson } from './evaluator';
import * as OLI from './oli';

const DEFAULT_HANDLER_COUNT = 1;
const MAX_HANDLER_COUNT = 1000;

type ValidatedRequest =
  | { ok: true; request: Required<EvalRequest> }
  | { ok: false; error: EvalHandlerError };

type RequestSummary = {
  request_shape: 'single' | 'batch' | 'invalid';
  batch_count: number;
  variable_count: number;
  requested_count?: number;
};

function errorResponse(type: EvalHandlerError['error']['type'], message: string): EvalHandlerError {
  return {
    error: {
      type,
      message,
    },
  };
}

function isVariable(value: unknown): value is Variable {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    return false;
  }

  const candidate = value as Record<string, unknown>;
  return typeof candidate.variable === 'string' && typeof candidate.expression === 'string';
}

function isSingleVariableSet(value: unknown): value is Variable[] {
  return Array.isArray(value) && value.every(isVariable);
}

function isBatchVariableSet(value: unknown): value is Variable[][] {
  return Array.isArray(value) && value.every(isSingleVariableSet);
}

function normalizeCount(rawCount: unknown): number | null {
  if (rawCount === undefined) {
    return DEFAULT_HANDLER_COUNT;
  }

  if (
    typeof rawCount !== 'number' ||
    !Number.isInteger(rawCount) ||
    rawCount < 1 ||
    rawCount > MAX_HANDLER_COUNT
  ) {
    return null;
  }

  return rawCount;
}

function summarizeVariables(vars: EvalVariables): RequestSummary {
  if (isBatchVariableSet(vars)) {
    return {
      request_shape: 'batch',
      batch_count: vars.length,
      variable_count: vars.reduce((total, set) => total + set.length, 0),
    };
  }

  return {
    request_shape: 'single',
    batch_count: 1,
    variable_count: vars.length,
  };
}

function summarizeEvent(event: unknown): RequestSummary {
  if (event === null || typeof event !== 'object' || Array.isArray(event)) {
    return {
      request_shape: 'invalid',
      batch_count: 0,
      variable_count: 0,
    };
  }

  const payload = event as Record<string, unknown>;
  const requestedCount =
    typeof payload.count === 'number' && Number.isInteger(payload.count)
      ? payload.count
      : undefined;

  if (
    'vars' in payload &&
    (isSingleVariableSet(payload.vars) || isBatchVariableSet(payload.vars))
  ) {
    return {
      ...summarizeVariables(payload.vars as EvalVariables),
      requested_count: requestedCount,
    };
  }

  return {
    request_shape: 'invalid',
    batch_count: 0,
    variable_count: 0,
    requested_count: requestedCount,
  };
}

export function validateRequestEvent(event: unknown): ValidatedRequest {
  if (event === null || typeof event !== 'object' || Array.isArray(event)) {
    return {
      ok: false,
      error: errorResponse('validation_error', 'Event payload must be a JSON object.'),
    };
  }

  const payload = event as Record<string, unknown>;
  const count = normalizeCount(payload.count);

  if (count === null) {
    return {
      ok: false,
      error: errorResponse(
        'validation_error',
        `count must be an integer between 1 and ${MAX_HANDLER_COUNT}.`,
      ),
    };
  }

  if (!('vars' in payload)) {
    return {
      ok: false,
      error: errorResponse('validation_error', 'vars is required.'),
    };
  }

  if (!isSingleVariableSet(payload.vars) && !isBatchVariableSet(payload.vars)) {
    return {
      ok: false,
      error: errorResponse(
        'validation_error',
        'vars must be an array of variable objects or an array of variable-object arrays.',
      ),
    };
  }

  return {
    ok: true,
    request: {
      vars: payload.vars as EvalVariables,
      count,
    },
  };
}

function normalizeEvaluation(entry: unknown): Evaluation {
  if (entry === null || typeof entry !== 'object' || Array.isArray(entry)) {
    throw new Error('Evaluator returned a malformed evaluation.');
  }

  const evaluation = entry as Record<string, unknown>;

  if (typeof evaluation.variable !== 'string' || typeof evaluation.errored !== 'boolean') {
    throw new Error('Evaluator returned a malformed evaluation.');
  }

  return {
    variable: evaluation.variable,
    errored: evaluation.errored,
    result: normalizeForJson(evaluation.result),
  };
}

function normalizeEvaluationList(list: unknown): Evaluation[] {
  if (!Array.isArray(list)) {
    throw new Error('Evaluator returned a malformed evaluation list.');
  }

  return list.map((entry) => normalizeEvaluation(entry));
}

export function normalizeHandlerResponse(result: unknown): EvaluationResult {
  if (!Array.isArray(result)) {
    throw new Error('Evaluator returned a non-array response.');
  }

  if (result.length === 0) {
    return [];
  }

  if (Array.isArray(result[0])) {
    if (!(result as unknown[]).every((entry) => Array.isArray(entry))) {
      throw new Error('Evaluator returned a mixed response shape.');
    }

    return (result as unknown[]).map((entry) => normalizeEvaluationList(entry));
  }

  return normalizeEvaluationList(result);
}

function summarizeResult(result: EvaluationResult) {
  if (result.length === 0) {
    return {
      response_shape: 'empty',
      evaluation_count: 0,
    };
  }

  if (Array.isArray(result[0])) {
    return {
      response_shape: 'batch',
      evaluation_count: (result as Evaluation[][]).reduce(
        (total, evaluations) => total + evaluations.length,
        0,
      ),
    };
  }

  return {
    response_shape: 'single',
    evaluation_count: (result as Evaluation[]).length,
  };
}

function logOutcome(
  summary: RequestSummary,
  outcome: 'ok' | 'validation_error' | 'runtime_error',
  durationMs: number,
  extra: Record<string, unknown> = {},
) {
  const payload = {
    outcome,
    duration_ms: durationMs,
    ...summary,
    ...extra,
  };

  if (outcome === 'ok') {
    console.info('[eval-engine] request completed', payload);
    return;
  }

  console.warn('[eval-engine] request completed', payload);
}

export async function handleEvent(
  event: unknown,
  evaluateRequest: (variables: EvalVariables, count: number) => EvaluationResult = evaluate,
): Promise<EvaluationResult | EvalHandlerError> {
  const startedAt = Date.now();
  const eventSummary = summarizeEvent(event);
  const validated = validateRequestEvent(event);

  if (!validated.ok) {
    logOutcome(eventSummary, 'validation_error', Date.now() - startedAt, {
      error_type: validated.error.error.type,
    });

    return validated.error;
  }

  try {
    const result = evaluateRequest(validated.request.vars, validated.request.count);
    const normalized = normalizeHandlerResponse(result);

    logOutcome(
      {
        ...summarizeVariables(validated.request.vars),
        requested_count: validated.request.count,
      },
      'ok',
      Date.now() - startedAt,
      summarizeResult(normalized),
    );

    return normalized;
  } catch (_error) {
    logOutcome(
      {
        ...summarizeVariables(validated.request.vars),
        requested_count: validated.request.count,
      },
      'runtime_error',
      Date.now() - startedAt,
      {
        error_type: 'runtime_error',
      },
    );

    return errorResponse('runtime_error', 'Evaluation request failed.');
  }
}

export async function handler(event: unknown): Promise<EvaluationResult | EvalHandlerError> {
  return handleEvent(event);
}

module.exports = {
  convertStringToNumber,
  createVmOptions,
  em,
  handleEvent,
  handler,
  normalizeForJson,
  normalizeHandlerResponse,
  validateRequestEvent,
  evaluate,
  OLI,
};
