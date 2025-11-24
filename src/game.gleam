import enemy
import gleam/float
import gleam/option
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
    effect.batch([effect.tick(Tick), effect.none()]),
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
      let model = game_loop(model, ctx)

      #(model, effect.tick(Tick))
    }
    StartWave -> {
      let new_wave = model.wave + 1
      // add enemies as appropriate
      #(model, effect.none())
    }
  }

  #(model, effect, option.None)
}

fn game_loop(model: Model, ctx: tiramisu.Context(String)) -> Model {
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
        )
      #(shot_model, player_model)
    }
    _, _ -> #(model.shots, player_model)
  }
  let shot_model = shot.tick(shot_model)
  let new_time = model.time +. ctx.delta_time /. 1000.0

  Model(
    ..model,
    player: player_model,
    camera_position: vec2.Vec2(player_model.x, player_model.y),
    shots: shot_model,
    time: new_time,
  )
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
