import gleam/int
import gleam/list
import gleam/option
import gleam_community/maths
import health_bar
import threejs
import tiramisu/asset
import tiramisu/geometry
import tiramisu/material
import tiramisu/scene
import tiramisu/transform
import typed_array
import utils
import vec/vec3

const max_health = 10

pub const size = 50.0

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

pub fn create_enemy(x: Float, y: Float) -> Enemy {
  Enemy(x, y, max_health, generate_enemy_texture(), Idle(1000))
}

pub fn dispose_enemy(enemy: Enemy) -> Nil {
  threejs.dispose_texture(enemy.texture)
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
          let distance = utils.hypot(y -. enemy.y, x -. enemy.x)
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

fn choose_state(enemy: Enemy) -> State {
  todo
}

pub fn view(model: EnemyModel) -> scene.Node(String) {
  let assert Ok(sprite_geom) = geometry.plane(width: size, height: size)
  let children =
    list.index_map(model.enemies, fn(enemy, index) {
      let assert Ok(sprite_mat) =
        material.basic(
          color: 0xffffff,
          transparent: True,
          opacity: 1.0,
          map: option.Some(enemy.texture),
        )
      scene.empty(
        id: "EnemyGroup" <> int.to_string(index),
        transform: transform.at(position: vec3.Vec3(enemy.x, enemy.y, 0.0)),
        children: [
          scene.mesh(
            id: "Enemy" <> int.to_string(index),
            geometry: sprite_geom,
            material: sprite_mat,
            transform: transform.identity,
            physics: option.None,
          ),
          health_bar.view_health_bar(
            id: "Enemy" <> int.to_string(index),
            health: enemy.health,
            max_health: max_health,
            position: vec3.Vec3(1.0, 35.0, 1.0),
            width: 10.0,
          ),
        ],
      )
    })
  scene.empty(id: "Enemies", transform: transform.identity, children: children)
}
