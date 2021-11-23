import { CapiVariableTypes, getCapiType } from '../../../../adaptivity/capi';

export interface TypeOption {
  key: 'string' | 'number' | 'array' | 'boolean' | 'enum' | 'math' | 'parray';
  text: string;
  value: CapiVariableTypes;
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

export interface ActionOperatorOption {
  key: 'equal' | 'add' | 'bind' | 'set';
  text: string;
  value: string;
}
export const actionOperatorOptions: ActionOperatorOption[] = [
  { key: 'equal', text: '=', value: '=' },
  { key: 'add', text: 'Adding', value: 'adding' },
  { key: 'bind', text: 'Bind To', value: 'bind to' },
  { key: 'set', text: 'Setting To', value: 'setting to' },
];

export interface ConditionOperatorOption {
  key: string;
  text: string;
  value: string;
}
export const conditionOperatorOptions: ConditionOperatorOption[] = [
  { key: 'equal', text: '=', value: 'equal' },
  { key: 'notEqual', text: '!=', value: 'notEqual' },
  { key: 'lessThan', text: '<', value: 'lessThan' },
  { key: 'lessThanInclusive', text: '<=', value: 'lessThanInclusive' },
  { key: 'greaterThan', text: '>', value: 'greaterThan' },
  { key: 'greaterThanInclusive', text: '>=', value: 'greaterThanInclusive' },
  { key: 'in', text: 'In', value: 'in' },
  { key: 'notIn', text: 'Not In', value: 'notIn' },
  { key: 'contains', text: 'Contains', value: 'contains' },
  { key: 'notContains', text: 'Not Contains', value: 'notContains' },
  { key: 'containsAnyOf', text: 'Contains Any', value: 'containsAnyOf' },
  {
    key: 'notContainsAnyOf',
    text: 'Not Contains Any',
    value: 'notContainsAnyOf',
  },
  { key: 'containsOnly', text: 'Contains Only', value: 'containsOnly' },
  { key: 'isAnyOf', text: 'Is Any Of', value: 'isAnyOf' },
  { key: 'notIsAnyOf', text: 'Not Any Of', value: 'notIsAnyOf' },
  { key: 'isNaN', text: 'Is NaN', value: 'isNaN' },
  { key: 'equalWithTolerance', text: '~==', value: 'equalWithTolerance' },
  {
    key: 'notEqualWithTolerance',
    text: '~!=',
    value: 'notEqualWithTolerance',
  },
  { key: 'inRange', text: 'In Range', value: 'inRange' },
  { key: 'notInRange', text: 'Not In Range', value: 'notInRange' },
  {
    key: 'containsExactly',
    text: 'Contains Exactly',
    value: 'containsExactly',
  },
  {
    key: 'notContainsExactly',
    text: 'Not Contains Exactly',
    value: 'notContainsExactly',
  },
  { key: 'startsWith', text: 'Starts With', value: 'startsWith' },
  { key: 'endsWith', text: 'Ends With', value: 'endsWith' },
  { key: 'is', text: 'Is', value: 'is' },
  { key: 'notIs', text: 'Not Is', value: 'notIs' },
  { key: 'hasSameTerms', text: 'Has Same Terms', value: 'hasSameTerms' },
  { key: 'hasDifferentTerms', text: 'Has Different Terms', value: 'hasDifferentTerms' },
  { key: 'isEquivalentOf', text: 'Is Equivalent', value: 'isEquivalentOf' },
  { key: 'notIsEquivalentOf', text: 'Is Not Equivalent', value: 'notIsEquivalentOf' },
  { key: 'isExactly', text: 'Is Exactly', value: 'isExactly' },
  { key: 'notIsExactly', text: 'Not Is Exactly', value: 'notIsExactly' },
];

export interface ConditionTypeOperatorCombo {
  type: CapiVariableTypes;
  operators: string[];
}
export const conditionTypeOperatorCombos: ConditionTypeOperatorCombo[] = [
  { type: CapiVariableTypes.BOOLEAN, operators: ['equal', 'is'] },
  {
    type: CapiVariableTypes.ENUM,
    operators: [
      'equal',
      'notEqual',
      'is',
      'notIs',
      // these are not supported by the rules engine anyway, we don't have all the values typically for an enum
      /* 'greaterThan',
      'lessThan',
      'greaterThanInclusive',
      'lessThanInclusive',
      'inRange',
      'notInRange', */
    ],
  },
  {
    type: CapiVariableTypes.NUMBER,
    operators: [
      'equal',
      'notEqual',
      'isNaN',
      'is',
      'isAnyOf',
      'notIs',
      'greaterThan',
      'lessThan',
      'greaterThanInclusive',
      'lessThanInclusive',
      'equalWithTolerance',
      'notEqualWithTolerance',
      'inRange',
      'notInRange',
    ],
  },
  {
    type: CapiVariableTypes.STRING,
    operators: [
      'equal',
      'notEqual',
      'is',
      'notIs',
      'isExactly',
      'notIsExactly',
      'contains',
      'notContains',
      'containsExactly',
      'notContainsExactly',
      'containsAnyOf',
      'notContainsAnyOf',
      'startsWith',
      'endsWith',
    ],
  },
  {
    type: CapiVariableTypes.ARRAY,
    operators: [
      'equal',
      'notEqual',
      'is',
      'notIs',
      'contains',
      'notContains',
      'containsAnyOf',
      'notContainsAnyOf',
      'containsOnly',
    ],
  },
  {
    type: CapiVariableTypes.MATH_EXPR,
    operators: [
      'isExactly',
      'notIsExactly',
      'isEquivalentOf',
      'notIsEquivalentOf',
      'hasSameTerms',
      'hasDifferentTerms',
    ],
  },
  {
    type: CapiVariableTypes.ARRAY_POINT,
    operators: ['equal', 'notEqual', 'is', 'notIs', 'contains', 'notContains'],
  },
];

export const sessionVariables: Record<string, unknown> = {
  attemptNumber: 0,
  currentQuestionScore: 0,
  graded: false,
  questionTimeExceeded: false,
  timeOnQuestion: 0,
  timeStartQuestion: 0,
  tutorialScore: 0,
  visits: [],
};

export const inferTypeFromOperatorAndValue = (operator: string, value: any): CapiVariableTypes => {
  const typeCombos = conditionTypeOperatorCombos.filter((combo) =>
    combo.operators.includes(operator),
  );
  // if there is only one type of value that supports this operator, then use that type (i.e. isNaN)
  if (typeCombos.length === 1) {
    return typeCombos[0].type;
  } else {
    // if there are multiple types of value that support this operator, then best guess based on the value type
    const valueType = getCapiType(value);
    // make sure that the value type is supported by the operator
    // this might still be wrong, but at least it won't kill the operator
    const supportedTypes = typeCombos.map((combo) => combo.type);
    if (!supportedTypes.includes(valueType)) {
      // in this case then ignore the value type and use the first type combo
      return typeCombos[0].type;
    }
    // TODO: figure out how to tell that a STRING is an ENUM or a MATH_EXPR
    // ALSO: strings can contain variables which can be other types, in that case we're hosed...
    return valueType;
  }
};
