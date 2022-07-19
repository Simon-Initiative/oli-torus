import { makeRequest } from './common';

export type VariableScript = {
  expression: string;
  variable: string;
};

export type Variable = {
  variable: string;
  expression: string;
  id: string;
};

export type VariableEvaluation = {
  variable: string;
  result: string | number | null;
  errored: boolean;
};

export interface VariableEvaluationResult {
  result: 'success';
  evaluations: VariableEvaluation[];
}

export function evaluateVariables(data: VariableScript[], count = 1) {
  const params = {
    method: 'POST',
    body: JSON.stringify({ data, count }),
    url: `/variables`,
  };

  return makeRequest<VariableEvaluationResult>(params);
}
