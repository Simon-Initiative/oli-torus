import { IMutateAction } from '../../../../delivery/store/features/activities/slice';

export const variableIdentifier = (name: string) => `variables.${name}`;

export const createIncrementStateAction = (variableName: string, amount = 1): IMutateAction => ({
  type: 'mutateState',
  params: {
    value: String(amount),
    target: variableIdentifier(variableName),
    operator: 'adding',
    targetType: 1,
  },
});

export const createSetStateAction = (variableName: string, expression: string): IMutateAction => ({
  type: 'mutateState',
  params: {
    value: expression,
    target: variableIdentifier(variableName),
    operator: 'setting to',
    targetType: 1,
  },
});
