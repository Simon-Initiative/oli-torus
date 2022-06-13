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
  INVALID_EXPRESSION = 'invalid_expression',
  INVALID_OWNER_INIT = 'invalid_owner_init',
  INVALID_OWNER_CONDITION = 'invalid_owner_condition',
  INVALID_OWNER_MUTATE = 'invalid_owner_mutate',
  DEFAULT = '',
}

export const DiagnosticRuleTypes = [
  DiagnosticTypes.INVALID_TARGET_COND,
  DiagnosticTypes.INVALID_TARGET_INIT,
  DiagnosticTypes.INVALID_TARGET_MUTATE,
  DiagnosticTypes.INVALID_VALUE,
  DiagnosticTypes.INVALID_EXPRESSION_VALUE,
  DiagnosticTypes.INVALID_EXPRESSION,
  DiagnosticTypes.INVALID_OWNER_INIT,
  DiagnosticTypes.INVALID_OWNER_CONDITION,
  DiagnosticTypes.INVALID_OWNER_MUTATE,
];
