import gleam/float
import gleam/int
import gleam/list
import gleam/option
import gleam_community/maths
import health_bar
import loader
import tiramisu/asset
import tiramisu/geometry
import tiramisu/material
import tiramisu/scene
import tiramisu/transform
import vec/vec3

const max_health: Int = 100

const decor_num: Int = 6

const decor_size: Float = 40.0

pub const tower_width: Float = 100.0

pub const tower_height: Float = 100.0

pub type TowerModel {
  TowerModel(towers: List(Tower))
}

pub type Tower {
  Tower(x: Float, y: Float, health: Int, decorations: List(Decoration))
}

pub type Decoration {
  Decoration(x: Float, y: Float, rotation: Float)
}

pub fn init() -> TowerModel {
  TowerModel(towers: generate_towers())
}

const tower_dist: Float = 200.0

fn generate_towers() -> List(Tower) {
  [
    Tower(0.0, 0.0 -. tower_dist, max_health, generate_decor()),
    Tower(tower_dist, 0.0, max_health, generate_decor()),
    Tower(0.0, tower_dist, max_health, generate_decor()),
    Tower(0.0 -. tower_dist, 0.0, max_health, generate_decor()),
  ]
}

pub fn set_tower_health(tower: Tower, health: Int) -> Tower {
  let tower_decor_num = decor_num * health / max_health
  let current_tower_decor_num = list.length(tower.decorations)
  let decors = case tower_decor_num < current_tower_decor_num {
    True -> list.take(tower.decorations, tower_decor_num)
    False ->
      case tower_decor_num > current_tower_decor_num {
        True ->
          tower.decorations
          |> list.append(
            list.range(current_tower_decor_num, tower_decor_num)
            |> list.map(generate_decor_index),
          )
        False -> tower.decorations
      }
  }

  Tower(..tower, health: health, decorations: decors)
}

fn generate_decor() -> List(Decoration) {
  list.range(0, decor_num - 1)
  |> list.map(generate_decor_index)
}

fn generate_decor_index(decor_index: Int) -> Decoration {
  let #(x, y) = get_decor_pos(decor_index)
  Decoration(
    x +. float.random() *. 10.0 -. 5.0,
    y +. float.random() *. 10.0 -. 5.0,
    float.random() *. maths.pi() *. 2.0,
  )
}

fn get_decor_pos(index: Int) -> #(Float, Float) {
  let distance = 40.0

  let angle =
    2.0 *. maths.pi() *. int.to_float(index) /. int.to_float(decor_num)

  #(maths.cos(angle) *. distance, maths.sin(angle) *. distance)
}

pub fn view(model: TowerModel, asset_cache) -> scene.Node(String) {
  let assert Ok(sprite_geom) = geometry.plane(width: 1.0, height: 1.0)
  let assert Ok(sprite_mat) =
    material.basic(
      color: 0xdddddd,
      transparent: True,
      opacity: 1.0,
      map: asset.get_texture(asset_cache, loader.diamond_asset)
        |> option.from_result,
    )
  let assert Ok(decor_mat) =
    material.basic(
      color: 0xffffff,
      transparent: True,
      opacity: 1.0,
      map: asset.get_texture(asset_cache, loader.decor_asset)
        |> option.from_result,
    )
  let children =
    list.index_map(model.towers, fn(tower, index) {
      let decor_meshes =
        tower.decorations
        |> list.index_map(fn(decor, decor_index) {
          scene.mesh(
            id: "Tower"
              <> int.to_string(index)
              <> "Decor"
              <> int.to_string(decor_index),
            geometry: sprite_geom,
            material: decor_mat,
            transform: transform.at(position: vec3.Vec3(decor.x, decor.y, 1.0))
              |> transform.with_scale(vec3.Vec3(decor_size, decor_size, 1.0)),
            physics: option.None,
          )
        })

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
              |> transform.with_scale(vec3.Vec3(
                2.0 *. tower_width,
                2.0 *. tower_height,
                1.0,
              )),
            physics: option.None,
          ),
          health_bar.view_health_bar(
            id: "Tower" <> int.to_string(index),
            health: tower.health,
            max_health: max_health,
            position: vec3.Vec3(1.0, 80.0, 1.0),
            width: 20.0,
          ),
        ]
          |> list.append(decor_meshes),
      )
    })
  scene.empty(id: "Towers", transform: transform.identity, children: children)
}
