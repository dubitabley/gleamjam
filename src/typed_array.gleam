/// A Uint8Array in gleam - https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/Uint8Array
pub type Uint8Array

/// Convert a Gleam list to a JavaScript Uint8Array.
///
@external(javascript, "./typed_array.ffi.mjs", "fromList")
pub fn from_list(a: List(Int)) -> Uint8Array
