/// 2D Game Example - Orthographic Camera
import gleam/float
import gleam/option
import player
import tiramisu
import tiramisu/background
import tiramisu/camera
import tiramisu/effect.{type Effect}
import tiramisu/input
import tiramisu/light
import tiramisu/scene
import tiramisu/transform
import vec/vec3

pub type Model {
  Model(time: Float, player_model: player.PlayerModel)
}

pub type Msg {
  Tick
  PlayerMsg(player.PlayerMsg)
}

pub fn main() -> Nil {
  tiramisu.run(
    dimensions: option.None,
    background: background.Color(0x1a1a2e),
    init:,
    update:,
    view:,
  )
}

fn init(
  _ctx: tiramisu.Context(String),
) -> #(Model, Effect(Msg), option.Option(_)) {
  let #(player_model, player_effect) = player.init()
  let player_effect = effect.map(player_effect, fn(msg) { PlayerMsg(msg) })
  #(
    Model(time: 0.0, player_model: player_model),
    effect.batch([effect.tick(Tick), player_effect]),
    option.None,
  )
}

fn update(
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
  let #(player_model, player_move_effect) =
    player.update(model.player_model, player.PlayerMove(player_movement))
  let player_move_effect =
    effect.map(player_move_effect, fn(msg) { PlayerMsg(msg) })
  let model = Model(..model, player_model: player_model)

  let #(model, effect) = case msg {
    Tick -> {
      let new_time = model.time +. ctx.delta_time /. 1000.0
      #(Model(..model, time: new_time), effect.tick(Tick))
    }
    PlayerMsg(msg) -> {
      let #(player_model, player_effect) =
        player.update(model.player_model, msg)
      let player_effect = effect.map(player_effect, fn(msg) { PlayerMsg(msg) })
      #(Model(..model, player_model: player_model), player_effect)
    }
  }

  #(model, effect.batch([effect, player_move_effect]), option.None)
}

fn view(model: Model, ctx: tiramisu.Context(String)) -> scene.Node(String) {
  let cam =
    camera.camera_2d(
      width: float.round(ctx.canvas_width),
      height: float.round(ctx.canvas_height),
    )

  scene.empty(id: "Scene", transform: transform.identity, children: [
    scene.camera(
      id: "camera",
      camera: cam,
      transform: transform.at(position: vec3.Vec3(0.0, 0.0, 20.0)),
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
    player.player_view(model.player_model),
  ])
}
