import gleam/bit_array
import gleam/crypto
import gleam/string
import math/normalization/format
import math/normalization/types

/// Hash a normalized result by first formatting its deterministic normalized
/// debug string, then applying SHA-256 in shared Gleam code.
///
/// The hash intentionally follows the debug string contract so BEAM and
/// JavaScript callers compare the same bytes. The output is lowercase hex for a
/// stable text representation. Md5 and Sha1 are deliberately not used here.
pub fn normalized_hash(normalized: types.Normalized) -> String {
  let debug_string = format.normalized_to_debug_string(normalized)

  crypto.hash(crypto.Sha256, bit_array.from_string(debug_string))
  |> bit_array.base16_encode
  |> string.lowercase
}
