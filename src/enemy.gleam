import gleam/int
import gleam/list
import gleam/option
import threejs
import tiramisu/asset
import tiramisu/effect.{type Effect}
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
  Enemy(x: Float, y: Float, health: Int, texture: asset.Texture)
}

pub type State {
  Moving
  Idle
  Attacking
}

pub type EnemyMsg {
  Tick
}

pub fn init() -> EnemyModel {
  EnemyModel([])
}

pub fn add_enemy(model: EnemyModel) -> EnemyModel {
  let enemy = Enemy(0.0, -150.0, 100, generate_enemy_texture())
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

pub fn update(
  model: EnemyModel,
  msg: EnemyMsg,
) -> #(EnemyModel, Effect(EnemyMsg)) {
  case msg {
    Tick -> {
      #(model, effect.none())
    }
  }
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
