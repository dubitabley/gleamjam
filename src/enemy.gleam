import gleam/float
import gleam/int
import gleam/list
import gleam/option
import gleam_community/maths
import health_bar
import player
import threejs
import tiramisu/asset
import tiramisu/effect.{type Effect}
import tiramisu/geometry
import tiramisu/material
import tiramisu/scene
import tiramisu/transform
import tower
import typed_array
import utils
import vec/vec3

const max_health = 10

const shoot_delay = 2.0

const idle_delay = 1.0

pub const size = 50.0

pub type EnemyModel {
  EnemyModel(enemies: List(Enemy))
}

pub type Enemy {
  Enemy(x: Float, y: Float, health: Int, texture: asset.Texture, state: State)
}

pub type EnemyMsg {
  CreateShot(utils.PointWithDirection)
}

pub type State {
  Moving(x: Float, y: Float)
  Idle(start_time: Float, wait_time: Float)
  Shooting(shoot_point: utils.PointWithDirection)
}

pub fn init() -> EnemyModel {
  EnemyModel([])
}

pub fn create_enemy(x: Float, y: Float, start_time: Float) -> Enemy {
  Enemy(
    x,
    y,
    max_health,
    generate_enemy_texture(),
    Idle(start_time, idle_delay),
  )
}

pub fn create_shot_texture() -> asset.Texture {
  // todo: should this be different?
  generate_enemy_texture()
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

pub fn tick(
  model: EnemyModel,
  towers: tower.TowerModel,
  player: player.PlayerModel,
  time: Float,
) -> #(EnemyModel, Effect(EnemyMsg)) {
  let #(new_enemies, effects) =
    model.enemies
    |> list.map(fn(enemy) {
      case enemy.state {
        Moving(x, y) -> {
          let angle = maths.atan2(y -. enemy.y, x -. enemy.x)
          let distance = utils.hypot(y -. enemy.y, x -. enemy.x)
          let move_speed = 2.0
          let enemy = case distance <=. move_speed {
            True -> {
              let new_state = choose_state(enemy, towers, player)
              Enemy(..enemy, x: x, y: y, state: new_state)
            }
            False -> {
              let new_x = enemy.x +. move_speed *. maths.cos(angle)
              let new_y = enemy.y +. move_speed *. maths.sin(angle)
              Enemy(..enemy, x: new_x, y: new_y)
            }
          }
          #(enemy, effect.none())
        }
        Idle(start_time, wait_time) -> {
          let enemy = case time >. start_time +. wait_time {
            True -> {
              let new_state = choose_state(enemy, towers, player)
              Enemy(..enemy, state: new_state)
            }
            False -> enemy
          }
          #(enemy, effect.none())
        }
        Shooting(shoot_point) -> {
          let new_state = Idle(time, shoot_delay)
          #(
            Enemy(..enemy, state: new_state),
            effect.from(fn(dispatch) { dispatch(CreateShot(shoot_point)) }),
          )
        }
      }
    })
    |> list.unzip
  let effect = effects |> effect.batch
  #(EnemyModel(enemies: new_enemies), effect)
}

const shoot_distance = 200.0

// enemy logic - very rudimentary
//
// if within distance of player, shoot at them
// if within distance of tower, shoot at that
// else move towards nearest tower
fn choose_state(
  enemy: Enemy,
  towers: tower.TowerModel,
  player: player.PlayerModel,
) -> State {
  let distance_to_player = utils.hypot(enemy.y -. player.y, enemy.x -. player.x)
  case distance_to_player <. shoot_distance {
    True -> {
      let angle = maths.atan2(player.y -. enemy.y, player.x -. enemy.x)
      // +. { float.random() *. 0.1 -. 0.05 }
      let shoot_point = utils.PointWithDirection(enemy.x, enemy.y, angle)
      Shooting(shoot_point)
    }
    False -> {
      let #(closest_tower, distance) =
        towers.towers
        |> list.map(fn(tower) {
          #(tower, utils.hypot(enemy.y -. tower.y, enemy.x -. tower.x))
        })
        |> list.fold(#(option.None, 10_000_000.0), fn(accum, current) {
          let #(best_tower, distance) = accum
          let #(current_tower, current_distance) = current
          case current_distance <. distance {
            True -> #(option.Some(current_tower), current_distance)
            False -> #(best_tower, distance)
          }
        })
      case distance <. shoot_distance, closest_tower {
        True, option.Some(tower) -> {
          // shoot at closest tower
          let angle = maths.atan2(tower.y -. enemy.y, tower.x -. enemy.x)
          let shoot_point = utils.PointWithDirection(enemy.x, enemy.y, angle)
          Shooting(shoot_point)
        }
        False, option.Some(tower) -> {
          // move towards closest tower
          let angle =
            maths.atan2(tower.y -. enemy.y, tower.x -. enemy.x)
            +. { float.random() *. 1.0 -. 0.5 }

          let move_distance = float.random() *. 100.0 +. 100.0

          let new_x = enemy.x +. move_distance *. maths.cos(angle)
          let new_y = enemy.y +. move_distance *. maths.sin(angle)

          Moving(x: new_x, y: new_y)
        }
        _, option.None -> {
          // move towards player
          let angle =
            maths.atan2(player.y -. enemy.y, player.x -. enemy.x)
            +. { float.random() *. 1.0 -. 0.5 }

          let move_distance = float.random() *. 100.0 +. 100.0

          let new_x = enemy.x +. move_distance *. maths.cos(angle)
          let new_y = enemy.y +. move_distance *. maths.sin(angle)

          Moving(x: new_x, y: new_y)
        }
      }
    }
  }
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
