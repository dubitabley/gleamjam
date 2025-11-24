import gleam/int
import gleam/option
import tiramisu/geometry
import tiramisu/material
import tiramisu/scene
import tiramisu/transform
import vec/vec3

pub fn view_health_bar(
  id id: String,
  health health: Int,
  max_health max_health: Int,
  position position: vec3.Vec3(Float),
  width width: Float,
) -> scene.Node(String) {
  let assert Ok(plane_geometry) = geometry.plane(1.0, 1.0)
  let assert Ok(border_material) =
    material.basic(
      color: 0x444444,
      transparent: False,
      opacity: 1.0,
      map: option.None,
    )
  let border =
    scene.mesh(
      id: id <> "HealthBarBorder",
      geometry: plane_geometry,
      material: border_material,
      transform: transform.at(vec3.Vec3(0.0, 0.0, 10.0))
        |> transform.with_scale(vec3.Vec3(width +. 1.0, 2.0, 1.0)),
      physics: option.None,
    )
  let assert Ok(health_material) =
    material.basic(
      color: 0xff0000,
      transparent: False,
      opacity: 1.0,
      map: option.None,
    )
  let health_fraction = int.to_float(health) /. int.to_float(max_health)
  // set to left
  let health_bar_pos = { health_fraction /. 2.0 -. 0.5 } *. width
  let health_bar =
    scene.mesh(
      id: id <> "HealthBar",
      geometry: plane_geometry,
      material: health_material,
      transform: transform.at(vec3.Vec3(health_bar_pos, 0.0, 11.0))
        |> transform.with_scale(vec3.Vec3(health_fraction *. width, 1.0, 1.0)),
      physics: option.None,
    )
  scene.empty(
    id: id <> "HealthBarGroup",
    transform: transform.at(position)
      |> transform.with_scale(vec3.Vec3(5.0, 5.0, 1.0)),
    children: [border, health_bar],
  )
}
