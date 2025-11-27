import game
import gleam/bool
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
  Playing(playing_info: PlayingInfo, resume: Bool)
  Paused(PlayingInfo, controls_open: Bool)
  WaveComplete(wave_num: Int)
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
  WaveCompleteUi(Int)
  StartWaveUi(PlayingInfo)
  ChangeEnemies(Int)
  TogglePause
  ToggleControls
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
          Model(state: Playing(PlayingInfo(0, 0), False)),
          ui.dispatch_to_tiramisu(StartGame(load_results.cache)),
        )
      }
    }
    Playing(_, _), WaveCompleteUi(wave_num) -> #(
      Model(state: WaveComplete(wave_num)),
      ui_effect.none(),
    )
    Playing(_, _), StartWaveUi(new_info)
    | WaveComplete(_), StartWaveUi(new_info)
    -> {
      #(Model(Playing(new_info, False)), ui_effect.none())
    }
    Playing(info, resuming), ChangeEnemies(enemy_num) -> #(
      Model(Playing(PlayingInfo(info.wave, enemy_num), resuming)),
      ui_effect.none(),
    )
    Playing(info, _), TogglePause -> #(
      Model(Paused(info, False)),
      ui.dispatch_to_tiramisu(ToggleGamePause),
    )
    Paused(info, _), TogglePause -> #(
      Model(Playing(info, True)),
      ui.dispatch_to_tiramisu(ToggleGamePause),
    )
    Paused(info, controls_open), ToggleControls -> #(
      Model(Paused(info, bool.negate(controls_open))),
      ui_effect.none(),
    )
    _, StartLoad
    | _, StartWaveUi(_)
    | _, ChangeEnemies(_)
    | _, TogglePause
    | _, WaveCompleteUi(_)
    | _, ToggleControls
    -> #(model, ui_effect.none())
  }
}

fn view_ui(model: Model) -> Element(Msg) {
  html.div([class("overlay")], [
    case model.state {
      Menu -> menu_overlay()
      Loading(load_progress) -> loading_overlay(load_progress)
      Playing(playing_info, resuming) -> game_overlay(playing_info, resuming)
      Paused(playing_info, controls_open) ->
        paused_overlay(playing_info, controls_open)
      WaveComplete(wave_num) -> wave_over_overlay(wave_num)
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

fn game_overlay(playing_info: PlayingInfo, resuming: Bool) -> Element(Msg) {
  let children = case resuming {
    True -> [game_info(playing_info), game_buttons(False, False)]
    False -> [
      game_info(playing_info),
      game_buttons(False, False),
      wave_start_overlay(playing_info.wave),
    ]
  }
  html.div([], children)
}

fn game_info(playing_info: PlayingInfo) -> Element(Msg) {
  html.div([class("game-info-wrapper")], [
    html.span([], [html.text("Wave: " <> int.to_string(playing_info.wave))]),
    html.span([], [
      html.text("Enemies: " <> int.to_string(playing_info.enemies)),
    ]),
  ])
}

fn game_buttons(paused: Bool, controls_open: Bool) -> Element(Msg) {
  let children = case paused {
    True -> [play_button(paused), controls_button(controls_open)]
    False -> [play_button(paused)]
  }
  html.div([class("game-button-wrapper")], children)
}

fn controls_button(controls_open: Bool) -> Element(Msg) {
  let button_text = case controls_open {
    True -> "Close Controls/Info"
    False -> "Open Controls/Info"
  }
  html.button([class("game-button"), event.on_click(ToggleControls)], [
    html.text(button_text),
  ])
}

fn play_button(paused: Bool) -> Element(Msg) {
  let button_text = case paused {
    True -> "Resume"
    False -> "Pause"
  }
  html.div([class("play-button-wrapper")], [
    html.button([class("game-button"), event.on_click(TogglePause)], [
      html.text(button_text),
    ]),
  ])
}

fn paused_overlay(
  playing_info: PlayingInfo,
  controls_open: Bool,
) -> Element(Msg) {
  let children = case controls_open {
    True -> [
      game_info(playing_info),
      game_buttons(True, controls_open),
      pause_info_overlay(),
      controls_overlay(),
    ]
    False -> [
      game_info(playing_info),
      game_buttons(True, controls_open),
      pause_info_overlay(),
    ]
  }
  html.div([], children)
}

fn wave_over_overlay(wave_num: Int) -> Element(Msg) {
  main_info_overlay("Completed wave " <> int.to_string(wave_num), True)
}

fn wave_start_overlay(wave_num: Int) -> Element(Msg) {
  main_info_overlay("Starting wave " <> int.to_string(wave_num), True)
}

fn pause_info_overlay() -> Element(Msg) {
  main_info_overlay("Paused", False)
}

fn main_info_overlay(main_text: String, fade_out: Bool) -> Element(Msg) {
  let class_name =
    "main-info-text"
    <> case fade_out {
      True -> " fade-out"
      False -> ""
    }
  html.div([class("main-info-wrapper")], [
    html.span([class(class_name)], [
      html.text(main_text),
    ]),
  ])
}

fn controls_overlay() -> Element(Msg) {
  html.div([class("controls-overlay-wrapper")], [
    html.div([class("controls-overlay")], [
      html.h2([], [html.text("Game")]),
      html.div([], [html.text("Defend your diamond towers!")]),
      html.br([]),
      html.div([], [
        html.text("Use WASD to move around, press space to fire at the enemies"),
      ]),
      html.div([], [
        html.text("Use Enter to activate the buttons in world"),
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
  GamePaused(game.Model)
}

pub type GameMsg {
  StartGame(asset.AssetCache)
  GameMsg(game.Msg)
  ToggleGamePause
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
    GamePlaying(_), GameMsg(game.UpdateGui(gui_info)) -> {
      let playing_info = case gui_info {
        game.NewWaveUi(new_wave, enemy_count) ->
          StartWaveUi(PlayingInfo(new_wave, enemy_count))
        game.EnemiesAmount(enemy_count) -> ChangeEnemies(enemy_count)
        game.EndWaveUi(wave_end) -> WaveCompleteUi(wave_end)
      }
      #(model, ui.dispatch_to_lustre(playing_info))
    }
    GamePlaying(game_model), GameMsg(game.GameMsg(msg)) -> {
      let #(game_model, game_effect, _physics) =
        game.update(game_model, msg, ctx)
      let effect = effect.map(game_effect, fn(e) { GameMsg(e) })
      #(GameModel(GamePlaying(game_model)), effect)
    }
    GamePlaying(game_model), ToggleGamePause -> #(
      GameModel(GamePaused(game_model)),
      effect.none(),
    )
    GamePaused(game_model), ToggleGamePause -> {
      let effect = game.resume()
      let effect = effect.map(effect, fn(e) { GameMsg(e) })
      #(GameModel(GamePlaying(game_model)), effect)
    }
    _, StartGame(_) | _, GameMsg(_) | _, ToggleGamePause -> #(
      model,
      effect.none(),
    )
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

    GamePlaying(game_model) | GamePaused(game_model) ->
      game.view(game_model, ctx)
  }
}
