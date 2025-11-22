// stuff for handling the player
import gleam/io
import gleam/javascript/promise
import gleam/list
import gleam/option
import tiramisu/asset
import tiramisu/effect.{type Effect}
import tiramisu/geometry
import tiramisu/material
import tiramisu/scene
import tiramisu/transform
import vec/vec2
import vec/vec3

// sprite for player
const lucy_asset: String = "lucy.webp"

// consts
const size: Float = 100.0

pub type PlayerModel {
  PlayerModel(x: Float, y: Float, texture: option.Option(asset.Texture))
}

pub type Movement {
  Keys(up: Bool, down: Bool, left: Bool, right: Bool)
}

pub type PlayerMsg {
  TextureLoaded(asset.Texture)
  ErrorMessage(String)
}

pub fn init() -> #(PlayerModel, Effect(PlayerMsg)) {
  let load_texture_effect =
    asset.load_texture(lucy_asset)
    |> promise.map(fn(result) {
      case result {
        Ok(texture) -> TextureLoaded(texture)
        Error(_) -> ErrorMessage("Couldn't load texture")
      }
    })
    |> effect.from_promise
  #(PlayerModel(0.0, 0.0, option.None), load_texture_effect)
}

pub fn update(
  model: PlayerModel,
  msg: PlayerMsg,
) -> #(PlayerModel, Effect(PlayerMsg)) {
  case msg {
    TextureLoaded(texture) -> #(
      PlayerModel(..model, texture: option.Some(texture)),
      effect.none(),
    )
    ErrorMessage(error) -> {
      io.print_error(error)
      #(model, effect.none())
    }
  }
}

pub fn move(model: PlayerModel, movement: Movement) -> PlayerModel {
  let x = add_input(model.x, movement.left, movement.right, 3.0)
  let y = add_input(model.y, movement.up, movement.down, 3.0)
  PlayerModel(..model, x: x, y: y)
}

pub type PlayerPoint {
  PlayerPoint(x: Float, y: Float, direction: Float)
}

pub fn get_points(model: PlayerModel) -> List(PlayerPoint) {
  let points = [
    PlayerPoint(-0.05 *. size, 0.47 *. size, -0.24),
    PlayerPoint(0.45 *. size, 0.21 *. size, 1.17),
    PlayerPoint(0.36 *. size, -0.39 *. size, 2.36),
    PlayerPoint(-0.18 *. size, -0.47 *. size, -2.5),
    PlayerPoint(-0.45 *. size, 0.05 *. size, -1.42),
  ]
  list.map(points, fn(x) { add_point(model.x, model.y, x) })
}

fn add_point(x: Float, y: Float, point: PlayerPoint) -> PlayerPoint {
  PlayerPoint(point.x +. x, point.y +. y, point.direction)
}

fn add_input(val: Float, neg: Bool, pos: Bool, offset: Float) -> Float {
  case neg, pos {
    False, False | True, True -> val
    False, True -> val +. offset
    True, False -> val -. offset
  }
}

pub fn view(player: PlayerModel) -> scene.Node(String) {
  let assert Ok(sprite_geom) = geometry.plane(width: size, height: size)
  let assert Ok(sprite_mat) =
    material.basic(
      // lucy pink colour
      color: 0xffaff3,
      transparent: True,
      opacity: 1.0,
      map: player.texture,
    )

  scene.mesh(
    id: "sprite",
    geometry: sprite_geom,
    material: sprite_mat,
    transform: transform.at(position: vec3.Vec3(player.x, player.y, 1.0)),
    physics: option.None,
  )
}
