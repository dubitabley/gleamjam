// stuff for handling the player
import gleam/io
import gleam/javascript/promise
import gleam/option
import tiramisu/asset
import tiramisu/effect.{type Effect}
import tiramisu/geometry
import tiramisu/material
import tiramisu/scene
import tiramisu/transform
import vec/vec3

// sprite for player
const lucy_asset: String = "lucy.webp"

pub type PlayerModel {
  PlayerModel(x: Float, y: Float, texture: option.Option(asset.Texture))
}

pub type Movement {
  Keys(up: Bool, down: Bool, left: Bool, right: Bool)
}

pub type PlayerMsg {
  TextureLoaded(asset.Texture)
  ErrorMessage(String)
  PlayerMove(Movement)
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
    PlayerMove(movement) -> {
      let x = add_input(model.x, movement.left, movement.right, 3.0)
      let y = add_input(model.y, movement.up, movement.down, 3.0)
      #(PlayerModel(..model, x: x, y: y), effect.none())
    }
  }
}

fn add_input(val: Float, neg: Bool, pos: Bool, offset: Float) -> Float {
  case neg, pos {
    False, False | True, True -> val
    False, True -> val +. offset
    True, False -> val -. offset
  }
}

pub fn player_view(player: PlayerModel) -> scene.Node(String) {
  let assert Ok(sprite_geom) = geometry.plane(width: 50.0, height: 50.0)
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
    transform: transform.at(position: vec3.Vec3(player.x, player.y, 0.0))
      |> transform.with_euler_rotation(vec3.Vec3(0.0, 0.0, 0.0))
      |> transform.with_scale(vec3.Vec3(2.0, 2.0, 1.0)),
    physics: option.None,
  )
}
