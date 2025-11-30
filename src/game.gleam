import boss
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
import tiramisu/spritesheet
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
    boss: option.Option(boss.Model),
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
  WinGame
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
      boss: option.None,
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
      let #(enemy_model, boss_model) = start_wave(new_wave, model.time)

      // update gui
      let enemy_count = list.length(enemy_model.enemies)
      let new_wave_info = NewWaveUi(new_wave, enemy_count)
      #(
        Model(
          ..model,
          enemies: enemy_model,
          boss: boss_model,
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
    let next_level = case tower.cannon {
      option.Some(cannon) -> cannon.level + 1
      option.None -> 1
    }
    let level_cost = tower.get_cannon_level_cost(next_level)
    world_ui.Button(
      x,
      y,
      80.0,
      80.0,
      world_ui.ButtonText("+"),
      level_cost,
      False,
      UpgradeTower(TowerUpgradeInfo(tower.id)),
    )
  })
}

fn start_wave(
  wave_num: Int,
  time: Float,
) -> #(enemy.EnemyModel, option.Option(boss.Model)) {
  let enemy_count = case wave_num {
    1 -> 2
    2 -> 5
    3 -> 9
    4 -> 14
    5 -> 7
    _ -> wave_num * wave_num
  }
  let new_enemies =
    list.range(0, enemy_count - 1)
    |> list.map(fn(index) {
      let #(x, y) = get_enemy_position(index, enemy_count)
      enemy.create_enemy(x, y, time)
    })

  let boss = case wave_num >= 5 {
    True -> option.Some(boss.init())
    False -> option.None
  }
  #(enemy.EnemyModel(enemies: new_enemies), boss)
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
  let player_model = player.set_move(model.player, player_movement)

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

  let #(towers, tower_shots) =
    tick_towers(model.tower.towers, enemy_model.enemies, model.time)
  let shot_model = shot.ShotModel(shot_model.shots |> list.append(tower_shots))
  let tower_model = tower.TowerModel(towers)

  // this is atrocious, i really should've used messages for more of this to avoid this spaghetti
  let #(boss_model, tower_model, player_model, boss_effect) = case model.boss {
    option.Some(boss_model) -> {
      let new_boss =
        tick_boss_state(boss_model, tower_model, player_model, model.time)
      case new_boss.state {
        boss.Dying(dying_start_time)
          if model.time >. dying_start_time +. boss.dying_time
        -> {
          #(
            option.Some(new_boss),
            tower_model,
            player_model,
            effect.from(fn(dispatch) { dispatch(WinGame) }),
          )
        }
        boss.Blasting(
          start_time,
          animation,
          animation_state,
          blast_angle,
          last_damage_time,
        ) -> {
          case boss.should_check_damage(model.time, last_damage_time) {
            True -> {
              let blast_rect =
                utils.Rectangle(
                  boss_model.x,
                  boss_model.y,
                  boss.blast_width,
                  boss.blast_height,
                )
              let player_rect =
                utils.Rectangle(
                  player_model.x,
                  player_model.y,
                  player.size,
                  player.size,
                )
              case
                utils.check_collision_rotated_rectangles(
                  blast_rect,
                  blast_angle,
                  player_rect,
                  0.0,
                )
              {
                True -> {
                  let new_boss_state =
                    boss.Blasting(
                      start_time,
                      animation,
                      animation_state,
                      blast_angle,
                      option.Some(model.time),
                    )
                  let new_boss = boss.Model(..new_boss, state: new_boss_state)
                  let player_health = model.player.health - boss.blast_damage
                  let player_model =
                    player.PlayerModel(..player_model, health: player_health)

                  // AAAAAAAAAAAAAAAAAAAAA
                  let effect = case player_health <= 0 {
                    True -> effect.from(fn(dispatch) { dispatch(GameOver) })
                    False -> effect.none()
                  }
                  #(option.Some(new_boss), tower_model, player_model, effect)
                }
                False -> #(
                  option.Some(new_boss),
                  tower_model,
                  player_model,
                  effect.none(),
                )
              }
            }
            False -> #(
              option.Some(new_boss),
              tower_model,
              player_model,
              effect.none(),
            )
          }
        }
        _ -> #(option.Some(new_boss), tower_model, player_model, effect.none())
      }
    }
    option.None -> #(model.boss, tower_model, player_model, effect.none())
  }

  let new_time = model.time +. ctx.delta_time /. 1000.0

  let model =
    Model(
      ..model,
      tower: tower_model,
      enemies: enemy_model,
      player: player_model,
      camera_position: vec2.Vec2(player_model.x, player_model.y),
      shots: shot_model,
      boss: boss_model,
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
      boss_effect,
    ]),
  )
}

