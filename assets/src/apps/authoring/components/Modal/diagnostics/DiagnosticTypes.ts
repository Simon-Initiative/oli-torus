export enum DiagnosticTypes {
  DUPLICATE = 'duplicate',
  PATTERN = 'pattern',
  BROKEN = 'broken',
  INCOMPLETE = 'incomplete',
  INVALID_TARGET_MUTATE = 'invalid_target_mutate',
  INVALID_VALUE = 'invalid_value',
  INVALID_TARGET_INIT = 'invalid_target_init',
  INVALID_TARGET_COND = 'invalid_target_cond',
  INVALID_EXPRESSION_VALUE = 'invalid_expression_value',
  DEFAULT = '',
}

export const DiagnosticRuleTypes = [
  DiagnosticTypes.INVALID_TARGET_COND,
  DiagnosticTypes.INVALID_TARGET_INIT,
  DiagnosticTypes.INVALID_TARGET_MUTATE,
  DiagnosticTypes.INVALID_VALUE,
  DiagnosticTypes.INVALID_EXPRESSION_VALUE,
];
