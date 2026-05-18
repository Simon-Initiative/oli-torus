import { equalWithToleranceOperator } from '../../../adaptivity/operators/equality';

/** Accepts decimals and scientific notation (e.g. 1e10, -2.5E+3). Rejects hex, Infinity, partial parses. */
const FIB_NUMERIC_LITERAL = /^[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?$/;

export function parseFibNumber(raw: string | null | undefined): number | null {
  if (raw == null) return null;
  const t = String(raw).trim();
  if (t === '') return null;
  if (!FIB_NUMERIC_LITERAL.test(t)) return null;
  const n = Number(t);
  return Number.isFinite(n) ? n : null;
}

function acceptedNumericStrings(correct: string, alternateCorrect: string | string[] | undefined) {
  const alternates = normalizeAlternateStrings(alternateCorrect);
  const primary = String(correct ?? '').trim();
  const out: string[] = [];
  if (primary) out.push(primary);
  for (const a of alternates) {
    if (a && !out.includes(a)) out.push(a);
  }
  return out;
}

function normalizeAlternateStrings(alternateCorrect: string | string[] | undefined): string[] {
  if (alternateCorrect == null) return [];
  if (Array.isArray(alternateCorrect)) {
    return alternateCorrect.map((s) => String(s).trim()).filter(Boolean);
  }
  if (typeof alternateCorrect === 'string' && alternateCorrect.trim()) {
    return alternateCorrect
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
  }
  return [];
}

function effectiveTolerancePercent(tolerancePercent: number | null | undefined): number {
  if (tolerancePercent == null || !Number.isFinite(tolerancePercent)) return 0;
  return tolerancePercent > 0 ? tolerancePercent : 0;
}

export function fibNumericAnswerCorrect(
  submission: string,
  correct: string,
  alternateCorrect: string | string[] | undefined,
  tolerancePercent?: number | null,
): boolean {
  const submitted = parseFibNumber(submission);
  if (submitted === null) return false;

  const accepted = acceptedNumericStrings(correct, alternateCorrect);
  const acceptedValues = accepted
    .map((s) => parseFibNumber(s))
    .filter((n): n is number => n !== null);

  if (acceptedValues.length === 0) return false;

  const tol = effectiveTolerancePercent(tolerancePercent ?? undefined);
  if (tol <= 0) {
    return acceptedValues.some((v) => v === submitted);
  }

  return acceptedValues.some((expected) => equalWithToleranceOperator(submitted, [expected, tol]));
}

export function fibNumericRowsAllValid(rows: string[]): boolean {
  if (!rows?.length) return false;
  return rows.every((r) => parseFibNumber(r) !== null);
}

export function fibTolerancePercentAuthoringValid(tp: unknown): boolean {
  if (tp == null) return true;
  if (typeof tp !== 'number' || !Number.isFinite(tp)) return false;
  return tp >= 0;
}
