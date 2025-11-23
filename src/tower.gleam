import gleam/int
import gleam/list
import gleam/option
import loader
import tiramisu/asset
import tiramisu/geometry
import tiramisu/material
import tiramisu/scene
import tiramisu/transform
import vec/vec3

pub type TowerModel {
  TowerModel(towers: List(Tower))
}

pub type Tower {
  Tower(x: Float, y: Float, health: Int)
}

pub fn init() -> TowerModel {
  TowerModel(towers: generate_towers())
}

const tower_dist: Float = 200.0

fn generate_towers() -> List(Tower) {
  [
    Tower(0.0, 0.0 -. tower_dist, 100),
    Tower(tower_dist, 0.0, 100),
    Tower(0.0, tower_dist, 100),
    Tower(0.0 -. tower_dist, 0.0, 100),
  ]
}

pub fn view(model: TowerModel, asset_cache) -> scene.Node(String) {
  let assert Ok(sprite_geom) = geometry.plane(width: 100.0, height: 100.0)
  let assert Ok(sprite_mat) =
    material.basic(
      // diamond colour
      color: 0xffffff,
      transparent: True,
      opacity: 1.0,
      map: asset.get_texture(asset_cache, loader.diamond_asset)
        |> option.from_result,
    )
  let children =
    list.index_map(model.towers, fn(tower, index) {
      scene.mesh(
        id: "Tower" <> int.to_string(index),
        geometry: sprite_geom,
        material: sprite_mat,
        transform: transform.at(position: vec3.Vec3(tower.x, tower.y, 0.0))
          |> transform.with_euler_rotation(vec3.Vec3(0.0, 0.0, 0.0))
          |> transform.with_scale(vec3.Vec3(2.0, 2.0, 1.0)),
        physics: option.None,
      )
    })
  scene.empty(id: "Towers", transform: transform.identity, children: children)
}
