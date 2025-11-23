import game
import gleam/float
import gleam/option
import lustre
import lustre/attribute.{class}
import lustre/effect as ui_effect
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import tiramisu
import tiramisu/background
import tiramisu/camera
import tiramisu/effect.{type Effect}
import tiramisu/scene
import tiramisu/transform
import tiramisu/ui
import vec/vec3

pub type State {
  Menu
  Loading
  Playing
}

pub type Model {
  Model(state: State)
}

pub type Msg {
  StartGameUi
}

pub fn main() -> Nil {
  let assert Ok(_) =
    lustre.application(init_ui, update_ui, view_ui)
    |> lustre.start("#app", Nil)
  tiramisu.run(
    dimensions: option.None,
    background: background.Color(0x1a1a2e),
    init: init,
    update: update,
    view: view,
  )
}

fn init_ui(_flags) {
  #(Model(Menu), ui.register_lustre())
}

fn update_ui(model: Model, msg: Msg) -> #(Model, ui_effect.Effect(Msg)) {
  case model.state, msg {
    Menu, StartGameUi -> #(
      Model(state: Playing),
      ui.dispatch_to_tiramisu(StartGame),
    )
    _, StartGameUi -> #(model, ui_effect.none())
  }
}

fn view_ui(model: Model) -> Element(Msg) {
  html.div([class("overlay")], [
    case model.state {
      Menu -> menu_overlay()
      Loading -> html.div([], [])
      Playing -> html.div([], [])
    },
  ])
}

fn menu_overlay() -> Element(Msg) {
  html.div([class("menu-wrapper")], [
    html.div([class("lucy-wrapper")], [
      html.img([class("lucy-menu"), attribute.src("lucy.webp")]),
    ]),
    html.div([class("menu")], [
      html.button([class("menu-button"), event.on_click(StartGameUi)], [
        html.text("Start Game"),
      ]),
    ]),
  ])
}

pub type GameModel {
  GameModel(state: GameState)
}

pub type GameState {
  GameMenu
  GamePlaying(game.Model)
}

pub type GameMsg {
  StartGame
  GameMsg(game.Msg)
}

pub fn init(
  _ctx: tiramisu.Context(String),
) -> #(GameModel, Effect(GameMsg), option.Option(_)) {
  #(GameModel(GameMenu), effect.none(), option.None)
}

pub fn update(
  model: GameModel,
  msg: GameMsg,
  ctx: tiramisu.Context(String),
) -> #(GameModel, Effect(GameMsg), option.Option(_)) {
  let #(model, effect) = case model.state, msg {
    GameMenu, StartGame -> {
      let #(game_model, game_effect, _physics) = game.init(ctx)
      let effect = effect.map(game_effect, fn(e) { GameMsg(e) })
      #(GameModel(GamePlaying(game_model)), effect)
    }
    GamePlaying(game_model), GameMsg(msg) -> {
      let #(game_model, game_effect, _physics) =
        game.update(game_model, msg, ctx)
      let effect = effect.map(game_effect, fn(e) { GameMsg(e) })
      #(GameModel(GamePlaying(game_model)), effect)
    }
    _, StartGame | _, GameMsg(_) -> #(model, effect.none())
  }

  #(model, effect, option.None)
}

pub fn view(
  model: GameModel,
  ctx: tiramisu.Context(String),
) -> scene.Node(String) {
  case model.state {
    GameMenu -> {
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
      ])
    }

    GamePlaying(game_model) -> game.view(game_model, ctx)
  }
}
