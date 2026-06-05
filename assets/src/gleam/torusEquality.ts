import type { Result } from 'gleam_build/oli/gleam.mjs';
import type {
  EqualityConfigError$,
  EqualityResult$,
  EqualitySpec$,
} from 'gleam_build/oli/math/equality/types.mjs';
import {
  decode_equality_config,
  encode_equality_config,
  evaluate_equality,
} from 'gleam_build/oli/torus_math.mjs';

export type EqualityConfig = EqualitySpec$;
export type EqualityConfigError = EqualityConfigError$;
export type EqualityResult = EqualityResult$;
export type EqualityDecodeResult = Result<EqualitySpec$, EqualityConfigError$>;

export function decodeEqualityConfig(source: string): EqualityDecodeResult {
  return decode_equality_config(source);
}

export function encodeEqualityConfig(spec: EqualityConfig): string {
  return encode_equality_config(spec);
}

export function evaluateEquality(spec: EqualityConfig, submitted: string): EqualityResult {
  return evaluate_equality(spec, submitted);
}
