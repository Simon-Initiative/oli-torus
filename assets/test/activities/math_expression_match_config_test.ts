import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { MultiInputSchema } from 'components/activities/multi_input/schema';
import { multiInputStem } from 'components/activities/multi_input/utils';
import { ShortAnswerActions } from 'components/activities/short_answer/actions';
import { ShortAnswerModelSchema, isInputType } from 'components/activities/short_answer/schema';
import { defaultModel } from 'components/activities/short_answer/utils';
import {
  ScoringStrategy,
  Transform,
  makeHint,
  makePart,
  makeStem,
  makeTransformation,
} from 'components/activities/types';
import { MatchConfigs } from 'data/activities/model/match';
import { Responses, makeMatchConfigResponse } from 'data/activities/model/responses';
import { Model } from 'data/content/model/elements/factories';
import { dispatch } from 'utils/test_utils';

describe('math expression matchConfig model support', () => {
  it('accepts math_expression as a Short Answer input type', () => {
    const model: ShortAnswerModelSchema = {
      stem: makeStem('Simplify 1/2'),
      inputType: 'math_expression',
      authoring: {
        parts: [
          {
            id: '1',
            scoringStrategy: ScoringStrategy.average,
            responses: Responses.forMathExpression('1/2'),
            hints: [makeHint(''), makeHint(''), makeHint('')],
          },
        ],
        transformations: [],
        previewText: '',
      },
    };

    expect(isInputType('math_expression')).toBe(true);
    expect(model.inputType).toBe('math_expression');
  });

  it('accepts math_expression as a Multi Input input type', () => {
    const input = Model.inputRef();

    const model: MultiInputSchema = {
      stem: multiInputStem(input),
      choices: [],
      submitPerPart: false,
      inputs: [{ inputType: 'math_expression', id: input.id, partId: '1' }],
      authoring: {
        parts: [makePart(Responses.forMathExpression('10 m/s'), [makeHint('')], '1')],
        targeted: [],
        transformations: [makeTransformation('choices', Transform.shuffle, true)],
        previewText: 'Enter a speed',
      },
    };

    expect(model.inputs[0].inputType).toBe('math_expression');
    expect(model.authoring.parts[0].responses[0].matchConfig?.type).toBe('math_expression');
  });

  it('creates matchConfig responses with an empty fallback rule', () => {
    const correct = makeMatchConfigResponse(
      MatchConfigs.algebraicEquivalence('1/2', {
        form: { type: 'simplified_fraction' },
      }),
      1,
      'Correct',
      true,
    );
    const catchAll = Responses.matchConfigCatchAll('Incorrect');

    expect(correct).toHaveProperty('matchConfig');
    expect(correct.rule).toBe('');
    expect(catchAll.matchConfig).toEqual({ version: 1, type: 'always' });
    expect(catchAll.rule).toBe('');
  });

  it('switches Short Answer authoring responses to matchConfig with empty fallback rules', () => {
    const model = dispatch(defaultModel(), ShortAnswerActions.setInputType('math_expression', '1'));
    const responses = model.authoring.parts[0].responses;

    expect(model.inputType).toBe('math_expression');
    expect(responses[0].matchConfig?.type).toBe('math_expression');
    expect(responses[1].matchConfig).toEqual({ version: 1, type: 'always' });
    expect(responses[0].rule).toBe('');
    expect(responses[1].rule).toBe('');
  });

  it('edits matchConfig responses with an empty fallback rule', () => {
    const model = dispatch(defaultModel(), ShortAnswerActions.setInputType('math_expression', '1'));
    const correctResponse = model.authoring.parts[0].responses[0];

    const updated = dispatch(
      model,
      ResponseActions.editMatchConfig(
        correctResponse.id,
        MatchConfigs.algebraicEquivalence('2/3', {
          form: { type: 'simplified_fraction' },
        }),
      ),
    );

    const updatedResponse = updated.authoring.parts[0].responses[0];
    expect(updatedResponse.matchConfig?.type).toBe('math_expression');
    expect(
      updatedResponse.matchConfig?.type === 'math_expression' && updatedResponse.matchConfig.math,
    ).toEqual({
      mode: 'algebraic_equivalence',
      expected: '2/3',
      form: { type: 'simplified_fraction' },
    });
    expect(updatedResponse.rule).toBe('');
  });

  it('round trips Short Answer activity JSON with nested matchConfig and empty fallback rules', () => {
    const model: ShortAnswerModelSchema = {
      stem: makeStem('Simplify 1/2'),
      inputType: 'math_expression',
      authoring: {
        parts: [
          {
            id: '1',
            scoringStrategy: ScoringStrategy.average,
            responses: [
              makeMatchConfigResponse(
                MatchConfigs.algebraicEquivalence('1/2', {
                  form: { type: 'simplified_fraction' },
                }),
                1,
                'Correct',
                true,
              ),
              Responses.matchConfigCatchAll(),
            ],
            hints: [makeHint(''), makeHint(''), makeHint('')],
          },
        ],
        transformations: [],
        previewText: '',
      },
    };

    const roundTripped = JSON.parse(JSON.stringify(model));
    const responses = roundTripped.authoring.parts[0].responses;

    expect(roundTripped.inputType).toBe('math_expression');
    expect(responses[0].matchConfig.math.form.type).toBe('simplified_fraction');
    expect(responses[1].matchConfig.type).toBe('always');
    expect(responses[0].rule).toBe('');
    expect(responses[1].rule).toBe('');
  });

  it('round trips Multi Input activity JSON with nested matchConfig and empty fallback rules', () => {
    const input = Model.inputRef();

    const model: MultiInputSchema = {
      stem: multiInputStem(input),
      choices: [],
      submitPerPart: false,
      inputs: [{ inputType: 'math_expression', id: input.id, partId: '1' }],
      authoring: {
        parts: [
          makePart(
            [
              makeMatchConfigResponse(
                MatchConfigs.unitAware('10 m/s', {
                  type: 'convertible_units',
                  units: ['m/s', 'km/hr'],
                }),
                1,
                'Correct',
                true,
              ),
              Responses.matchConfigCatchAll(),
            ],
            [makeHint('')],
            '1',
          ),
        ],
        targeted: [],
        transformations: [makeTransformation('choices', Transform.shuffle, true)],
        previewText: 'Enter a speed',
      },
    };

    const roundTripped = JSON.parse(JSON.stringify(model));
    const responses = roundTripped.authoring.parts[0].responses;

    expect(roundTripped.inputs[0].inputType).toBe('math_expression');
    expect(responses[0].matchConfig.math.unitPolicy.units).toEqual(['m/s', 'km/hr']);
    expect(responses[1].matchConfig.type).toBe('always');
    expect(responses[0].rule).toBe('');
    expect(responses[1].rule).toBe('');
  });
});
