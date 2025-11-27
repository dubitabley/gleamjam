//// Stuff for handling the ui in game in the world
//// That the player moves over

import gleam/int
import gleam/list
import gleam/option
import loader
import tiramisu/asset
import tiramisu/geometry
import tiramisu/material
import tiramisu/scene
import tiramisu/transform
import utils
import vec/vec3

pub type Model(effect_type) {
  Model(buttons: List(Button(effect_type)))
}

pub type Button(effect_type) {
  Button(
    x: Float,
    y: Float,
    width: Float,
    height: Float,
    text: String,
    enabled: Bool,
    on_click: effect_type,
  )
}

pub fn init() -> Model(effect_type) {
  Model(buttons: [])
}

pub fn check_player_collisions(
  model: Model(effect_type),
  player_rect: utils.Rectangle,
) -> Model(effect_type) {
  let buttons =
    model.buttons
    |> list.map(fn(button) {
      let button_rect =
        utils.Rectangle(button.x, button.y, button.width, button.height)
      let enabled = utils.check_collision_rect_rect(player_rect, button_rect)
      Button(..button, enabled: enabled)
    })
  Model(buttons)
}

pub fn get_effect_collisions(model: Model(effect_type)) -> List(effect_type) {
  model.buttons
  |> list.filter_map(fn(button) {
    case button.enabled {
      True -> Ok(button.on_click)
      False -> Error(0)
    }
  })
}

pub fn view_buttons(
  buttons: List(Button(effect_type)),
  asset_cache: asset.AssetCache,
) -> List(scene.Node(String)) {
  let assert Ok(geometry) = geometry.plane(1.0, 1.0)

  let assert Ok(arial_font) =
    asset.get_font(asset_cache, loader.arial_font_asset)
  let assert Ok(text_material) =
    material.basic(
      color: 0xffaaaa,
      transparent: False,
      opacity: 1.0,
      map: option.None,
    )

  buttons
  |> list.index_map(fn(button, index) {
    let colour = case button.enabled {
      True -> 0xffffff
      False -> 0x000000
    }
    let assert Ok(material) =
      material.basic(
        color: colour,
        transparent: False,
        opacity: 1.0,
        map: option.None,
      )
    let assert Ok(text_geom) =
      geometry.text(
        text: button.text,
        font: arial_font,
        size: 10.0,
        depth: 0.0,
        curve_segments: 10,
        bevel_enabled: False,
        bevel_thickness: 1.0,
        bevel_size: 1.0,
        bevel_offset: 1.0,
        bevel_segments: 1,
      )
    scene.empty(
      id: "WorldButtonWrapper" <> int.to_string(index),
      transform: transform.at(vec3.Vec3(button.x, button.y, 1.0))
        |> transform.with_scale(vec3.Vec3(button.width, button.height, 1.0)),
      children: [
        scene.mesh(
          id: "WorldButton" <> int.to_string(index),
          geometry: geometry,
          material: material,
          transform: transform.identity,
          physics: option.None,
        ),
        scene.mesh(
          id: "WorldButtonText" <> int.to_string(index),
          geometry: text_geom,
          material: text_material,
          transform: transform.at(vec3.Vec3(-0.45, -0.25, 1.0))
            |> transform.with_scale(vec3.Vec3(0.013, 0.04, 1.0)),
          physics: option.None,
        ),
      ],
    )
  })
}

pub fn view(
  model: Model(effect_type),
  asset_cache: asset.AssetCache,
) -> scene.Node(String) {
  let buttons = view_buttons(model.buttons, asset_cache)
  scene.empty(
    id: "WorldUIScene",
    transform: transform.identity,
    children: buttons,
  )
}
