import gleam/int
import gleam/list
import gleam/option
import gleam_community/maths
import loader
import player
import tiramisu/asset
import tiramisu/geometry
import tiramisu/material
import tiramisu/scene
import tiramisu/transform
import vec/vec3

pub type ShotModel {
  ShotModel(shots: List(Shot))
}

pub type Shot {
  Shot(x: Float, y: Float, direction: Float, rotation: Float, colour: Int)
}

pub fn init() -> ShotModel {
  ShotModel([])
}

pub fn tick(model: ShotModel) -> ShotModel {
  ShotModel(
    list.map(model.shots, fn(shot) {
      let x = shot.x +. 10.0 *. maths.sin(shot.direction)
      let y = shot.y +. 10.0 *. maths.cos(shot.direction)
      let rotation = shot.rotation +. 0.2
      Shot(x, y, shot.direction, rotation, shot.colour)
    }),
  )
}

pub fn create_shots(
  model: ShotModel,
  points: List(player.PlayerPoint),
  colour: Int,
) -> ShotModel {
  let shots =
    points
    |> list.map(fn(point) {
      Shot(point.x, point.y, point.direction, 0.0, colour)
    })
    |> list.append(model.shots)

  ShotModel(shots)
}

pub fn view(
  model: ShotModel,
  asset_cache: asset.AssetCache,
) -> scene.Node(String) {
  let assert Ok(geometry) = geometry.circle(radius: 10.0, segments: 10)

  let texture =
    asset_cache
    |> asset.get_texture(loader.shot_asset)
    |> option.from_result()
  let shots =
    list.index_map(model.shots, fn(shot, index) {
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
