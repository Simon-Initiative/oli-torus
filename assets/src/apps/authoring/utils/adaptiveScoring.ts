const SCORABLE_ADAPTIVE_PART_TYPES = new Set([
  'janus-mcq',
  'janus-input-text',
  'janus-input-number',
  'janus-dropdown',
  'janus-slider',
  'janus-multi-line-text',
  'janus-hub-spoke',
  'janus-text-slider',
  'janus-fill-blanks',
]);

const normalizeNumber = (value: unknown): number => {
  if (typeof value === 'number' && !Number.isNaN(value)) {
    return value;
  }

  if (typeof value === 'string') {
    const parsed = Number(value);
    return Number.isNaN(parsed) ? 0 : parsed;
  }

  return 0;
};

export const adaptiveScreenHasScorableInputs = (activity: any): boolean => {
  const partsLayout = activity?.content?.partsLayout || [];

  return partsLayout.some((part: any) => SCORABLE_ADAPTIVE_PART_TYPES.has(part?.type));
};

export const effectiveAdaptiveScreenMaxScore = (activity: any): number => {
  return normalizeNumber(activity?.content?.custom?.maxScore);
};
