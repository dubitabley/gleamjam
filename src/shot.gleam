import gleam/int
import gleam/list
import gleam/option
import gleam_community/maths
import player
import tiramisu/geometry
import tiramisu/material
import tiramisu/scene
import tiramisu/transform
import vec/vec3

const shot_asset: String = "shot.webp"

pub type ShotModel {
  ShotModel(shots: List(Shot))
}

pub type Shot {
  Shot(x: Float, y: Float, direction: Float)
}

pub fn init() -> ShotModel {
  ShotModel([])
}

pub fn tick(model: ShotModel) -> ShotModel {
  ShotModel(
    list.map(model.shots, fn(shot) {
      let x = shot.x +. 10.0 *. maths.sin(shot.direction)
      let y = shot.y +. 10.0 *. maths.cos(shot.direction)
      Shot(x, y, shot.direction)
    }),
  )
}

pub fn create_shots(
  model: ShotModel,
  points: List(player.PlayerPoint),
) -> ShotModel {
  let shots =
    points
    |> list.map(fn(point) { Shot(point.x, point.y, point.direction) })
    |> list.append(model.shots)

  ShotModel(shots)
}

pub fn view(model: ShotModel) -> scene.Node(String) {
  let assert Ok(geometry) = geometry.circle(radius: 10.0, segments: 10)
  let assert Ok(material) =
    material.basic(
      color: 0xff0000,
      transparent: False,
      opacity: 1.0,
      map: option.None,
    )
  let shots =
    list.index_map(model.shots, fn(shot, index) {
      scene.mesh(
        id: "shot" <> int.to_string(index),
        geometry: geometry,
        material: material,
        transform: transform.at(position: vec3.Vec3(shot.x, shot.y, 0.2)),
        physics: option.None,
      )
    })
  scene.empty(id: "Shots", transform: transform.identity, children: shots)
}
