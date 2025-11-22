import gleam/int
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
import vec/vec3

const diamond_asset: String = "diamond.webp"

pub type TowerModel {
  TowerModel(towers: List(Tower), texture: option.Option(asset.Texture))
}

pub type Tower {
  Tower(x: Float, y: Float, health: Int)
}

pub type TowerMsg {
  TextureLoaded(asset.Texture)
  ErrorMessage(String)
}

pub fn init() -> #(TowerModel, Effect(TowerMsg)) {
  let load_texture_effect =
    asset.load_texture(diamond_asset)
    |> promise.map(fn(result) {
      case result {
        Ok(texture) -> TextureLoaded(texture)
        Error(_) -> ErrorMessage("Couldn't load diamond texture")
      }
    })
    |> effect.from_promise

  #(
    TowerModel(towers: generate_towers(), texture: option.None),
    load_texture_effect,
  )
}

const tower_dist: Float = 200.0

fn generate_towers() -> List(Tower) {
  [
    Tower(0.0, 0.0 -. tower_dist, 100),
    Tower(tower_dist, 0.0, 100),
    Tower(0.0, tower_dist, 100),
    Tower(0.0 -. tower_dist, 0.0, 100),
  ]
}

pub fn update(
  model: TowerModel,
  msg: TowerMsg,
) -> #(TowerModel, Effect(TowerMsg)) {
  case msg {
    TextureLoaded(texture) -> #(
      TowerModel(..model, texture: option.Some(texture)),
      effect.none(),
    )
    ErrorMessage(error) -> {
      io.print_error(error)
      #(model, effect.none())
    }
  }
}

pub fn view(model: TowerModel) -> scene.Node(String) {
  let assert Ok(sprite_geom) = geometry.plane(width: 100.0, height: 100.0)
  let assert Ok(sprite_mat) =
    material.basic(
      // diamond colour
      color: 0xffffff,
      transparent: True,
      opacity: 1.0,
      map: model.texture,
    )
  let children =
    list.index_map(model.towers, fn(tower, index) {
      scene.mesh(
        id: "Tower" <> int.to_string(index),
        geometry: sprite_geom,
        material: sprite_mat,
        transform: transform.at(position: vec3.Vec3(tower.x, tower.y, 0.0))
          |> transform.with_euler_rotation(vec3.Vec3(0.0, 0.0, 0.0))
          |> transform.with_scale(vec3.Vec3(2.0, 2.0, 1.0)),
        physics: option.None,
      )
    })
  scene.empty(id: "Towers", transform: transform.identity, children: children)
}
