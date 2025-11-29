import game
import gleam/bool
import gleam/float
import gleam/int
import gleam/list
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
import tiramisu/light
import tiramisu/scene
import tiramisu/transform
import tiramisu/ui
import utils
import vec/vec3

pub type State {
  Menu(controls_open: Bool)
  Loading(option.Option(asset.LoadProgress))
  Playing(playing_info: PlayingInfo, resume: Bool, points: Int)
  Paused(PlayingInfo, controls_open: Bool, points: Int)
  WaveComplete(wave_num: Int, points: Int)
  GameOver
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
  LoadMenuAssetInfo(loader.LoadState)
  WaveCompleteUi(Int)
  StartWaveUi(PlayingInfo)
  ChangeEnemies(Int)
  TogglePause
  ToggleControls
  UpdatePointsUi(points: Int)
  GameOverUi
  BackToMenu
}

pub fn main() -> Nil {
  let assert Ok(_) =
    lustre.application(init_ui, update_ui, view_ui)
    |> lustre.start("#app", Nil)
  tiramisu.run(
    dimensions: option.None,
    background: background.Color(0x131323),
    init: init,
    update: update,
    view: view,
  )
}

fn init_ui(_flags) -> #(Model, ui_effect.Effect(Msg)) {
  let background_assets_effect =
    loader.load_assets_menu()
    |> ui_effect.map(fn(loader_msg) { LoadMenuAssetInfo(loader_msg) })
  #(
    Model(Menu(False)),
    ui_effect.batch([ui.register_lustre(), background_assets_effect]),
  )
}

fn update_ui(model: Model, msg: Msg) -> #(Model, ui_effect.Effect(Msg)) {
  case model.state, msg {
    Menu(_), StartLoad | GameOver, StartLoad -> {
      let load_effect =
        loader.load_assets_game()
        |> ui_effect.map(fn(load_info) { LoadAssetInfo(load_info) })
      #(Model(state: Loading(option.None)), load_effect)
    }
    Menu(controls_open), ToggleControls -> {
      #(Model(state: Menu(!controls_open)), ui_effect.none())
    }
    _, LoadMenuAssetInfo(load_state) -> {
      case load_state {
        loader.AssetsLoaded(load_results) -> {
          #(model, ui.dispatch_to_tiramisu(LoadBackground(load_results.cache)))
        }
        _ -> #(model, ui_effect.none())
      }
    }
    _, LoadAssetInfo(load_state) -> {
      case load_state {
        loader.LoadProgress(load_progress) -> #(
          Model(state: Loading(option.Some(load_progress))),
          ui_effect.none(),
        )
        loader.AssetsLoaded(load_results) -> #(
          Model(state: Playing(PlayingInfo(0, 0), False, 0)),
          ui.dispatch_to_tiramisu(StartGame(load_results.cache)),
        )
      }
    }
    Playing(_, _, points), WaveCompleteUi(wave_num) -> #(
      Model(state: WaveComplete(wave_num, points)),
      ui_effect.none(),
    )
    Playing(_, _, points), StartWaveUi(new_info)
    | WaveComplete(_, points), StartWaveUi(new_info)
    -> {
      #(Model(state: Playing(new_info, False, points)), ui_effect.none())
    }
    Playing(info, resuming, points), ChangeEnemies(enemy_num) -> #(
      Model(state: Playing(PlayingInfo(info.wave, enemy_num), resuming, points)),
      ui_effect.none(),
    )
    Playing(info, _, points), TogglePause -> #(
      Model(state: Paused(info, False, points)),
      ui.dispatch_to_tiramisu(ToggleGamePause),
    )
    Paused(info, _, points), TogglePause -> #(
      Model(state: Playing(info, True, points)),
      ui.dispatch_to_tiramisu(ToggleGamePause),
    )
    Paused(info, controls_open, points), ToggleControls -> #(
      Model(state: Paused(info, bool.negate(controls_open), points)),
      ui_effect.none(),
    )
    Playing(info, resume, _), UpdatePointsUi(points) -> #(
      Model(state: Playing(info, resume, points)),
      ui_effect.none(),
    )
    Paused(info, controls_open, _), UpdatePointsUi(points) -> #(
      Model(state: Paused(info, controls_open, points)),
      ui_effect.none(),
    )
    WaveComplete(wave_num, _), UpdatePointsUi(points) -> #(
      Model(state: WaveComplete(wave_num, points)),
      ui_effect.none(),
    )
    _, GameOverUi -> #(Model(state: GameOver), ui_effect.none())
    _, BackToMenu -> #(Model(state: Menu(False)), ui_effect.none())
    _, StartLoad
    | _, StartWaveUi(_)
    | _, ChangeEnemies(_)
    | _, TogglePause
    | _, WaveCompleteUi(_)
    | _, ToggleControls
    | _, UpdatePointsUi(_)
    -> #(model, ui_effect.none())
  }
}

