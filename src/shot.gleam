import gleam/int
import gleam/list
import gleam/option
import gleam_community/maths
import loader
import threejs
import tiramisu/asset
import tiramisu/geometry
import tiramisu/material
import tiramisu/scene
import tiramisu/transform
import utils
import vec/vec3

// shots live for 3 seconds
const shot_life_time = 3.0

pub const size = 10.0

pub type ShotModel {
  ShotModel(shots: List(Shot))
}

pub type Shot {
  Shot(
    x: Float,
    y: Float,
    direction: Float,
    rotation: Float,
    colour: Int,
    start_time: Float,
    shot_type: ShotType,
  )
}

pub type ShotType {
  Player
  Enemy(asset.Texture)
}

pub fn init() -> ShotModel {
  ShotModel([])
}

pub fn tick(model: ShotModel, time: Float) -> ShotModel {
  ShotModel(
    model.shots
    |> list.filter(fn(shot) {
      // remove shots that have been around too long
      let still_alive = shot.start_time +. shot_life_time >. time
      case still_alive {
        False -> dispose_shot(shot)
        _ -> Nil
      }
      still_alive
    })
    |> list.map(fn(shot) {
      let x = shot.x +. 10.0 *. maths.cos(shot.direction)
      let y = shot.y +. 10.0 *. maths.sin(shot.direction)
      let rotation = shot.rotation +. 0.2
      Shot(..shot, x: x, y: y, rotation: rotation)
    }),
  )
}

pub fn dispose_shot(shot: Shot) {
  case shot.shot_type {
    Enemy(texture) -> threejs.dispose_texture(texture)
    _ -> Nil
  }
}

pub fn create_player_shots(
  model: ShotModel,
  points: List(utils.PointWithDirection),
  colour: Int,
  time: Float,
) -> ShotModel {
  let shots =
    points
    |> list.map(fn(point) {
      Shot(point.x, point.y, point.direction, 0.0, colour, time, Player)
    })
    |> list.append(model.shots)

  ShotModel(shots)
}

pub fn create_enemy_shot(
  model: ShotModel,
  point: utils.PointWithDirection,
  texture: asset.Texture,
  time: Float,
) {
  let new_shot =
    Shot(point.x, point.y, point.direction, 0.0, 0xffffff, time, Enemy(texture))
  let shots = model.shots |> list.append([new_shot])
  ShotModel(shots)
}

pub fn view(
  model: ShotModel,
  asset_cache: asset.AssetCache,
) -> scene.Node(String) {
  let assert Ok(geometry) = geometry.circle(radius: size, segments: 10)

  let player_shot_texture =
    asset_cache
    |> asset.get_texture(loader.player_shot_asset)
    |> option.from_result()
  let shots =
    list.index_map(model.shots, fn(shot, index) {
      let texture = case shot.shot_type {
        Player -> player_shot_texture
        Enemy(texture) -> option.Some(texture)
      }
      let assert Ok(material) =
        material.basic(
          color: shot.colour,
          transparent: True,
          opacity: 1.0,
          map: texture,
        )
      scene.mesh(
        id: "shot" <> int.to_string(index),
        geometry: geometry,
        material: material,
        transform: transform.at(position: vec3.Vec3(shot.x, shot.y, 0.2))
          |> transform.with_euler_rotation(vec3.Vec3(0.0, 0.0, shot.rotation)),
        physics: option.None,
      )
    })
  scene.empty(id: "Shots", transform: transform.identity, children: shots)
}
