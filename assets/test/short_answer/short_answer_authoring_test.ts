import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { ShortAnswerActions } from 'components/activities/short_answer/actions';
import { supportedUnitOptions } from 'components/activities/short_answer/sections/supportedUnitOptions';
import {
  defaultModel,
  shortAnswerInputTypeFromQuestionType,
  shortAnswerMathExpressionConfig,
  shortAnswerOptions,
  shortAnswerQuestionType,
} from 'components/activities/short_answer/utils';
import { makeResponse } from 'components/activities/types';
import { MatchConfigs } from 'data/activities/model/match';
import { makeMatchConfigResponse } from 'data/activities/model/responses';
import { containsRule } from 'data/activities/model/rules';
import { dispatch } from 'utils/test_utils';
import { eqRule } from '../../src/data/activities/model/rules';

const DEFAULT_PART_ID = '1';
describe('short answer question', () => {
  const model = defaultModel();

  it('has a stem', () => {
    expect(model).toHaveProperty('stem');
  });

  it('has input type', () => {
    expect(model).toHaveProperty('inputType');
  });

  it('presents expanded math expression question types without changing the stored input type contract', () => {
    expect(shortAnswerOptions).toEqual([
      { value: 'numeric', displayValue: 'Numeric' },
      { value: 'algebraic', displayValue: 'Algebraic expression' },
      { value: 'number_with_units', displayValue: 'Number with units' },
      { value: 'expression_with_units', displayValue: 'Expression with units' },
      { value: 'integer', displayValue: 'Integer' },
      { value: 'decimal', displayValue: 'Decimal' },
      { value: 'fraction', displayValue: 'Fraction' },
      { value: 'simplified_fraction', displayValue: 'Simplified fraction' },
      { value: 'latex_direct', displayValue: 'LaTeX Math expression' },
      { value: 'text', displayValue: 'Short Text' },
      { value: 'textarea', displayValue: 'Paragraph' },
    ]);
    expect(shortAnswerInputTypeFromQuestionType('algebraic')).toBe('math_expression');
    expect(shortAnswerInputTypeFromQuestionType('text')).toBe('text');
    expect(shortAnswerQuestionType({ ...model, inputType: 'numeric' })).toBe('numeric');
    expect(shortAnswerQuestionType({ ...model, inputType: 'math' })).toBe('latex_direct');
  });

  it('has at least 3 hints', () => {
    expect(model.authoring.parts[0].hints.length).toBeGreaterThanOrEqual(3);
  });

  it('can add and remove a response in text mode', () => {
    const updated = dispatch(
      model,
      ResponseActions.addResponse(
        makeResponse(containsRule('another answer'), 0, ''),
        DEFAULT_PART_ID,
      ),
    );
    expect(updated.authoring.parts[0].responses[0].score).toBe(1);
    expect(updated.authoring.parts[0].responses[1].score).toBe(0);
    expect(updated.authoring.parts[0].responses[2].score).toBe(0);
    expect(updated.authoring.parts[0].responses[0].rule).toBe('input contains {answer}');
    expect(updated.authoring.parts[0].responses[1].rule).toBe('input contains {another answer}');
    expect(updated.authoring.parts[0].responses[2].rule).toBe('input like {.*}');

    expect(
      dispatch(updated, ResponseActions.removeResponse(updated.authoring.parts[0].responses[1].id))
        .authoring.parts[0].responses,
    ).toHaveLength(2);
  });

  it('can add and remove a response in numeric mode', () => {
    let updated = dispatch(model, ShortAnswerActions.setInputType('numeric', DEFAULT_PART_ID));

    updated = dispatch(
      updated,
      ResponseActions.addResponse(makeResponse(eqRule(1), 0, ''), DEFAULT_PART_ID),
    );
    expect(updated.authoring.parts[0].responses[0].score).toBe(1);
    expect(updated.authoring.parts[0].responses[1].score).toBe(0);
    expect(updated.authoring.parts[0].responses[2].score).toBe(0);
    expect(updated.authoring.parts[0].responses[0].rule).toBe('input = {1}');
    expect(updated.authoring.parts[0].responses[1].rule).toBe('input = {1}');
    expect(updated.authoring.parts[0].responses[2].rule).toBe('input like {.*}');

    expect(
      dispatch(updated, ResponseActions.removeResponse(updated.authoring.parts[0].responses[1].id))
        .authoring.parts[0].responses,
    ).toHaveLength(2);
  });

  it('removes stale matchConfig when a response is edited back to a rule', () => {
    const response = makeMatchConfigResponse(MatchConfigs.algebraicEquivalence('x + 1'), 1);
    const mathExpressionModel = JSON.parse(
      JSON.stringify(dispatch(model, ShortAnswerActions.setInputType('math_expression', '1'))),
    );
    mathExpressionModel.authoring.parts[0].responses[0] = response;

    const updated = dispatch(mathExpressionModel, ResponseActions.editRule(response.id, eqRule(1)));

    expect(updated.authoring.parts[0].responses[0].rule).toBe('input = {1}');
    expect(updated.authoring.parts[0].responses[0]).not.toHaveProperty('matchConfig');
  });

  it('sets exact form choices at the question level and uses plain math expression match configs', () => {
    const updated = dispatch(
      model,
      ShortAnswerActions.setQuestionType('simplified_fraction', DEFAULT_PART_ID),
    );
    const correct = updated.authoring.parts[0].responses[0].matchConfig;

    expect(updated.inputType).toBe('math_expression');
    expect(updated.itemConfig?.subtype).toBe('simplified_fraction');
    expect(correct?.type === 'math_expression' && correct.math).toEqual({
      mode: 'algebraic_equivalence',
      expected: '',
      form: { type: 'simplified_fraction' },
    });
  });

  it('stores algebraic variable sampling settings once at the question level', () => {
    let updated = dispatch(model, ShortAnswerActions.setQuestionType('algebraic', DEFAULT_PART_ID));

    updated = dispatch(
      updated,
      ShortAnswerActions.setMathExpressionConfig(
        'algebraic',
        {
          validation: {
            allowedVariables: ['x'],
            domains: [
              {
                name: 'x',
                lower: { value: -2, inclusive: true },
                upper: { value: 5, inclusive: false },
                exclusions: [0],
                integerOnly: true,
                preferredValues: [1, 2],
              },
            ],
          },
        },
        DEFAULT_PART_ID,
      ),
    );

    const correct = updated.authoring.parts[0].responses[0].matchConfig;

    expect(updated.itemConfig?.config?.validation?.domains?.[0].upper.inclusive).toBe(false);
    expect(correct?.type === 'math_expression' && correct.math).toMatchObject({
      mode: 'algebraic_equivalence',
    });
    expect(correct?.type === 'math_expression' && correct.math).not.toHaveProperty('validation');
  });

  it('infers shared unit settings from existing response match configs', () => {
    const mathExpressionModel = dispatch(
      model,
      ShortAnswerActions.setQuestionType('expression_with_units', DEFAULT_PART_ID),
    );

    const response = makeMatchConfigResponse(
      MatchConfigs.unitAware('10 m/s', {
        type: 'accepted_units',
        units: ['m/s', 'km/hr'],
      }),
      1,
    );
    const restored = JSON.parse(JSON.stringify(mathExpressionModel));
    delete restored.itemConfig;
    restored.authoring.parts[0].responses[0] = response;

    expect(shortAnswerQuestionType(restored)).toBe('expression_with_units');
    expect(shortAnswerMathExpressionConfig(restored)?.unitPolicy).toEqual({
      type: 'accepted_units',
      units: ['m/s', 'km/hr'],
    });
  });

  it('preserves wrong-unit targeted response matching when shared unit settings change', () => {
    let updated = dispatch(
      model,
      ShortAnswerActions.setQuestionType('number_with_units', DEFAULT_PART_ID),
    );

    updated = dispatch(
      updated,
      ResponseActions.addResponse(
        makeMatchConfigResponse(
          MatchConfigs.unitAware(
            '10 m/s',
            {
              type: 'convertible_units',
              units: ['m/s'],
            },
            { matchWrongUnits: true },
          ),
          0,
        ),
        DEFAULT_PART_ID,
      ),
    );

    updated = dispatch(
      updated,
      ShortAnswerActions.setMathExpressionConfig(
        'number_with_units',
        {
          unitPolicy: {
            type: 'convertible_units',
            units: ['m/s', 'cm/s'],
          },
        },
        DEFAULT_PART_ID,
      ),
    );

    const correct = updated.authoring.parts[0].responses[0].matchConfig;
    const targeted = updated.authoring.parts[0].responses[1].matchConfig;

    expect(correct?.type === 'math_expression' && correct.math).not.toHaveProperty(
      'matchWrongUnits',
    );
    expect(targeted?.type === 'math_expression' && targeted.math).toMatchObject({
      mode: 'unit_aware',
      matchWrongUnits: true,
    });
  });

  it('offers supported unit atoms and compound presets for unit authoring', () => {
    const values = supportedUnitOptions.map((option) => option.value);

    expect(values).toContain('m/s^2');
    expect(values).toContain('mol/L');
    expect(values).toContain('L*atm');
    expect(values).toContain('angstrom');
    expect(values).toContain('mph');
    expect(values.filter((value) => value === 'N')).toHaveLength(1);
  });
});
