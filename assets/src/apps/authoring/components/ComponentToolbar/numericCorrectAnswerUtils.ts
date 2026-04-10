export interface NumericCorrectAnswer {
  range: boolean;
  correctAnswer?: number;
  correctMin?: number;
  correctMax?: number;
}

const numericCorrectnessRequiredParts = new Set([
  'janus_input_number',
  'janus_slider',
  'janus-input-number',
  'janus-slider',
]);

export const requiresNumericCorrectAnswer = (...identifiers: Array<string | undefined | null>) =>
  identifiers.some((identifier) => !!identifier && numericCorrectnessRequiredParts.has(identifier));

export const defaultExactCorrectAnswer = (custom: Record<string, any> = {}) => {
  if (typeof custom.minimum === 'number') return custom.minimum;
  if (typeof custom.minValue === 'number') return custom.minValue;
  return 0;
};

export const defaultRangeCorrectAnswer = (
  custom: Record<string, any> = {},
): NumericCorrectAnswer => {
  const min = defaultExactCorrectAnswer(custom);

  if (typeof custom.maximum === 'number') {
    return { range: true, correctMin: min, correctMax: custom.maximum };
  }

  if (typeof custom.maxValue === 'number') {
    return { range: true, correctMin: min, correctMax: custom.maxValue };
  }

  return { range: true, correctMin: min, correctMax: min };
};

export const hasValidNumericCorrectAnswer = (answer: any) => {
  if (!answer || typeof answer !== 'object') return false;

  if (answer.range) {
    return (
      typeof answer.correctMin === 'number' &&
      Number.isFinite(answer.correctMin) &&
      typeof answer.correctMax === 'number' &&
      Number.isFinite(answer.correctMax) &&
      answer.correctMin <= answer.correctMax
    );
  }

  return typeof answer.correctAnswer === 'number' && Number.isFinite(answer.correctAnswer);
};
