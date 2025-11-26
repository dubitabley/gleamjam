// stuff for handling the player
import gleam/list
import gleam/option
import health_bar
import loader
import tiramisu/asset
import tiramisu/geometry
import tiramisu/material
import tiramisu/scene
import tiramisu/transform
import utils
import vec/vec3

// consts
pub const size: Float = 100.0

const max_health: Int = 100

const speed: Float = 10.0

// in seconds
const shot_delay: Float = 0.5

pub type PlayerModel {
  PlayerModel(
    x: Float,
    y: Float,
    health: Int,
    shot_time: Float,
    shot_colour: ShotColour,
  )
}

// rainbow!
pub type ShotColour {
  Red
  Orange
  Yellow
  Green
  Blue
  Indigo
  Violet
}

fn shot_colour(shot_colour: ShotColour) -> Int {
  case shot_colour {
    Red -> 0xf43545
    Orange -> 0xfa8901
    Yellow -> 0xfad717
    Green -> 0x00ba71
    Blue -> 0x00c2de
    Indigo -> 0x00418d
    Violet -> 0x5f2879
  }
}

fn next_shot_colour(shot_colour: ShotColour) -> ShotColour {
  case shot_colour {
    Red -> Orange
    Orange -> Yellow
    Yellow -> Green
    Green -> Blue
    Blue -> Indigo
    Indigo -> Violet
    Violet -> Red
  }
}

pub type Movement {
  Keys(up: Bool, down: Bool, left: Bool, right: Bool)
}

pub fn init() -> PlayerModel {
  PlayerModel(0.0, 0.0, max_health, 0.0, Red)
}

pub fn move(model: PlayerModel, movement: Movement) -> PlayerModel {
  let x = add_input(model.x, movement.left, movement.right, speed)
  let y = add_input(model.y, movement.up, movement.down, speed)
  PlayerModel(..model, x: x, y: y)
}

pub fn can_make_shot(model: PlayerModel, time: Float) -> Bool {
  time >. model.shot_time +. shot_delay
}

pub fn make_shot(model: PlayerModel, time: Float) -> #(PlayerModel, Int) {
  let colour = shot_colour(model.shot_colour)
  #(
    PlayerModel(
      ..model,
      shot_time: time,
      shot_colour: next_shot_colour(model.shot_colour),
    ),
    colour,
  )
}

pub fn get_points(model: PlayerModel) -> List(utils.PointWithDirection) {
  // hardcoded 5 points of the star
  let points = [
    utils.PointWithDirection(-0.05 *. size, 0.47 *. size, 1.81),
    utils.PointWithDirection(0.45 *. size, 0.21 *. size, 0.31),
    utils.PointWithDirection(0.36 *. size, -0.39 *. size, -0.66),
    utils.PointWithDirection(-0.18 *. size, -0.47 *. size, -2.03),
    utils.PointWithDirection(-0.45 *. size, 0.05 *. size, -3.08),
  ]
  list.map(points, fn(x) { add_point(model.x, model.y, x) })
}

fn add_point(
  x: Float,
  y: Float,
  point: utils.PointWithDirection,
) -> utils.PointWithDirection {
  utils.PointWithDirection(point.x +. x, point.y +. y, point.direction)
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
  scene.empty(
    id: "PlayerGroup",
    transform: transform.at(position: vec3.Vec3(player.x, player.y, 0.0)),
    children: [
      scene.mesh(
        id: "Player",
        geometry: sprite_geom,
        material: sprite_mat,
        transform: transform.identity,
        physics: option.None,
      ),
      health_bar.view_health_bar(
        id: "Player",
        health: player.health,
        max_health: max_health,
        position: vec3.Vec3(1.0, 60.0, 1.0),
        width: 15.0,
      ),
    ],
  )
}
