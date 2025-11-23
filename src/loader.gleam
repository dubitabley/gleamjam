// stuff for loading textures primarily
// could load gltf models but don't have any 3d stuff yet
// probably should add some audio effects at some point
import gleam/javascript/promise
import lustre/effect.{type Effect}
import tiramisu/asset

// sprite for player
pub const lucy_asset: String = "lucy.webp"

pub const diamond_asset: String = "diamond.webp"

pub const shot_asset: String = "shot.webp"

pub type LoadState {
  LoadProgress(asset.LoadProgress)
  AssetsLoaded(asset.BatchLoadResult)
}

pub fn load_assets() -> Effect(LoadState) {
  let assets_to_load = [
    asset.TextureAsset(lucy_asset),
    asset.TextureAsset(diamond_asset),
    asset.TextureAsset(shot_asset),
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
