export const MAX_IMAGE_DIMENSION = 10000;
export const MAX_IMAGE_WIDTH = MAX_IMAGE_DIMENSION;

/** Returns a positive pixel dimension capped at 10000px, or undefined for unsupported sizes. */
export const normalizeImageDimension = (value: unknown): number | undefined => {
  const dimension =
    typeof value === 'number'
      ? value
      : typeof value === 'string' && /^(?:\d+(?:\.\d*)?|\.\d+)(?:px)?$/i.test(value.trim())
      ? Number(value.trim().replace(/px$/i, ''))
      : NaN;

  return Number.isFinite(dimension) && dimension > 0
    ? Math.min(dimension, MAX_IMAGE_DIMENSION)
    : undefined;
};

/** Returns a positive pixel width capped at 10000px, or undefined for unsupported sizes. */
export const normalizeImageWidth = normalizeImageDimension;

/** Returns a finite positive aspect ratio from a number, numeric string, or "width / height". */
export const normalizeImageAspectRatio = (value: unknown): number | undefined => {
  const parts =
    typeof value === 'string' &&
    /^(?:\d+(?:\.\d*)?|\.\d+)(?:\s*\/\s*(?:\d+(?:\.\d*)?|\.\d+))?$/.test(value.trim())
      ? value.trim().split('/').map(Number)
      : undefined;
  const ratio =
    typeof value === 'number'
      ? value
      : parts && parts.every((part) => Number.isFinite(part) && part > 0)
      ? parts[0] / (parts[1] ?? 1)
      : NaN;

  return Number.isFinite(ratio) && ratio > 0 ? ratio : undefined;
};
