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
import world_ui

pub type Model {
  Model(
    time: Float,
    player: player.PlayerModel,
    tower: tower.TowerModel,
    shots: shot.ShotModel,
    enemies: enemy.EnemyModel,
    camera_position: vec2.Vec2(Float),
    asset_cache: asset.AssetCache,
    wave_info: WaveInfo,
    world_ui: world_ui.Model(GameMsgType),
    points: Int,
  )
}

pub type WaveInfo {
  OngoingWave(wave_num: Int)
  WaveEnd(last_wave_num: Int)
}

pub type Msg {
  GameMsg(GameMsgType)
  UpdateGui(UpdateGuiInfo)
  GameOver
}

pub type GameMsgType {
  Tick
  StartWave
  EndWave
  EnemyMsg(enemy.EnemyMsg)
  AddPoints(point_num: Int)
  UpgradeTower(TowerUpgradeInfo)
}

pub type TowerUpgradeInfo {
  TowerUpgradeInfo(tower_id: Int)
}

fn map_game_msg(msg: GameMsgType) -> Msg {
  GameMsg(msg)
}

pub type UpdateGuiInfo {
  EndWaveUi(wave_num: Int)
  NewWaveUi(wave: Int, enemy_count: Int)
  EnemiesAmount(enemy_count: Int)
  UpdatePoints(point_num: Int)
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
      wave_info: WaveEnd(0),
      world_ui: world_ui.init(),
      points: 0,
    ),
    effect.batch([
      effect.tick(Tick) |> effect.map(map_game_msg),
      effect.from(fn(dispatch) { dispatch(StartWave |> map_game_msg) }),
    ]),
    option.None,
  )
}

pub fn resume() -> Effect(Msg) {
  effect.tick(Tick) |> effect.map(map_game_msg)
}

pub fn update(
  model: Model,
  msg: GameMsgType,
  ctx: tiramisu.Context(String),
) -> #(Model, Effect(Msg), option.Option(_)) {
  let #(model, effect) = case msg {
    Tick -> {
      // run the game loop
      let #(model, effect) = game_loop(model, ctx)
      let tick_effect = effect.tick(Tick) |> effect.map(map_game_msg)

      #(model, effect.batch([tick_effect, effect]))
    }
    StartWave -> {
      let assert WaveEnd(current_wave) = model.wave_info
      let new_wave = current_wave + 1
      // add enemies as appropriate
      let enemy_model = start_wave(new_wave, model.time)
      // update gui
      let enemy_count = list.length(enemy_model.enemies)
      let new_wave_info = NewWaveUi(new_wave, enemy_count)
      #(
        Model(
          ..model,
          enemies: enemy_model,
          wave_info: OngoingWave(new_wave),
          world_ui: world_ui.init(),
        ),
        effect.from(fn(dispatch) { dispatch(UpdateGui(new_wave_info)) }),
      )
    }
    EndWave -> {
      let assert OngoingWave(current_wave) = model.wave_info
      // add world ui button
      let world_ui =
        world_ui.Model(
          [
            world_ui.Button(
              0.0,
              0.0,
              100.0,
              100.0,
              world_ui.ButtonText("|>"),
              0,
              False,
              StartWave,
            ),
          ]
          |> list.append(add_tower_world_buttons(model.tower.towers)),
        )
      #(
        Model(..model, wave_info: WaveEnd(current_wave), world_ui: world_ui),
        effect.from(fn(dispatch) {
          dispatch(UpdateGui(EndWaveUi(current_wave)))
        }),
      )
    }
    EnemyMsg(msg) -> {
      case msg {
        enemy.CreateShot(point) -> {
          let shot_model =
            shot.create_enemy_shot(
              model.shots,
              point,
              enemy.create_shot_texture(),
              model.time,
            )
          #(Model(..model, shots: shot_model), effect.none())
        }
      }
    }
    AddPoints(point_num) -> {
      let new_point_num = model.points + point_num
      #(
        Model(..model, points: new_point_num),
        effect.from(fn(dispatch) {
          dispatch(UpdateGui(UpdatePoints(new_point_num)))
        }),
      )
    }
    UpgradeTower(tower_info) -> {
      let towers =
        model.tower.towers
        |> list.map(fn(tower) {
          case tower.id == tower_info.tower_id {
            True -> tower.upgrade_tower(tower)
            False -> tower
          }
        })
      let model = Model(..model, tower: tower.TowerModel(towers))
      #(model, effect.none())
    }
  }

  #(model, effect, option.None)
}

