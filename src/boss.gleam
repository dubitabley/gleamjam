//// Final boss!
//// Should be a psychedelic glitchy monster that breaks the world

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
import tiramisu/spritesheet
import tiramisu/transform
import utils
import vec/vec3

const boss_texture_num = 2

pub const replication_time = 0.5

const max_boss_health = 120

pub const max_blast_distance = 400.0

pub const blast_width = 10_000.0

pub const blast_height = 50.0

pub const blast_damage = 3

pub const blast_damage_time = 0.3

pub const blast_time = 2.0

pub const move_time = 0.2

pub const move_dist = 10.0

pub const dying_time = 2.0

const blast_id = "blast"

pub type Model {
  Model(
    x: Float,
    y: Float,
    width: Float,
    height: Float,
    health: Int,
    stage: Int,
    state: BossState,
    textures: List(Texture),
  )
}

pub type BossState {
  Idle
  Replicating(start_time: Float)
  Blasting(
    start_time: Float,
    animation: spritesheet.Animation,
    animation_state: spritesheet.AnimationState,
    angle: Float,
    last_damage_time: option.Option(Float),
  )
  Moving(target_x: Float, target_y: Float, last_move_time: Float)
  Dying(start_time: Float)
}

pub fn should_check_damage(
  current_time: Float,
  last_damage_time: option.Option(Float),
) -> Bool {
  case last_damage_time {
    option.Some(last_damage_time) ->
      current_time >. last_damage_time +. blast_damage_time
    option.None -> True
  }
}

pub fn replication_health_stage(health: Int) -> Int {
  case health {
    health if health <= max_boss_health && health > 80 -> 1
    health if health <= 80 && health > 60 -> 2
    health if health <= 60 && health > 40 -> 3
    _ -> 4
  }
}

pub fn replicate(boss: Model) -> Model {
  let new_textures =
    boss.textures
    |> list.map(fn(texture) { [texture, texture] })
    |> list.flatten()
  let new_width = boss.width +. 200.0
  let new_height = boss.height +. 200.0
  Model(..boss, textures: new_textures, width: new_width, height: new_height)
}

pub type Texture {
  Texture(
    x: Float,
    y: Float,
    rotation: Float,
    opacity: Float,
    texture_num: Int,
    target_x: Float,
    target_y: Float,
  )
}

pub fn init() -> Model {
  let model = Model(0.0, -1500.0, 200.0, 200.0, max_boss_health, 1, Idle, [])
  let texture_num = 5
  let textures =
    list.range(1, texture_num) |> list.map(fn(_) { new_texture(model) })
  let model = Model(..model, textures: textures)
  model
}

fn new_texture(model: Model) -> Texture {
  let texture_num = int.random(boss_texture_num + 1) + 1
  let #(x, y) = get_texture_pos(model)
  let rotation = utils.random_angle()
  let opacity = 0.5

  let #(target_x, target_y) = get_texture_pos(model)

  Texture(x, y, rotation, opacity, texture_num, target_x, target_y)
}

fn get_texture_pos(model: Model) -> #(Float, Float) {
  let x = float.random() *. model.width -. model.width /. 2.0
  let y = float.random() *. model.height -. model.width /. 2.0
  #(x, y)
}

pub fn tick_textures(boss: Model) -> Model {
  case boss.state {
    Dying(..) -> tick_textures_dying(boss)
    _ -> tick_textures_normal(boss)
  }
}