fn view_ui(model: Model) -> Element(Msg) {
  html.div([class("overlay")], [
    case model.state {
      Menu(controls_open) -> menu_overlay(controls_open)
      Loading(load_progress) -> loading_overlay(load_progress)
      Playing(playing_info, resuming, points) ->
        game_overlay(playing_info, resuming, points)
      Paused(playing_info, controls_open, points) ->
        paused_overlay(playing_info, controls_open, points)
      WaveComplete(wave_num, points) -> wave_over_overlay(wave_num, points)
      GameOver -> game_over_overlay()
    },
  ])
}

fn menu_overlay(controls_open: Bool) -> Element(Msg) {
  html.div([class("menu-wrapper")], [
    html.div([class("lucy-wrapper")], [
      html.img([class("lucy-menu"), attribute.src("lucy.webp")]),
    ]),
    html.div(
      [class("menu")],
      [
        html.button([class("menu-button"), event.on_click(StartLoad)], [
          html.text("Start Game"),
        ]),
        controls_button(controls_open),
      ]
        |> list.append(case controls_open {
          True -> [
            controls_overlay(),
          ]
          False -> []
        }),
    ),
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

fn game_overlay(
  playing_info: PlayingInfo,
  resuming: Bool,
  points: Int,
) -> Element(Msg) {
  let children = case resuming {
    True -> [
      game_info(playing_info),
      game_buttons(False, False),
      points_overlay(points),
    ]
    False -> [
      game_info(playing_info),
      game_buttons(False, False),
      wave_start_overlay(playing_info.wave),
      points_overlay(points),
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

fn game_over_overlay() -> Element(Msg) {
  html.div([class("main-info-wrapper")], [
    html.div([class("game-over-button-wrapper")], [
      html.h1([class("game-over-text")], [html.text("Game Over!")]),
      html.button([class("game-over-button"), event.on_click(BackToMenu)], [
        html.text("Back to Menu"),
      ]),
      html.button([class("game-over-button"), event.on_click(StartLoad)], [
        html.text("Play Again"),
      ]),
      html.div([class("lucy-wrapper")], [
        html.img([class("lucy-over"), attribute.src("lucy_over.webp")]),
      ]),
    ]),
  ])
}

fn paused_overlay(
  playing_info: PlayingInfo,
  controls_open: Bool,
  points: Int,
) -> Element(Msg) {
  let children =
    [
      game_info(playing_info),
      game_buttons(True, controls_open),
      pause_info_overlay(),
      points_overlay(points),
    ]
    |> list.append(case controls_open {
      True -> [
        controls_overlay(),
      ]
      False -> []
    })
  html.div([], children)
}

fn wave_over_overlay(wave_num: Int, points: Int) -> Element(Msg) {
  html.div([], [
    main_info_overlay("Completed wave " <> int.to_string(wave_num), True),
    points_overlay(points),
  ])
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
      html.div([class("controls-close-button-wrapper")], [
        html.button(
          [class("controls-close-button"), event.on_click(ToggleControls)],
          [html.img([class("close-button"), attribute.src("close_icon.svg")])],
        ),
      ]),
      html.h2([], [html.text("Game")]),
      html.div([], [html.text("Defend your diamond towers!")]),
      html.br([]),
      html.div([], [
        html.text("Use WASD to move around, press space to fire at the enemies"),
      ]),
      html.div([], [
        html.text(
          "Use Enter to activate the buttons in world. Some of them cost points to activate. ",
        ),
        html.text(
          "You gain points from destroying enemies and completing waves. Check them in the top left",
        ),
      ]),
    ]),
  ])
}

fn points_overlay(points: Int) -> Element(Msg) {
  html.div([class("points-info-wrapper")], [
    html.div([class("points")], [html.text("Points: " <> int.to_string(points))]),
  ])
}

pub type GameModel {
  GameModel(
    state: GameState,
    background: GameBackground,
    asset_cache: option.Option(asset.AssetCache),
  )
}

pub type GameState {
  /// Just in the menu, outside of the game
  GameMenu
  /// Playing the game
  GamePlaying(game.Model)
  /// Paused game
  GamePaused(game.Model)
}

pub type GameBackground {
  GameBackground(stars: List(BackgroundStar))
}

pub type BackgroundStar {
  BackgroundStar(
    x: Float,
    y: Float,
    size: Float,
    rotation_x: Float,
    rotation_y: Float,
    rotation_z: Float,
    pos_dir_x: Bool,
  )
}

fn generate_background() -> GameBackground {
  let star_num = 400
  list.range(1, star_num)
  |> list.map(fn(_) {
    BackgroundStar(
      float.random() *. 3000.0 -. 1500.0,
      float.random() *. 3000.0 -. 1500.0,
      float.random() *. 0.7 +. 0.5,
      utils.random_angle(),
      utils.random_angle(),
      utils.random_angle(),
      utils.random_bool(),
    )
  })
  |> GameBackground()
}

pub type GameMsg {
  StartGame(asset.AssetCache)
  GameMsg(game.Msg)
  LoadBackground(asset.AssetCache)
  ToggleGamePause
  EndGame
  Tick
}

pub fn init(
  _ctx: tiramisu.Context(String),
) -> #(GameModel, Effect(GameMsg), option.Option(_)) {
  #(
    GameModel(GameMenu, generate_background(), option.None),
    effect.tick(Tick),
    option.None,
  )
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
      #(GameModel(..model, state: GamePlaying(game_model)), effect)
    }
    GamePlaying(_), GameMsg(game.UpdateGui(gui_info)) -> {
      let playing_info = case gui_info {
        game.NewWaveUi(new_wave, enemy_count) ->
          StartWaveUi(PlayingInfo(new_wave, enemy_count))
        game.EnemiesAmount(enemy_count) -> ChangeEnemies(enemy_count)
        game.EndWaveUi(wave_end) -> WaveCompleteUi(wave_end)
        game.UpdatePoints(point_num) -> UpdatePointsUi(point_num)
      }
      #(model, ui.dispatch_to_lustre(playing_info))
    }
    GamePlaying(game_model), GameMsg(game.GameMsg(msg)) -> {
      let #(game_model, game_effect, _physics) =
        game.update(game_model, msg, ctx)
      let effect = effect.map(game_effect, fn(e) { GameMsg(e) })
      #(GameModel(..model, state: GamePlaying(game_model)), effect)
    }
    GamePlaying(_), GameMsg(game.GameOver) -> {
      #(GameModel(..model, state: GameMenu), ui.dispatch_to_lustre(GameOverUi))
    }
    GamePlaying(game_model), ToggleGamePause -> #(
      GameModel(..model, state: GamePaused(game_model)),
      effect.none(),
    )
    GamePaused(game_model), ToggleGamePause -> {
      let effect = game.resume()
      let effect = effect.map(effect, fn(e) { GameMsg(e) })
      #(GameModel(..model, state: GamePlaying(game_model)), effect)
    }
    _, EndGame -> {
      #(GameModel(..model, state: GameMenu), ui.dispatch_to_lustre(GameOverUi))
    }
    _, LoadBackground(asset_cache) -> #(
      GameModel(..model, asset_cache: option.Some(asset_cache)),
      effect.none(),
    )
    _, Tick -> {
      let background_stars =
        model.background.stars
        |> list.map(fn(star) {
          BackgroundStar(
            ..star,
            rotation_z: star.rotation_z
              +. float.random()
              *. 0.1
              *. case star.pos_dir_x {
                True -> 1.0
                False -> -1.0
              },
            rotation_y: star.rotation_y +. float.random() *. 0.1,
          )
        })
      #(
        GameModel(..model, background: GameBackground(background_stars)),
        effect.tick(Tick),
      )
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
  let background_nodes = case model.asset_cache {
    option.Some(asset_cache) -> {
      case asset_cache |> asset.get_model(loader.background_star_asset) {
        Ok(star_model) -> {
          let star_transforms =
            model.background.stars
            |> list.map(fn(star_info) {
              transform.at(vec3.Vec3(star_info.x, star_info.y, -10.0))
              |> transform.with_euler_rotation(vec3.Vec3(
                star_info.rotation_x,
                star_info.rotation_y,
                star_info.rotation_z,
              ))
              |> transform.with_scale(vec3.Vec3(
                star_info.size,
                star_info.size,
                1.0,
              ))
            })
          [
            scene.instanced_model(
              id: "BackgroundStars",
              object: star_model.scene,
              instances: star_transforms,
              physics: option.None,
              material: option.None,
            ),
          ]
        }
        Error(_) -> []
      }
    }
    option.None -> []
  }

  case model.state {
    GameMenu -> {
      let cam =
        camera.camera_2d(
          width: float.round(ctx.canvas_width),
          height: float.round(ctx.canvas_height),
        )
      let assert Ok(light) = light.ambient(intensity: 0.5, color: 0xffffff)
      scene.empty(
        id: "Scene",
        transform: transform.identity,
        children: [
          scene.camera(
            id: "camera",
            camera: cam,
            transform: transform.at(position: vec3.Vec3(0.0, 0.0, 100.0)),
            look_at: option.None,
            active: True,
            viewport: option.None,
            postprocessing: option.None,
          ),
          scene.light(id: "Light", light: light, transform: transform.identity),
        ]
          |> list.append(background_nodes),
      )
    }

    GamePlaying(game_model) | GamePaused(game_model) ->
      game.view(game_model, ctx, background_nodes)
  }
}
