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

pub const cannon_asset: String = "cannon.webp"

pub const player_shot_asset: String = "shot.webp"

pub const boss_asset_1: String = "boss_texture_1.webp"

pub const boss_asset_2: String = "boss_texture_2.webp"

pub const blast_sheet_asset: String = "blast_sheet.webp"

pub const arial_font_asset: String = "fonts/arial_bold.json"

pub const background_star_asset: String = "star.glb"

pub type LoadState {
  LoadProgress(asset.LoadProgress)
  AssetsLoaded(asset.BatchLoadResult)
}

pub fn load_assets_game() -> Effect(LoadState) {
  load_assets([
    asset.TextureAsset(lucy_asset),
    asset.TextureAsset(diamond_asset),
    asset.TextureAsset(decor_asset),
    asset.TextureAsset(player_shot_asset),
    asset.TextureAsset(cannon_asset),
    asset.TextureAsset(boss_asset_1),
    asset.TextureAsset(boss_asset_2),
    asset.TextureAsset(blast_sheet_asset),
    asset.FontAsset(arial_font_asset),
  ])
}

fn load_assets(assets_to_load: List(asset.AssetType)) -> Effect(LoadState) {
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

pub fn load_assets_menu() {
  load_assets([asset.ModelAsset(background_star_asset)])
}
