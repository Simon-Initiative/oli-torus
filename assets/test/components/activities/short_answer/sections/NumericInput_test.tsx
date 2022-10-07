import {
  PrecisionKind,
  precisionFromString,
} from 'components/activities/short_answer/sections/NumericInput';

it('validatePrecision returns a validated Precision object', () => {
  expect(precisionFromString('3')).toEqual({ kind: PrecisionKind.WithPrecision, value: 3 });
  expect(precisionFromString('1203000')).toEqual({
    kind: PrecisionKind.WithPrecision,
    value: 1203000,
  });
  expect(precisionFromString('')).toEqual({ kind: PrecisionKind.Invalid, value: '' });
  expect(precisionFromString('0')).toEqual({ kind: PrecisionKind.Invalid, value: 0 });
  expect(precisionFromString('-1')).toEqual({ kind: PrecisionKind.Invalid, value: -1 });
  expect(precisionFromString('-23')).toEqual({ kind: PrecisionKind.Invalid, value: -23 });
});