fn tick_boss_state(
  boss_model: boss.Model,
  towers: tower.TowerModel,
  player: player.PlayerModel,
  time: Float,
) -> boss.Model {
  let boss_model = case boss_model.state {
    // this is just a default state, pick a new state
    boss.Idle -> {
      new_boss_state(boss_model, towers, player, time)
    }
    boss.Replicating(start_time) -> {
      // just waiting
      case time >. start_time +. boss.replication_time {
        True -> new_boss_state(boss_model, towers, player, time)
        False -> boss_model
      }
    }
    boss.Blasting(
      start_time,
      animation,
      animation_state,
      angle,
      last_damage_time,
    ) -> {
      case time >. start_time +. boss.blast_time {
        True -> new_boss_state(boss_model, towers, player, time)
        False -> {
          let sprite_state =
            spritesheet.update(
              state: animation_state,
              animation: animation,
              delta_time: 0.01,
            )

          let new_state =
            boss.Blasting(
              start_time,
              animation,
              sprite_state,
              angle,
              last_damage_time,
            )
          boss.Model(..boss_model, state: new_state)
        }
      }
    }
    boss.Moving(target_x, target_y, last_move_time) -> {
      // stagger the movement to make it look glitchy and jagged
      case time >. last_move_time +. boss.move_time {
        True -> {
          let angle =
            maths.atan2(target_y -. boss_model.y, target_x -. boss_model.x)
          let distance =
            utils.hypot(boss_model.y -. target_y, boss_model.x -. target_x)

          case distance <=. boss.move_dist {
            True -> {
              // hit target, move and get new state
              let boss_model =
                boss.Model(..boss_model, x: target_x, y: target_y)
              new_boss_state(boss_model, towers, player, time)
            }
            False -> {
              let new_x = boss_model.x +. maths.cos(angle) *. boss.move_dist
              let new_y = boss_model.y +. maths.sin(angle) *. boss.move_dist
              let state =
                boss.Moving(
                  target_x: target_x,
                  target_y: target_y,
                  last_move_time: time,
                )
              boss.Model(..boss_model, x: new_x, y: new_y, state: state)
            }
          }
        }
        False -> boss_model
      }
    }
    // don't handle this here
    boss.Dying(_) -> boss_model
  }
  // move all the textures around
  boss.tick_textures(boss_model)
}

