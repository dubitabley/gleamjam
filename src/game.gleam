import gleam/float
import gleam/option
import player
import shot
import tiramisu
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
    camera_position: vec2.Vec2(Float),
  )
}

pub type Msg {
  Tick
  PlayerMsg(player.PlayerMsg)
  TowerMsg(tower.TowerMsg)
}

pub fn init(
  _ctx: tiramisu.Context(String),
) -> #(Model, Effect(Msg), option.Option(_)) {
  let #(player_model, player_effect) = player.init()
  let player_effect = effect.map(player_effect, fn(msg) { PlayerMsg(msg) })
  let #(tower_model, tower_effect) = tower.init()
  let tower_effect = effect.map(tower_effect, fn(msg) { TowerMsg(msg) })

  let shot_model = shot.init()

  #(
    Model(
      time: 0.0,
      player: player_model,
      tower: tower_model,
      camera_position: vec2.Vec2(0.0, 0.0),
      shots: shot_model,
    ),
    effect.batch([effect.tick(Tick), player_effect, tower_effect]),
    option.None,
  )
}

pub fn update(
  model: Model,
  msg: Msg,
  ctx: tiramisu.Context(String),
) -> #(Model, Effect(Msg), option.Option(_)) {
  // handle input to move player around
  let up = input.is_key_pressed(ctx.input, input.KeyS)
  let down = input.is_key_pressed(ctx.input, input.KeyW)
  let left = input.is_key_pressed(ctx.input, input.KeyA)
  let right = input.is_key_pressed(ctx.input, input.KeyD)

  let player_movement = player.Keys(up, down, left, right)
  let player_model = player.move(model.player, player_movement)
  let model =
    Model(
      ..model,
      player: player_model,
      camera_position: vec2.Vec2(player_model.x, player_model.y),
    )

  let shoot = input.is_key_just_pressed(ctx.input, input.Space)
  let shot_model = case shoot {
    True -> {
      shot.create_shots(model.shots, player.get_points(model.player))
    }
    False -> model.shots
  }
  let model = Model(..model, shots: shot_model)

  let #(model, effect) = case msg {
    Tick -> {
      let new_time = model.time +. ctx.delta_time /. 1000.0
      // tick things that need it
      let shot_model = shot.tick(model.shots)

      #(Model(..model, time: new_time, shots: shot_model), effect.tick(Tick))
    }
    PlayerMsg(msg) -> {
      let #(player_model, player_effect) = player.update(model.player, msg)
      let player_effect = effect.map(player_effect, fn(msg) { PlayerMsg(msg) })
      #(Model(..model, player: player_model), player_effect)
    }
    TowerMsg(msg) -> {
      let #(tower_model, tower_effect) = tower.update(model.tower, msg)
      let tower_effect = effect.map(tower_effect, fn(msg) { TowerMsg(msg) })
      #(Model(..model, tower: tower_model), tower_effect)
    }
  }

  #(model, effect, option.None)
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
    player.view(model.player),
    tower.view(model.tower),
    shot.view(model.shots),
  ])
}
