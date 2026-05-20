import type * as _ from "./gleam.d.mts";
import type * as $types from "./math/equality/types.d.mts";

declare class ParityCase extends _.CustomType {
  /** @deprecated */
  constructor(
    operator: string,
    legacy_rule: string,
    spec: $types.EqualitySpec$,
    matching: string,
    nonmatching: string,
    mismatch: $types.EqualityDiagnostic$,
    json: string
  );
  /** @deprecated */
  operator: string;
  /** @deprecated */
  legacy_rule: string;
  /** @deprecated */
  spec: $types.EqualitySpec$;
  /** @deprecated */
  matching: string;
  /** @deprecated */
  nonmatching: string;
  /** @deprecated */
  mismatch: $types.EqualityDiagnostic$;
  /** @deprecated */
  json: string;
}

type ParityCase$ = ParityCase;

export function main(): undefined;

export function standard_numeric_operator_corpus_matches_legacy_rule_shapes_test(
  
): undefined;

export function standard_numeric_operator_corpus_evaluates_positive_and_negative_cases_test(
  
): undefined;

export function parity_corpus_covers_every_standard_numeric_operator_test(): undefined;

export function parity_edge_cases_cover_ranges_scientific_parse_and_precision_test(
  
): undefined;

export function parity_corpus_excludes_adaptive_numeric_forms_test(): undefined;
