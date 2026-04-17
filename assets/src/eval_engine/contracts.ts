export type JsonPrimitive = string | number | boolean | null;

export type JsonValue = JsonPrimitive | JsonValue[] | { [key: string]: JsonValue };

export type Variable = {
  variable: string;
  expression: string;
};

export type EvalVariables = Variable[] | Variable[][];

export type Evaluation = {
  variable: string;
  result: JsonValue | null;
  errored: boolean;
};

export type EvaluationResult = Evaluation[] | Evaluation[][];

export type EvalRequest = {
  vars: EvalVariables;
  count?: number;
};

export type HandlerErrorType = 'validation_error' | 'runtime_error';

export type EvalHandlerError = {
  error: {
    type: HandlerErrorType;
    message: string;
  };
};
