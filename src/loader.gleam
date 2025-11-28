// stuff for loading textures primarily
// could load gltf models but don't have any 3d stuff yet
// probably should add some audio effects at some point
import gleam/javascript/promise
import lustre/effect.{type Effect}
import tiramisu/asset

// sprite for player
pub const lucy_asset: String = "lucy.webp"

pub const diamond_asset: String = "diamond.webp"

pub const decor_asset: String = "decor.webp"

pub const player_shot_asset: String = "shot.webp"

pub const arial_font_asset: String = "fonts/arial_bold.json"

pub type LoadState {
  LoadProgress(asset.LoadProgress)
  AssetsLoaded(asset.BatchLoadResult)
}

pub fn load_assets() -> Effect(LoadState) {
  let assets_to_load = [
    asset.TextureAsset(lucy_asset),
    asset.TextureAsset(diamond_asset),
    asset.TextureAsset(decor_asset),
    asset.TextureAsset(player_shot_asset),
    asset.FontAsset(arial_font_asset),
  ]

  effect.from(fn(dispatch) {
    promise.tap(
      asset.load_batch(assets_to_load, fn(progress) {
        dispatch(LoadProgress(progress))
      }),
      fn(load_result) {
        dispatch(AssetsLoaded(load_result))
        Nil
      },
    )
    Nil
  })
}
