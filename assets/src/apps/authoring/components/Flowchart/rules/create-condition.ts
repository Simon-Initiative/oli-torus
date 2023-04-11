import guid from '../../../../../utils/guid';
import { OperatorOptions } from '../../AdaptivityEditor/AdaptiveItemOptions';

// ex:
//   fact: 'stage.dropdown-id.selectedIndex',
//   type: 1,
//   value: '0',
//   operator: 'equal',
export const createCondition = (
  fact: string,
  valueExpression: string,
  operator: OperatorOptions,
  type = 1,
) => ({
  id: `c:${guid()}`,
  fact: fact,
  type,
  value: valueExpression,
  operator,
});
