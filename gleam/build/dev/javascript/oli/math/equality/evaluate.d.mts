import type * as _ from "../../gleam.d.mts";
import type * as $types from "../../math/equality/types.d.mts";

export function validate_spec(spec: $types.EqualitySpec$): _.Result<
  $types.EqualitySpec$,
  $types.EqualityConfigError$
>;

export function evaluate(spec: $types.EqualitySpec$, submitted: string): $types.EqualityResult$;
