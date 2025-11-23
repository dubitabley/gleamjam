import tiramisu/asset
import typed_array

@external(javascript, "./threejs.ffi.mjs", "loadTextureFromData")
fn load_texture_from_data(
  data: typed_array.Uint8Array,
  width: Int,
  height: Int,
  format: Int,
) -> asset.Texture

@external(javascript, "./threejs.ffi.mjs", "RGBFormat")
fn rgb_format() -> Int

@external(javascript, "./threejs.ffi.mjs", "RGBAFormat")
fn rgba_format() -> Int

pub fn rgba_texture_from_uint_8_array(
  data: typed_array.Uint8Array,
  width: Int,
  height: Int,
) -> asset.Texture {
  load_texture_from_data(data, width, height, rgba_format())
}

pub fn rgb_texture_from_uint_8_array(
  data: typed_array.Uint8Array,
  width: Int,
  height: Int,
) -> asset.Texture {
  load_texture_from_data(data, width, height, rgb_format())
}
