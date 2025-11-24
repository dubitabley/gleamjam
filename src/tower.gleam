import gleam/int
import gleam/list
import gleam/option
import health_bar
import loader
import tiramisu/asset
import tiramisu/geometry
import tiramisu/material
import tiramisu/scene
import tiramisu/transform
import vec/vec3

const max_health: Int = 100

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
    Tower(0.0, 0.0 -. tower_dist, max_health),
    Tower(tower_dist, 0.0, max_health),
    Tower(0.0, tower_dist, max_health),
    Tower(0.0 -. tower_dist, 0.0, max_health),
  ]
}

pub fn view(model: TowerModel, asset_cache) -> scene.Node(String) {
  let assert Ok(sprite_geom) = geometry.plane(width: 100.0, height: 100.0)
  let assert Ok(sprite_mat) =
    material.basic(
      // diamond colour
      color: 0xcccccc,
      transparent: True,
      opacity: 1.0,
      map: asset.get_texture(asset_cache, loader.diamond_asset)
        |> option.from_result,
    )
  let children =
    list.index_map(model.towers, fn(tower, index) {
      scene.empty(
        id: "TowerGroup" <> int.to_string(index),
        transform: transform.at(position: vec3.Vec3(tower.x, tower.y, 0.0)),
        children: [
          scene.mesh(
            id: "Tower" <> int.to_string(index),
            geometry: sprite_geom,
            material: sprite_mat,
            transform: transform.identity
              |> transform.with_euler_rotation(vec3.Vec3(0.0, 0.0, 0.0))
              |> transform.with_scale(vec3.Vec3(2.0, 2.0, 1.0)),
            physics: option.None,
          ),
          health_bar.view_health_bar(
            id: "Tower" <> int.to_string(index),
            health: tower.health,
            max_health: max_health,
            position: vec3.Vec3(1.0, 80.0, 1.0),
            width: 20.0,
          ),
        ],
      )
    })
  scene.empty(id: "Towers", transform: transform.identity, children: children)
}
