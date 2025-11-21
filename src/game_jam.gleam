/// 2D Game Example - Orthographic Camera
import gleam/float
import gleam/option
import tiramisu
import tiramisu/background
import tiramisu/camera
import tiramisu/effect.{type Effect}
import tiramisu/geometry
import tiramisu/light
import tiramisu/material
import tiramisu/scene
import tiramisu/transform
import vec/vec3

pub type Model {
  Model(time: Float)
}

pub type Msg {
  Tick
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

fn init(_ctx: tiramisu.Context(String)) -> #(Model, Effect(Msg), option.Option(_)) {
  #(Model(time: 0.0), effect.tick(Tick), option.None)
}

fn update(
  model: Model,
  msg: Msg,
  ctx: tiramisu.Context(String),
) -> #(Model, Effect(Msg), option.Option(_)) {
  case msg {
    Tick -> {
      let new_time = model.time +. ctx.delta_time /. 1000.0
      #(Model(time: new_time), effect.tick(Tick), option.None)
    }
  }
}

fn view(model: Model, ctx: tiramisu.Context(String)) -> scene.Node(String) {
  let cam = camera.camera_2d(
    width: float.round(ctx.canvas_width),
    height: float.round(ctx.canvas_height),
  )
  let assert Ok(sprite_geom) = geometry.plane(width: 50.0, height: 50.0)
  let assert Ok(sprite_mat) = material.basic(color: 0xff0066, transparent: False, opacity: 1.0, map: option.None)

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
    scene.mesh(
      id: "sprite",
      geometry: sprite_geom,
      material: sprite_mat,
      transform:
        transform.at(position: vec3.Vec3(0.0, 0.0, 0.0))
        |> transform.with_euler_rotation(vec3.Vec3(0.0, 0.0, model.time)),
      physics: option.None,
    ),
  ])
}
