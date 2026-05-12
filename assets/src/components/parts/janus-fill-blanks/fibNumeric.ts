/**
 * FITB numeric blanks: parse and compare learner input with authored answers.
 * Parsing is strict (whole string must be a single numeric literal) to align with
 * Elixir adaptive grading (`Float.parse/1` consumes the full trimmed string).
 * Future: range or ±% tolerance can extend fibNumericAnswerCorrect without changing the content key.
 */

/** Accepts decimals and scientific notation (e.g. 1e10, -2.5E+3). Rejects hex, Infinity, partial parses. */
const FIB_NUMERIC_LITERAL =
  /^[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?$/;

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

/**
 * True when the learner submission parses as a finite number and equals (===)
 * any accepted authored answer after the same parse — same rule as adaptive
 * `numeric_part_result` exact mode.
 */
export function fibNumericAnswerCorrect(
  submission: string,
  correct: string,
  alternateCorrect: string | string[] | undefined,
): boolean {
  const submitted = parseFibNumber(submission);
  if (submitted === null) return false;

  const accepted = acceptedNumericStrings(correct, alternateCorrect);
  const acceptedValues = accepted
    .map((s) => parseFibNumber(s))
    .filter((n): n is number => n !== null);

  if (acceptedValues.length === 0) return false;

  return acceptedValues.some((v) => v === submitted);
}

/** True when every non-empty row is a valid FITB number (for authoring validation). */
export function fibNumericRowsAllValid(rows: string[]): boolean {
  if (!rows?.length) return false;
  return rows.every((r) => parseFibNumber(r) !== null);
}
