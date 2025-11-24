import gleam/float
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam_community/maths
import threejs
import tiramisu/asset
import tiramisu/geometry
import tiramisu/material
import tiramisu/scene
import tiramisu/transform
import typed_array
import vec/vec3

pub type EnemyModel {
  EnemyModel(enemies: List(Enemy))
}

pub type Enemy {
  Enemy(x: Float, y: Float, health: Int, texture: asset.Texture, state: State)
}

pub type State {
  Moving(x: Float, y: Float)
  Idle(time: Int)
  Attacking
}

pub fn init() -> EnemyModel {
  EnemyModel([])
}

pub fn add_enemy(model: EnemyModel) -> EnemyModel {
  let enemy = Enemy(0.0, -150.0, 100, generate_enemy_texture(), Idle(1000))
  EnemyModel(list.append(model.enemies, [enemy]))
}

const texture_size = 5

fn generate_enemy_texture() -> asset.Texture {
  list.range(1, texture_size * texture_size)
  |> list.flat_map(fn(_) { random_rgba_colour() })
  |> typed_array.from_list()
  |> threejs.rgba_texture_from_uint_8_array(texture_size, texture_size)
}

fn random_rgba_colour() -> List(Int) {
  let alpha = case int.random(3) {
    0 | 1 -> 255
    _ -> 0
  }
  [int.random(256), int.random(256), int.random(256), alpha]
}

pub fn tick(model: EnemyModel) -> EnemyModel {
  let new_enemies =
    model.enemies
    |> list.map(fn(enemy) {
      case enemy.state {
        Moving(x, y) -> {
          let angle = maths.atan2(y -. enemy.y, x -. enemy.x)
          let distance = hypot(y -. enemy.y, x -. enemy.x)
          let move_speed = 1.0
          case distance <=. move_speed {
            True -> {
              Enemy(..enemy, x: x, y: y)
            }
            False -> {
              let new_x = move_speed *. maths.cos(angle)
              let new_y = move_speed *. maths.sin(angle)
              Enemy(..enemy, x: new_x, y: new_y)
            }
          }
        }
        Idle(time) -> {
          let new_time = time - 1
          case new_time <= 0 {
            True -> {
              let new_state = choose_state(enemy)
              Enemy(..enemy, state: new_state)
            }
            False -> enemy
          }
        }
        Attacking -> enemy
      }
    })
  EnemyModel(enemies: new_enemies)
}

fn hypot(x: Float, y: Float) -> Float {
  float.square_root(x *. x +. y *. y)
  |> result.unwrap(0.0)
}

fn choose_state(enemy: Enemy) -> State {
  todo
}

pub fn view(model: EnemyModel) -> scene.Node(String) {
  let assert Ok(sprite_geom) = geometry.plane(width: 50.0, height: 50.0)
  let children =
    list.index_map(model.enemies, fn(enemy, index) {
      let assert Ok(sprite_mat) =
        material.basic(
          color: 0xffffff,
          transparent: True,
          opacity: 1.0,
          map: option.Some(enemy.texture),
        )
      scene.mesh(
        id: "Enemy" <> int.to_string(index),
        geometry: sprite_geom,
        material: sprite_mat,
        transform: transform.at(position: vec3.Vec3(enemy.x, enemy.y, 10.0)),
        physics: option.None,
      )
    })
  scene.empty(id: "Towers", transform: transform.identity, children: children)
}