fn new_boss_state(
  boss_model: boss.Model,
  towers: tower.TowerModel,
  player: player.PlayerModel,
  time: Float,
) -> boss.Model {
  // replicate is top priority
  let stage = boss.replication_health_stage(boss_model.health)
  case stage > boss_model.stage {
    True -> {
      let boss_model = boss.replicate(boss_model)
      boss.Model(..boss_model, state: boss.Replicating(time))
    }
    False -> {
      // just start blasting if we're close enough
      // target tower first
      let closest_tower =
        towers.towers
        |> list.fold(option.None, fn(accum, tower) {
          let distance =
            utils.hypot(tower.y -. boss_model.y, tower.x -. boss_model.x)
          case accum {
            option.Some(#(_existing_tower, existing_distance)) ->
              case distance <. existing_distance {
                True -> option.Some(#(tower, distance))
                False -> accum
              }
            option.None -> option.Some(#(tower, distance))
          }
        })

      case closest_tower {
        option.Some(#(tower, distance)) if distance <=. boss.max_blast_distance -> {
          let angle =
            maths.atan2(boss_model.y -. tower.y, boss_model.x -. tower.x)
          let #(anim, anim_state) = boss.setup_blast_animation()
          let state = boss.Blasting(time, anim, anim_state, angle, option.None)
          boss.Model(..boss_model, state: state)
        }
        _ -> {
          let player_distance =
            utils.hypot(player.y -. boss_model.y, player.x -. boss_model.x)
          case player_distance <=. boss.max_blast_distance {
            True -> {
              let angle =
                maths.atan2(player.y -. boss_model.y, player.x -. boss_model.x)
              let #(anim, anim_state) = boss.setup_blast_animation()
              let state =
                boss.Blasting(time, anim, anim_state, angle, option.None)
              boss.Model(..boss_model, state: state)
            }
            False -> {
              // move towards tower if it exists
              case closest_tower {
                option.Some(#(tower, _)) -> {
                  let angle =
                    maths.atan2(
                      tower.y -. boss_model.y,
                      tower.x -. boss_model.x,
                    )
                    +. float.random()
                    *. 0.6
                    -. 0.3
                  let move_dist = float.random() *. 50.0 +. 50.0
                  let target_x = boss_model.x +. maths.cos(angle) *. move_dist
                  let target_y = boss_model.y +. maths.sin(angle) *. move_dist
                  let state = boss.Moving(target_x, target_y, time)
                  boss.Model(..boss_model, state: state)
                }
                option.None -> {
                  // move towards player
                  let angle =
                    maths.atan2(
                      boss_model.y -. player.y,
                      boss_model.x -. player.x,
                    )
                    +. float.random()
                    *. 0.6
                    -. 0.3
                  let move_dist = float.random() *. 50.0 +. 50.0
                  let target_x = boss_model.x +. maths.cos(angle) *. move_dist
                  let target_y = boss_model.y +. maths.sin(angle) *. move_dist
                  let state = boss.Moving(target_x, target_y, time)
                  boss.Model(..boss_model, state: state)
                }
              }
            }
          }
        }
      }
    }
  }
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
      let damage_num =
        tower_collisions
        |> list.filter(fn(collision) { collision.0 == tower })
        |> list.fold(0, fn(a, collision) { a + { collision.1 }.damage })
      let new_health = tower.health - damage_num
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

  let shot_damage =
    shots_player_collisions |> list.fold(0, fn(acc, shot) { acc + shot.damage })

  let player_health = model.player.health - shot_damage
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
      let damage_num =
        collisions
        |> list.filter(fn(collision) { collision.0 == enemy })
        |> list.fold(0, fn(a, collision) { a + { collision.1 }.damage })
      let new_health = enemy.health - damage_num
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

  let effect = case
    start_enemy_count - end_enemy_count,
    end_enemy_count == 0 && model.boss |> option.is_none()
  {
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

  // check boss collision
  let #(shots, boss) = case model.boss {
    option.Some(boss) -> {
      case boss.state {
        boss.Dying(_) -> #(shots, option.Some(boss))
        _ -> {
          let boss_shot_collisions =
            shots
            |> list.filter(shot.is_player)
            |> list.filter(fn(shot) { check_collision_boss_shot(boss, shot) })
          let total_damage =
            boss_shot_collisions
            |> list.fold(0, fn(acc, shot) { acc + shot.damage })
          let new_health = boss.health - total_damage
          let new_shots = shots |> utils.list_filter(boss_shot_collisions)
          let boss_state = case new_health <= 0 {
            True -> boss.Dying(model.time)
            False -> boss.state
          }
          let boss = boss.Model(..boss, state: boss_state, health: new_health)
          #(new_shots, option.Some(boss))
        }
      }
    }
    option.None -> #(shots, option.None)
  }

  #(
    Model(
      ..model,
      boss: boss,
      shots: shot.ShotModel(shots),
      enemies: enemy.EnemyModel(enemies),
    ),
    effect,
  )
}

fn tick_towers(
  towers: List(tower.Tower),
  enemies: List(enemy.Enemy),
  time: Float,
) -> #(List(tower.Tower), List(shot.Shot)) {
  let #(towers, shots) =
    towers
    |> list.map(fn(tower) {
      case tower.cannon {
        option.Some(cannon) -> {
          case cannon.state {
            tower.CannonIdle -> {
              let new_state = choose_new_cannon_state(tower, cannon, enemies)
              let cannon = tower.Cannon(..cannon, state: new_state)
              #(tower.Tower(..tower, cannon: option.Some(cannon)), [])
            }
            tower.CannonRotating(target_rotation) -> {
              let angle_diff = target_rotation -. cannon.rotation
              let abs_angle_diff = angle_diff |> float.absolute_value()
              case abs_angle_diff <. 0.05 {
                True -> {
                  let new_state = tower.CannonShooting(time)
                  let cannon = tower.Cannon(..cannon, state: new_state)
                  let cannon_x = tower.x +. cannon.x
                  let cannon_y = tower.y +. cannon.y
                  let cannon_damage = tower.get_cannon_damage(cannon.level)
                  let new_shot =
                    shot.create_tower_shot(
                      utils.PointWithDirection(
                        cannon_x,
                        cannon_y,
                        cannon.rotation,
                      ),
                      0xdddddd,
                      cannon_damage,
                      time,
                    )
                  #(tower.Tower(..tower, cannon: option.Some(cannon)), [
                    new_shot,
                  ])
                }
                False -> {
                  // rotate towards
                  let rotation = case angle_diff <. 0.05 {
                    True -> cannon.rotation -. 0.05
                    False -> cannon.rotation +. 0.05
                  }
                  let cannon = tower.Cannon(..cannon, rotation: rotation)
                  #(tower.Tower(..tower, cannon: option.Some(cannon)), [])
                }
              }
            }
            tower.CannonShooting(start_time) -> {
              case time >. { start_time +. 1.0 } {
                True -> {
                  let new_state =
                    choose_new_cannon_state(tower, cannon, enemies)
                  let cannon = tower.Cannon(..cannon, state: new_state)
                  #(tower.Tower(..tower, cannon: option.Some(cannon)), [])
                }
                False -> #(tower, [])
              }
            }
          }
        }
        option.None -> #(tower, [])
      }
    })
    |> list.unzip()

  #(towers, shots |> list.flatten())
}

