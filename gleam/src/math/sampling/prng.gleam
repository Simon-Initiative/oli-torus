import gleam/int

const modulus = 2_147_483_647

const multiplier = 48_271

/// A portable Park-Miller PRNG state.
///
/// The generator is deterministic and non-cryptographic. It exists only for
/// repeatable math sampling across BEAM and JavaScript, and must not be used for
/// secrets, access control, tokens, or any security-sensitive randomness.
pub opaque type State {
  State(value: Int)
}

/// Normalize a caller seed into the valid Park-Miller state range.
///
/// Park-Miller state cannot be zero, so zero and exact multiples of the modulus
/// map to `1`. Negative seeds are folded with positive modulo so the same input
/// is deterministic on both supported targets.
pub fn new(seed: Int) -> State {
  let normalized = case int.modulo(seed, by: modulus) {
    Ok(0) | Error(_) -> 1
    Ok(value) -> value
  }

  State(value: normalized)
}

/// Return the raw state value for tests and deterministic fixtures without
/// letting callers construct invalid PRNG states.
pub fn state_value(state: State) -> Int {
  let State(value: value) = state
  value
}

/// Advance the PRNG and return the next integer state value.
///
/// The multiplication stays within JavaScript's safe integer range for the
/// Park-Miller constants, which keeps the exact integer sequence aligned with
/// the BEAM target.
pub fn next_int(state: State) -> #(Int, State) {
  let State(value: value) = state
  let next_value = case int.modulo(value * multiplier, by: modulus) {
    Ok(value) -> value
    Error(_) -> 1
  }

  #(next_value, State(value: next_value))
}

/// Advance the PRNG and return a ratio in `(0, 1)`.
///
/// Returning a ratio rather than a target runtime random value keeps sampling
/// reproducible and avoids using JavaScript or Erlang random APIs.
pub fn next_float(state: State) -> #(Float, State) {
  let #(value, next_state) = next_int(state)
  #(int.to_float(value) /. int.to_float(modulus), next_state)
}
