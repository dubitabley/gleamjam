import enemy
import gleam/bool
import gleam/float
import gleam/int
import gleam/list
import gleam/option
import gleam_community/maths
import player
import shot
import tiramisu
import tiramisu/asset
import tiramisu/camera
import tiramisu/effect.{type Effect}
import tiramisu/input
import tiramisu/light
import tiramisu/scene
import tiramisu/transform
import tower
import utils
import vec/vec2
import vec/vec3

pub type Model {
  Model(
    time: Float,
    player: player.PlayerModel,
    tower: tower.TowerModel,
    shots: shot.ShotModel,
    enemies: enemy.EnemyModel,
    camera_position: vec2.Vec2(Float),
    asset_cache: asset.AssetCache,
    wave: Int,
  )
}

pub type Msg {
  Tick
  StartWave
  UpdateGui(UpdateGuiInfo)
}

pub type UpdateGuiInfo {
  NewWave(wave: Int, enemy_count: Int)
  EnemiesAmount(enemy_count: Int)
}

pub fn init(
  _ctx: tiramisu.Context(String),
  asset_cache: asset.AssetCache,
) -> #(Model, Effect(Msg), option.Option(_)) {
  let player_model = player.init()
  let tower_model = tower.init()

  let shot_model = shot.init()
  let enemy_model = enemy.init()

  #(
    Model(
      time: 0.0,
      player: player_model,
      tower: tower_model,
      camera_position: vec2.Vec2(0.0, 0.0),
      shots: shot_model,
      enemies: enemy_model,
      asset_cache: asset_cache,
      wave: 0,
    ),
    effect.batch([
      effect.tick(Tick),
      effect.from(fn(dispatch) { dispatch(StartWave) }),
    ]),
    option.None,
  )
}

pub fn update(
  model: Model,
  msg: Msg,
  ctx: tiramisu.Context(String),
) -> #(Model, Effect(Msg), option.Option(_)) {
  let #(model, effect) = case msg {
    Tick -> {
      // run the game loop
      let #(model, effect) = game_loop(model, ctx)

      #(model, effect.batch([effect.tick(Tick), effect]))
    }
    StartWave -> {
      let new_wave = model.wave + 1
      // add enemies as appropriate
      let enemy_model = start_wave(new_wave)
      // update gui
      let enemy_count = list.length(enemy_model.enemies)
      let wave_info = NewWave(new_wave, enemy_count)
      #(
        Model(..model, enemies: enemy_model, wave: new_wave),
        effect.from(fn(dispatch) { dispatch(UpdateGui(wave_info)) }),
      )
    }
    // this one gets handled
    UpdateGui(_) -> #(model, effect.none())
  }

  #(model, effect, option.None)
}

fn start_wave(wave_num: Int) -> enemy.EnemyModel {
  let enemy_count = wave_num * wave_num
  let new_enemies =
    list.range(0, enemy_count - 1)
    |> list.map(fn(index) {
      let #(x, y) = get_enemy_position(index, enemy_count)
      enemy.create_enemy(x, y)
    })
  enemy.EnemyModel(enemies: new_enemies)
}

fn get_enemy_position(index: Int, total: Int) -> #(Float, Float) {
  let distance = 1000.0

  let angle = 2.0 *. maths.pi() *. int.to_float(index) /. int.to_float(total)

  #(maths.cos(angle) *. distance, maths.sin(angle) *. distance)
}

fn game_loop(
  model: Model,
  ctx: tiramisu.Context(String),
) -> #(Model, Effect(Msg)) {
  // handle input to move player around
  let up = input.is_key_pressed(ctx.input, input.KeyS)
  let down = input.is_key_pressed(ctx.input, input.KeyW)
  let left = input.is_key_pressed(ctx.input, input.KeyA)
  let right = input.is_key_pressed(ctx.input, input.KeyD)

  let player_movement = player.Keys(up, down, left, right)
  let player_model = player.move(model.player, player_movement)

  let shoot = input.is_key_pressed(ctx.input, input.Space)
  let #(shot_model, player_model) = case
    shoot,
    player.can_make_shot(player_model, model.time)
  {
    True, True -> {
      let #(player_model, shot_colour) =
        player.make_shot(player_model, model.time)
      let shot_model =
        shot.create_shots(
          model.shots,
          player.get_points(model.player),
          shot_colour,
          model.time,
        )
      #(shot_model, player_model)
    }
    _, _ -> #(model.shots, player_model)
  }
  let shot_model = shot.tick(shot_model, model.time)
  let new_time = model.time +. ctx.delta_time /. 1000.0

  let model =
    Model(
      ..model,
      player: player_model,
      camera_position: vec2.Vec2(player_model.x, player_model.y),
      shots: shot_model,
      time: new_time,
    )
  let #(model, effect) = check_collisions(model)
  #(model, effect)
}

// performs collision checks between shots, enemies and towers
fn check_collisions(model: Model) -> #(Model, Effect(Msg)) {
  let collisions =
    model.shots.shots
    |> list.map(fn(shot) {
      model.enemies.enemies
      |> list.filter(fn(enemy) { check_collision_shot_enemy(enemy, shot) })
      |> list.map(fn(enemy) { #(enemy, shot) })
    })
    |> list.flatten

  let shots =
    model.shots.shots
    |> list.filter(fn(shot) {
      collisions
      |> list.map(fn(collision) { collision.1 })
      |> list.contains(shot)
      |> bool.negate
    })

  let start_enemy_count = list.length(model.enemies.enemies)

  let enemies =
    model.enemies.enemies
    |> list.filter_map(fn(enemy) {
      let collision_num =
        collisions
        |> list.map(fn(collision) { collision.0 })
        |> list.count(fn(coll) { coll == enemy })
      let new_health = enemy.health - collision_num * 2
      let enemy = enemy.Enemy(..enemy, health: new_health)
      case new_health > 0 {
        True -> Ok(enemy)
        False -> Error(0)
        // filter_map really should use option instead of result
      }
    })

  let end_enemy_count = list.length(enemies)

  let effect = case end_enemy_count != start_enemy_count {
    True ->
      effect.from(fn(dispatch) {
        dispatch(UpdateGui(EnemiesAmount(end_enemy_count)))
      })
    False -> effect.none()
  }

  #(
    Model(
      ..model,
      shots: shot.ShotModel(shots),
      enemies: enemy.EnemyModel(enemies),
    ),
    effect,
  )
}

fn check_collision_shot_enemy(enemy: enemy.Enemy, shot: shot.Shot) -> Bool {
  let distance = utils.hypot(shot.y -. enemy.y, shot.x -. enemy.x)
  distance <. shot.size +. enemy.size
}

pub fn view(model: Model, ctx: tiramisu.Context(String)) -> scene.Node(String) {
  let cam =
    camera.camera_2d(
      width: float.round(ctx.canvas_width),
      height: float.round(ctx.canvas_height),
    )

  scene.empty(id: "Scene", transform: transform.identity, children: [
    scene.camera(
      id: "camera",
      camera: cam,
      transform: transform.at(position: vec3.Vec3(
        model.camera_position.x,
        model.camera_position.y,
        20.0,
      )),
      look_at: option.None,
      active: True,
      viewport: option.None,
      postprocessing: option.None,
    ),
    scene.light(
      id: "ambient",
      light: {
        let assert Ok(light) = light.ambient(color: 0xffffff, intensity: 1.0)
        light
      },
      transform: transform.identity,
    ),
    player.view(model.player, model.asset_cache),
    tower.view(model.tower, model.asset_cache),
    shot.view(model.shots, model.asset_cache),
    enemy.view(model.enemies),
  ])
}
