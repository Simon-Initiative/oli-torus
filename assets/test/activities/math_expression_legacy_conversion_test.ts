import { MultiInputActions } from 'components/activities/multi_input/actions';
import { defaultModel as defaultMultiInputModel } from 'components/activities/multi_input/utils';
import { ShortAnswerActions } from 'components/activities/short_answer/actions';
import { defaultModel as defaultShortAnswerModel } from 'components/activities/short_answer/utils';
import {
  convertMultiInputLegacyMathOnSave,
  convertShortAnswerLegacyMathOnSave,
  legacyMathRuleToMatchConfig,
  legacyNumericRuleToMatchConfig,
} from 'data/activities/model/match_conversion';
import {
  containsRule,
  eqRule,
  equalsRule,
  gtRule,
  gteRule,
  ltRule,
  lteRule,
  matchRule,
  neqRule,
  notRangeRule,
  rangeRule,
} from 'data/activities/model/rules';
import { dispatch } from 'utils/test_utils';

const math = (config: ReturnType<typeof legacyNumericRuleToMatchConfig>) => {
  if (config?.type !== 'math_expression') return undefined;
  return config.math;
};

describe('legacy math expression authoring conversion', () => {
  it('converts numeric equality and significant figures to numeric matchConfig', () => {
    const config = legacyNumericRuleToMatchConfig(eqRule('3.20', 3));

    expect(config).toEqual({
      version: 1,
      type: 'math_expression',
      math: {
        mode: 'numeric',
        operator: 'equal',
        expected: '3.20',
        precision: { type: 'significant_figures', count: 3 },
      },
    });
  });

  it('converts numeric inequalities to numeric matchConfig', () => {
    expect(math(legacyNumericRuleToMatchConfig(gtRule(2)))).toMatchObject({
      mode: 'numeric',
      operator: 'greater_than',
      threshold: '2',
    });
    expect(math(legacyNumericRuleToMatchConfig(gteRule(2)))).toMatchObject({
      mode: 'numeric',
      operator: 'greater_than_or_equal',
      threshold: '2',
    });
    expect(math(legacyNumericRuleToMatchConfig(ltRule(2)))).toMatchObject({
      mode: 'numeric',
      operator: 'less_than',
      threshold: '2',
    });
    expect(math(legacyNumericRuleToMatchConfig(lteRule(2)))).toMatchObject({
      mode: 'numeric',
      operator: 'less_than_or_equal',
      threshold: '2',
    });
    expect(math(legacyNumericRuleToMatchConfig(neqRule(2)))).toMatchObject({
      mode: 'numeric',
      operator: 'not_equal',
      expected: '2',
    });
  });

  it('converts numeric range and not-range rules to numeric matchConfig', () => {
    expect(math(legacyNumericRuleToMatchConfig(rangeRule(1, 3, true)))).toMatchObject({
      mode: 'numeric',
      operator: 'between',
      lower: '1',
      upper: '3',
      bounds: 'inclusive',
    });
    expect(math(legacyNumericRuleToMatchConfig(notRangeRule(1, 3, false, 2)))).toMatchObject({
      mode: 'numeric',
      operator: 'not_between',
      lower: '1',
      upper: '3',
      bounds: 'exclusive',
      precision: { type: 'significant_figures', count: 2 },
    });
  });

  it('converts legacy Math equality with escaped LaTeX to direct LaTeX matchConfig', () => {
    const expected = String.raw`\frac{1}{2}`;

    expect(legacyMathRuleToMatchConfig(equalsRule(expected))).toEqual({
      version: 1,
      type: 'math_expression',
      math: {
        mode: 'latex_direct',
        expected,
      },
    });
  });

  it('converts saved Short Answer numeric models to math_expression with empty fallback rules', () => {
    const legacy = dispatch(
      defaultShortAnswerModel(),
      ShortAnswerActions.setInputType('numeric', '1'),
    );
    const converted = convertShortAnswerLegacyMathOnSave(legacy);
    const responses = converted.authoring.parts[0].responses;

    expect(converted.inputType).toBe('math_expression');
    expect(responses[0].matchConfig?.type).toBe('math_expression');
    expect(responses[1].matchConfig).toEqual({ version: 1, type: 'always' });
    expect(responses[0].rule).toBe('');
    expect(responses[1].rule).toBe('');
  });

  it('converts saved Short Answer math models to math_expression with empty fallback rules', () => {
    const legacy = dispatch(
      defaultShortAnswerModel(),
      ShortAnswerActions.setInputType('math', '1'),
    );
    const converted = convertShortAnswerLegacyMathOnSave(legacy);
    const responses = converted.authoring.parts[0].responses;

    expect(converted.inputType).toBe('math_expression');
    expect(responses[0].matchConfig).toMatchObject({
      type: 'math_expression',
      math: { mode: 'latex_direct' },
    });
    expect(responses[1].matchConfig).toEqual({ version: 1, type: 'always' });
    expect(responses[0].rule).toBe('');
    expect(responses[1].rule).toBe('');
  });

  it('converts saved Multi Input numeric parts to math_expression with empty fallback rules', () => {
    let model = defaultMultiInputModel();
    const inputId = model.inputs[0].id;
    model = dispatch(model, MultiInputActions.setInputType(inputId, 'numeric'));

    const converted = JSON.parse(JSON.stringify(convertMultiInputLegacyMathOnSave(model)));
    const responses = converted.authoring.parts[0].responses;

    expect(converted.inputs[0].inputType).toBe('math_expression');
    expect(responses[0].matchConfig?.type).toBe('math_expression');
    expect(responses[1].matchConfig).toEqual({ version: 1, type: 'always' });
    expect(responses[0].rule).toBe('');
    expect(responses[1].rule).toBe('');
  });

  it('converts saved Multi Input math parts to math_expression with empty fallback rules', () => {
    let model = defaultMultiInputModel();
    const inputId = model.inputs[0].id;
    model = dispatch(model, MultiInputActions.setInputType(inputId, 'math'));

    const converted = JSON.parse(JSON.stringify(convertMultiInputLegacyMathOnSave(model)));
    const responses = converted.authoring.parts[0].responses;

    expect(converted.inputs[0].inputType).toBe('math_expression');
    expect(responses[0].matchConfig).toMatchObject({
      type: 'math_expression',
      math: { mode: 'latex_direct' },
    });
    expect(responses[1].matchConfig).toEqual({ version: 1, type: 'always' });
    expect(responses[0].rule).toBe('');
    expect(responses[1].rule).toBe('');
  });

  it('leaves text and dropdown rules rule-backed during conversion', () => {
    const shortAnswer = convertShortAnswerLegacyMathOnSave(defaultShortAnswerModel());
    const multiInput = convertMultiInputLegacyMathOnSave(defaultMultiInputModel());
    let dropdown = defaultMultiInputModel();
    dropdown = dispatch(
      dropdown,
      MultiInputActions.setInputType(dropdown.inputs[0].id, 'dropdown'),
    );
    dropdown = convertMultiInputLegacyMathOnSave(dropdown);

    const textResponse = shortAnswer.authoring.parts[0].responses[0];
    const multiTextResponse = multiInput.authoring.parts[0].responses[0];
    const dropdownResponse = dropdown.authoring.parts[0].responses[0];

    expect(shortAnswer.inputType).toBe('text');
    expect(textResponse.rule).toBe(containsRule('answer'));
    expect(textResponse).not.toHaveProperty('matchConfig');
    expect(multiInput.inputs[0].inputType).toBe('text');
    expect(multiTextResponse.rule).toBe(containsRule('answer'));
    expect(multiTextResponse).not.toHaveProperty('matchConfig');
    expect(dropdown.inputs[0].inputType).toBe('dropdown');
    expect(dropdownResponse.rule).toBe(matchRule(dropdown.choices[0].id));
    expect(dropdownResponse).not.toHaveProperty('matchConfig');
  });
});
