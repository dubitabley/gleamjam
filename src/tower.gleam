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
import utils
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
  Tower(
    x: Float,
    y: Float,
    id: Int,
    health: Int,
    decorations: List(Decoration),
    cannon: option.Option(Cannon),
  )
}

pub type Cannon {
  Cannon(
    x: Float,
    y: Float,
    initial_rotation: Float,
    rotation: Float,
    state: CannonState,
    level: Int,
  )
}

pub fn get_cannon_level_cost(level: Int) -> Int {
  case level {
    1 -> 4
    2 -> 9
    3 -> 13
    4 -> 20
    _ -> level * 5
  }
}

pub fn get_cannon_rotation(level: Int) -> Float {
  case level {
    1 -> 0.4
    2 -> 0.6
    3 -> 1.0
    4 -> 2.0
    _ -> maths.pi() *. 2.0
  }
}

pub fn get_cannon_range(level: Int) -> Float {
  case level {
    1 -> 200.0
    2 -> 300.0
    3 -> 500.0
    4 -> 600.0
    _ -> int.to_float(level) *. 150.0
  }
}

pub fn get_cannon_damage(level: Int) -> Int {
  case level {
    1 -> 1
    2 -> 2
    3 -> 4
    4 -> 6
    _ -> level * 2
  }
}

pub type CannonState {
  /// Don't have anything to do, just idle
  CannonIdle
  /// Rotate towards the enemy
  CannonRotating(target_rotation: Float)
  /// Shooting, waiting for next shot
  CannonShooting(start_wait_time: Float)
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
    new_tower(0.0, 0.0 -. tower_dist, 1),
    new_tower(tower_dist, 0.0, 2),
    new_tower(0.0, tower_dist, 3),
    new_tower(0.0 -. tower_dist, 0.0, 4),
  ]
}

fn new_tower(x: Float, y: Float, id: Int) -> Tower {
  Tower(x, y, id, max_health, generate_decor(), option.None)
}

pub fn upgrade_tower(tower: Tower) -> Tower {
  case tower.cannon {
    option.Some(cannon) -> {
      // upgrade the cannon
      let new_cannon = Cannon(..cannon, level: cannon.level + 1)
      Tower(..tower, cannon: option.Some(new_cannon))
    }
    option.None -> {
      Tower(..tower, cannon: option.Some(new_cannon(tower)))
    }
  }
}

fn new_cannon(tower: Tower) -> Cannon {
  let rotation = maths.atan2(tower.y, tower.x)
  // position is offset from the tower
  let x = utils.sign(tower.x) *. 70.0
  let y = utils.sign(tower.y) *. 80.0
  Cannon(x, y, rotation, rotation, CannonIdle, 1)
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

      let cannon_mesh = case tower.cannon {
        option.Some(cannon) -> [view_cannon(cannon, index, asset_cache)]
        option.None -> []
      }

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
          |> list.append(decor_meshes)
          |> list.append(cannon_mesh),
      )
    })
  scene.empty(id: "Towers", transform: transform.identity, children: children)
}

fn view_cannon(
  cannon: Cannon,
  tower_index: Int,
  asset_cache: asset.AssetCache,
) -> scene.Node(String) {
  let assert Ok(sprite) =
    material.basic(
      color: 0xffffff,
      transparent: True,
      opacity: 1.0,
      map: asset_cache
        |> asset.get_texture(loader.cannon_asset)
        |> option.from_result(),
    )
  let assert Ok(geom) = geometry.plane(1.0, 1.0)

  scene.mesh(
    id: "Cannon" <> int.to_string(tower_index),
    geometry: geom,
    material: sprite,
    transform: transform.at(vec3.Vec3(cannon.x, cannon.y, 1.0))
      |> transform.with_euler_rotation(vec3.Vec3(0.0, 0.0, cannon.rotation))
      |> transform.with_scale(vec3.Vec3(100.0, 100.0, 1.0)),
    physics: option.None,
  )
}
