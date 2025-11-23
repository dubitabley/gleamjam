// stuff for handling the player
import gleam/list
import gleam/option
import loader
import tiramisu/asset
import tiramisu/geometry
import tiramisu/material
import tiramisu/scene
import tiramisu/transform
import vec/vec3

// consts
const size: Float = 100.0

pub type PlayerModel {
  PlayerModel(x: Float, y: Float)
}

pub type Movement {
  Keys(up: Bool, down: Bool, left: Bool, right: Bool)
}

pub fn init() -> PlayerModel {
  PlayerModel(0.0, 0.0)
}

pub fn move(model: PlayerModel, movement: Movement) -> PlayerModel {
  let x = add_input(model.x, movement.left, movement.right, 3.0)
  let y = add_input(model.y, movement.up, movement.down, 3.0)
  PlayerModel(x: x, y: y)
}

pub type PlayerPoint {
  PlayerPoint(x: Float, y: Float, direction: Float)
}

pub fn get_points(model: PlayerModel) -> List(PlayerPoint) {
  // hardcoded 5 points of the star
  let points = [
    PlayerPoint(-0.05 *. size, 0.47 *. size, -0.24),
    PlayerPoint(0.45 *. size, 0.21 *. size, 1.17),
    PlayerPoint(0.36 *. size, -0.39 *. size, 2.36),
    PlayerPoint(-0.18 *. size, -0.47 *. size, -2.5),
    PlayerPoint(-0.45 *. size, 0.05 *. size, -1.42),
  ]
  list.map(points, fn(x) { add_point(model.x, model.y, x) })
}

fn add_point(x: Float, y: Float, point: PlayerPoint) -> PlayerPoint {
  PlayerPoint(point.x +. x, point.y +. y, point.direction)
}

fn add_input(val: Float, neg: Bool, pos: Bool, offset: Float) -> Float {
  case neg, pos {
    False, False | True, True -> val
    False, True -> val +. offset
    True, False -> val -. offset
  }
}

pub fn view(
  player: PlayerModel,
  asset_cache: asset.AssetCache,
) -> scene.Node(String) {
  let assert Ok(sprite_geom) = geometry.plane(width: size, height: size)
  let assert Ok(sprite_mat) =
    material.basic(
      // lucy pink colour
      color: 0xffaff3,
      transparent: True,
      opacity: 1.0,
      map: asset_cache
        |> asset.get_texture(loader.lucy_asset)
        |> option.from_result(),
    )

  scene.mesh(
    id: "sprite",
    geometry: sprite_geom,
    material: sprite_mat,
    transform: transform.at(position: vec3.Vec3(player.x, player.y, 1.0)),
    physics: option.None,
  )
}
