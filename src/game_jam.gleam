import game
import gleam/float
import gleam/int
import gleam/option
import loader
import lustre
import lustre/attribute.{class}
import lustre/effect as ui_effect
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import tiramisu
import tiramisu/asset
import tiramisu/background
import tiramisu/camera
import tiramisu/effect.{type Effect}
import tiramisu/scene
import tiramisu/transform
import tiramisu/ui
import vec/vec3

pub type State {
  Menu
  Loading(option.Option(asset.LoadProgress))
  Playing(PlayingInfo)
}

pub type PlayingInfo {
  PlayingInfo(wave: Int, enemies: Int)
}

pub type Model {
  Model(state: State)
}

pub type Msg {
  StartLoad
  LoadAssetInfo(loader.LoadState)
  StartWaveUi(PlayingInfo)
  ChangeEnemies(Int)
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
    Menu, StartLoad -> {
      let load_effect =
        loader.load_assets()
        |> ui_effect.map(fn(load_info) { LoadAssetInfo(load_info) })
      #(Model(state: Loading(option.None)), load_effect)
    }
    _, LoadAssetInfo(load_state) -> {
      case load_state {
        loader.LoadProgress(load_progress) -> #(
          Model(state: Loading(option.Some(load_progress))),
          ui_effect.none(),
        )
        loader.AssetsLoaded(load_results) -> #(
          Model(state: Playing(PlayingInfo(0, 0))),
          ui.dispatch_to_tiramisu(StartGame(load_results.cache)),
        )
      }
    }
    Playing(_), StartWaveUi(new_info) -> #(
      Model(Playing(new_info)),
      ui_effect.none(),
    )
    Playing(info), ChangeEnemies(enemy_num) -> #(
      Model(Playing(PlayingInfo(info.wave, enemy_num))),
      ui_effect.none(),
    )
    _, StartLoad | _, StartWaveUi(_) | _, ChangeEnemies(_) -> #(
      model,
      ui_effect.none(),
    )
  }
}

fn view_ui(model: Model) -> Element(Msg) {
  html.div([class("overlay")], [
    case model.state {
      Menu -> menu_overlay()
      Loading(load_progress) -> loading_overlay(load_progress)
      Playing(playing_info) -> game_overlay(playing_info)
    },
  ])
}

fn menu_overlay() -> Element(Msg) {
  html.div([class("menu-wrapper")], [
    html.div([class("lucy-wrapper")], [
      html.img([class("lucy-menu"), attribute.src("lucy.webp")]),
    ]),
    html.div([class("menu")], [
      html.button([class("menu-button"), event.on_click(StartLoad)], [
        html.text("Start Game"),
      ]),
    ]),
  ])
}

fn loading_overlay(
  _load_progress: option.Option(asset.LoadProgress),
) -> Element(Msg) {
  // todo: use load progress here - too quick for me to notice this
  html.div([class("menu-wrapper")], [
    html.div([class("lucy-wrapper")], [
      html.img([class("lucy-menu"), attribute.src("lucy.webp")]),
    ]),
    html.div([class("menu")], [
      html.span([class("loading-text")], [
        html.text("Loading..."),
      ]),
    ]),
  ])
}

fn game_overlay(playing_info: PlayingInfo) -> Element(Msg) {
  html.div([class("gui-wrapper")], [
    html.span([], [html.text("Wave: " <> int.to_string(playing_info.wave))]),
    html.span([], [
      html.text("Enemies left: " <> int.to_string(playing_info.enemies)),
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
  StartGame(asset.AssetCache)
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
    GameMenu, StartGame(asset_cache) -> {
      let #(game_model, game_effect, _physics) = game.init(ctx, asset_cache)
      let effect = effect.map(game_effect, fn(e) { GameMsg(e) })
      #(GameModel(GamePlaying(game_model)), effect)
    }
    GamePlaying(game_model), GameMsg(msg) -> {
      let #(game_model, game_effect, _physics) =
        game.update(game_model, msg, ctx)
      let effect = effect.map(game_effect, fn(e) { GameMsg(e) })
      #(GameModel(GamePlaying(game_model)), effect)
    }
    _, StartGame(_) | _, GameMsg(_) -> #(model, effect.none())
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
