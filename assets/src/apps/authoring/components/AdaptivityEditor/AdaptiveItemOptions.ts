import { CapiVariableTypes } from '../../../../adaptivity/capi';

export interface TypeOption {
  key: string;
  text: string;
  value: number;
}
export const typeOptions: TypeOption[] = [
  { key: 'string', text: 'String', value: CapiVariableTypes.STRING },
  { key: 'number', text: 'Number', value: CapiVariableTypes.NUMBER },
  { key: 'array', text: 'Array', value: CapiVariableTypes.ARRAY },
  { key: 'boolean', text: 'Boolean', value: CapiVariableTypes.BOOLEAN },
  { key: 'enum', text: 'Enum', value: CapiVariableTypes.ENUM },
  { key: 'math', text: 'Math Expression', value: CapiVariableTypes.MATH_EXPR },
  { key: 'parray', text: 'Point Array', value: CapiVariableTypes.ARRAY_POINT },
];

export interface OperatorOption {
  key: string;
  text: string;
  value: string;
}
export const operatorOptions: OperatorOption[] = [
  { key: 'equal', text: '=', value: '=' },
  { key: 'add', text: 'Adding', value: 'adding' },
  { key: 'bind', text: 'Bind To', value: 'bind to' },
  { key: 'set', text: 'Setting To', value: 'setting to' },
];