fn add_tower_world_buttons(
  towers: List(tower.Tower),
) -> List(world_ui.Button(GameMsgType)) {
  towers
  |> list.map(fn(tower) {
    let x = tower.x +. utils.sign(tower.x) *. 100.0
    let y = tower.y +. utils.sign(tower.y) *. 100.0
    world_ui.Button(
      x,
      y,
      80.0,
      80.0,
      world_ui.ButtonText("+"),
      5,
      False,
      UpgradeTower(TowerUpgradeInfo(tower.id)),
    )
  })
}

fn start_wave(wave_num: Int, time: Float) -> enemy.EnemyModel {
  let enemy_count = wave_num * wave_num
  let new_enemies =
    list.range(0, enemy_count - 1)
    |> list.map(fn(index) {
      let #(x, y) = get_enemy_position(index, enemy_count)
      enemy.create_enemy(x, y, time)
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
        shot.create_player_shots(
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
  let #(enemy_model, enemy_effect) =
    enemy.tick(model.enemies, model.tower, model.player, model.time)
  let enemy_effect =
    enemy_effect
    |> effect.map(fn(enemy_msg) { GameMsg(EnemyMsg(enemy_msg)) })
  let player_rect =
    utils.Rectangle(player_model.x, player_model.y, player.size, player.size)
  let world_ui =
    world_ui.check_player_enabled(model.world_ui, model.points, player_rect)
  let interact =
    input.is_key_just_pressed(ctx.input, input.Enter)
    || input.is_key_just_pressed(ctx.input, input.Space)
  let #(effects, costs) =
    case interact {
      True -> world_ui.get_effect_collisions(world_ui)
      False -> []
    }
    |> list.unzip()
  let collision_effect =
    effects
    |> list.map(fn(msg) { effect.from(fn(dispatch) { dispatch(GameMsg(msg)) }) })
    |> effect.batch
  // technically you could go into negative here :/
  // should fix maybe
  let total_cost = costs |> utils.sum()
  let new_points = model.points - total_cost
  let points_ui_effect =
    effect.from(fn(dispatch) { dispatch(UpdateGui(UpdatePoints(new_points))) })
  let new_time = model.time +. ctx.delta_time /. 1000.0

  let model =
    Model(
      ..model,
      enemies: enemy_model,
      player: player_model,
      camera_position: vec2.Vec2(player_model.x, player_model.y),
      shots: shot_model,
      time: new_time,
      points: new_points,
      world_ui: world_ui,
    )
  let #(model, player_shot_effect) = check_player_shot_collisions(model)
  let #(model, enemy_shot_effect) = check_enemy_shot_collisions(model)
  #(
    model,
    effect.batch([
      enemy_effect,
      player_shot_effect,
      enemy_shot_effect,
      collision_effect,
      points_ui_effect,
    ]),
  )
}

fn check_enemy_shot_collisions(model: Model) -> #(Model, Effect(Msg)) {
  // get collisions up front
  let tower_collisions =
    model.shots.shots
    |> list.filter(shot.is_enemy)
    |> list.map(fn(shot) {
      model.tower.towers
      |> list.filter(fn(tower) { check_collision_tower_shot(tower, shot) })
      |> list.map(fn(tower) { #(tower, shot) })
    })
    |> list.flatten

  // remove shots that collided
  let shots =
    model.shots.shots
    |> list.filter(fn(shot) {
      tower_collisions
      |> list.map(utils.second_tuple)
      |> list.contains(shot)
      |> bool.negate
    })

  let towers =
    model.tower.towers
    |> list.filter_map(fn(tower) {
      let collision_num =
        tower_collisions
        |> list.map(fn(collision) { collision.0 })
        |> list.count(fn(coll) { coll == tower })
      let new_health = tower.health - collision_num * 2
      let tower = tower.set_tower_health(tower, new_health)
      case new_health > 0 {
        True -> Ok(tower)
        False -> {
          Error(0)
        }
        // filter_map really should use option instead of result
      }
    })

  let shots_player_collisions =
    shots
    |> list.filter(shot.is_enemy)
    |> list.filter(fn(shot) { check_collision_player_shot(model.player, shot) })

  // remove shots that collided
  let shots =
    shots
    |> utils.list_filter(shots_player_collisions)

  let player_health =
    model.player.health - 2 * list.length(shots_player_collisions)
  let player = player.PlayerModel(..model.player, health: player_health)

  let effect = case player_health <= 0 {
    True -> effect.from(fn(dispatch) { dispatch(GameOver) })
    False -> effect.none()
  }

  #(
    Model(
      ..model,
      player: player,
      shots: shot.ShotModel(shots),
      tower: tower.TowerModel(towers),
    ),
    effect,
  )
}

// performs collision checks between shots, enemies and towers
fn check_player_shot_collisions(model: Model) -> #(Model, Effect(Msg)) {
  let collisions =
    model.shots.shots
    |> list.filter(shot.is_player)
    |> list.map(fn(shot) {
      model.enemies.enemies
      |> list.filter(fn(enemy) { check_collision_enemy_shot(enemy, shot) })
      |> list.map(fn(enemy) { #(enemy, shot) })
    })
    |> list.flatten

  // remove shots that collided
  let shots =
    model.shots.shots
    |> list.filter(fn(shot) {
      collisions
      |> list.map(utils.second_tuple)
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
        False -> {
          // this just disposes of the texture and cleans it up
          enemy.dispose_enemy(enemy)
          Error(0)
        }
        // filter_map really should use option instead of result
      }
    })

  let end_enemy_count = list.length(enemies)

  let effect = case start_enemy_count - end_enemy_count, end_enemy_count == 0 {
    0, _ -> effect.none()
    enemies_down, True ->
      effect.batch([
        effect.from(fn(dispatch) {
          dispatch(AddPoints(enemies_down + 5) |> map_game_msg)
        }),
        effect.from(fn(dispatch) { dispatch(EndWave |> map_game_msg) }),
      ])
    enemies_down, False ->
      effect.batch([
        effect.from(fn(dispatch) {
          dispatch(AddPoints(enemies_down) |> map_game_msg)
        }),
        effect.from(fn(dispatch) {
          dispatch(UpdateGui(EnemiesAmount(end_enemy_count)))
        }),
      ])
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

fn check_collision_tower_shot(tower: tower.Tower, shot: shot.Shot) -> Bool {
  let tower_rect =
    utils.Rectangle(tower.x, tower.y, tower.tower_width, tower.tower_height)
  let shot_circle = utils.Circle(shot.x, shot.y, shot.size)
  utils.check_collision_circle_rect(shot_circle, tower_rect)
}

fn check_collision_enemy_shot(enemy: enemy.Enemy, shot: shot.Shot) -> Bool {
  let enemy_circle = utils.Circle(enemy.x, enemy.y, enemy.size)
  let shot_circle = utils.Circle(shot.x, shot.y, shot.size)
  utils.check_collision_circles(enemy_circle, shot_circle)
}

fn check_collision_player_shot(
  player: player.PlayerModel,
  shot: shot.Shot,
) -> Bool {
  let player_circle = utils.Circle(player.x, player.y, player.size /. 2.0)
  let shot_circle = utils.Circle(shot.x, shot.y, shot.size)
  utils.check_collision_circles(player_circle, shot_circle)
}

pub fn view(
  model: Model,
  ctx: tiramisu.Context(String),
  background: List(scene.Node(String)),
) -> scene.Node(String) {
  let cam =
    camera.camera_2d(
      width: float.round(ctx.canvas_width),
      height: float.round(ctx.canvas_height),
    )

  scene.empty(
    id: "Scene",
    transform: transform.identity,
    children: [
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
      world_ui.view(model.world_ui, model.asset_cache),
    ]
      |> list.append(background),
  )
}