pub fn tick_textures_normal(boss: Model) -> Model {
  let texture_move_dist = 2.0
  let textures =
    boss.textures
    |> list.map(fn(texture) {
      let angle =
        maths.atan2(
          texture.target_y -. texture.y,
          texture.target_x -. texture.x,
        )
      let distance =
        utils.hypot(
          texture.y -. texture.target_y,
          texture.x -. texture.target_x,
        )
      case distance <=. texture_move_dist {
        True -> {
          let new_x = texture.target_x
          let new_y = texture.target_y
          let #(target_x, target_y) = get_texture_pos(boss)
          Texture(
            ..texture,
            x: new_x,
            y: new_y,
            target_x: target_x,
            target_y: target_y,
          )
        }
        False -> {
          let new_x = texture.x +. maths.cos(angle) *. texture_move_dist
          let new_y = texture.y +. maths.sin(angle) *. texture_move_dist
          Texture(..texture, x: new_x, y: new_y)
        }
      }
    })
  Model(..boss, textures: textures)
}

fn tick_textures_dying(boss: Model) -> Model {
  // move textures away from the centre
  let textures =
    boss.textures
    |> list.map(fn(texture) {
      let angle = maths.atan2(texture.y, texture.x)
      let distance = utils.hypot(texture.y, texture.x)

      let move_dist = distance /. 100.0
      let new_x = texture.x +. maths.cos(angle) *. move_dist
      let new_y = texture.y +. maths.sin(angle) *. move_dist

      Texture(..texture, x: new_x, y: new_y)
    })

  Model(..boss, textures: textures)
}

pub fn setup_blast_animation() -> #(
  spritesheet.Animation,
  spritesheet.AnimationState,
) {
  let blast_animation =
    spritesheet.animation(
      name: blast_id,
      frames: [0, 1, 2, 3],
      frame_duration: 0.2,
      loop: spritesheet.Repeat,
    )
  let animation_state = spritesheet.initial_state(blast_id)
  #(blast_animation, animation_state)
}

pub fn view(boss: Model, asset_cache: asset.AssetCache) -> scene.Node(String) {
  let assert Ok(geom) = geometry.plane(1.0, 1.0)

  let textures =
    boss.textures
    |> list.index_map(fn(texture, index) {
      let texture_asset = case texture.texture_num {
        1 -> loader.boss_asset_1
        2 -> loader.boss_asset_2
        _ -> loader.boss_asset_1
      }
      let assert Ok(material) =
        material.basic(
          color: 0xffffff,
          transparent: True,
          opacity: texture.opacity,
          map: asset_cache
            |> asset.get_texture(texture_asset)
            |> option.from_result(),
        )

      scene.mesh(
        id: "BossTexture" <> int.to_string(index),
        geometry: geom,
        material: material,
        transform: transform.at(vec3.Vec3(texture.x, texture.y, 1.0))
          |> transform.with_scale(vec3.Vec3(100.0, 100.0, 1.0)),
        physics: option.None,
      )
    })

  let blast = case boss.state {
    Blasting(_, animation, animation_state, angle, ..) -> {
      let assert Ok(blast_texture) =
        asset_cache |> asset.get_texture(loader.blast_sheet_asset)
      let assert Ok(blast_sheet) =
        spritesheet.from_grid(texture: blast_texture, columns: 2, rows: 2)

      let sprite =
        scene.animated_sprite(
          id: "BossBlast",
          spritesheet: blast_sheet,
          animation: animation,
          state: animation_state,
          width: 1.0,
          height: 1.0,
          transform: transform.identity
            |> transform.with_scale(vec3.Vec3(blast_width, blast_height, 1.0))
            |> transform.with_euler_rotation(vec3.Vec3(0.0, 0.0, angle)),
          pixel_art: False,
          physics: option.None,
        )

      [sprite]
    }
    _ -> []
  }

  scene.empty(
    id: "Boss",
    transform: transform.at(vec3.Vec3(boss.x, boss.y, 1.0)),
    children: textures
      |> list.append(case boss.state {
        Dying(_) -> []
        _ -> [
          health_bar.view_health_bar(
            id: "BossHealthBar",
            health: boss.health,
            max_health: max_boss_health,
            position: vec3.Vec3(0.0, 1.0 *. boss.height, 1.0),
            width: boss.width *. 0.2,
          ),
        ]
      })
      |> list.append(blast),
  )
}
