import {
  PrecisionKind,
  validatePrecision,
} from 'components/activities/short_answer/sections/NumericInput';

it('validatePrecision returns a validated Precision object', () => {
  expect(validatePrecision('3')).toEqual({ kind: PrecisionKind.WithPrecision, value: 3 });
  expect(validatePrecision('1203000')).toEqual({
    kind: PrecisionKind.WithPrecision,
    value: 1203000,
  });
  expect(validatePrecision('')).toEqual({ kind: PrecisionKind.Invalid, value: '' });
  expect(validatePrecision('0')).toEqual({ kind: PrecisionKind.Invalid, value: 0 });
  expect(validatePrecision('-1')).toEqual({ kind: PrecisionKind.Invalid, value: -1 });
  expect(validatePrecision('-23')).toEqual({ kind: PrecisionKind.Invalid, value: -23 });
});