fn choose_new_cannon_state(
  tower: tower.Tower,
  cannon: tower.Cannon,
  enemies: List(enemy.Enemy),
) {
  case get_closest_enemy_cannon(tower, cannon, enemies) {
    option.Some(enemy) -> {
      let cannon_x = cannon.x +. tower.x
      let cannon_y = cannon.y +. tower.y

      // get angle we should be at
      let target_angle = maths.atan2(enemy.y -. cannon_y, enemy.x -. cannon_x)
      tower.CannonRotating(target_angle)
    }
    option.None -> tower.CannonIdle
  }
}

fn get_closest_enemy_cannon(
  tower: tower.Tower,
  cannon: tower.Cannon,
  enemies: List(enemy.Enemy),
) -> option.Option(enemy.Enemy) {
  let cannon_x = tower.x +. cannon.x
  let cannon_y = tower.y +. cannon.y
  enemies
  |> list.fold(option.None, fn(accum, enemy) {
    // gotta be within a cone of the cannon's initial rotation
    // and within a certain distance
    let range = tower.get_cannon_range(cannon.level)
    let distance = utils.hypot(enemy.y -. cannon_y, enemy.x -. cannon_x)
    case distance <=. range {
      True -> {
        let angle_towards =
          maths.atan2(enemy.y -. cannon_y, enemy.x -. cannon_x)
        let angle_diff =
          { angle_towards -. cannon.initial_rotation } |> float.absolute_value()
        let cannon_max_rotation = tower.get_cannon_rotation(cannon.level)
        case angle_diff <. cannon_max_rotation {
          True -> {
            case accum {
              option.Some(#(_, existing_distance)) -> {
                case distance <. existing_distance {
                  True -> option.Some(#(enemy, distance))
                  False -> accum
                }
              }
              option.None -> option.Some(#(enemy, distance))
            }
          }
          False -> accum
        }
      }
      False -> accum
    }
  })
  |> option.map(fn(value) { value.0 })
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

fn check_collision_boss_shot(boss_model: boss.Model, shot: shot.Shot) -> Bool {
  let boss_rect =
    utils.Rectangle(
      boss_model.x,
      boss_model.y,
      boss_model.width,
      boss_model.height,
    )
  let shot_circle = utils.Circle(shot.x, shot.y, shot.size)
  utils.check_collision_circle_rect(shot_circle, boss_rect)
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
          100.0,
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
      |> list.append(case model.boss {
        option.Some(boss_model) -> [boss.view(boss_model, model.asset_cache)]
        option.None -> []
      })
      |> list.append(background),
  )
}
