import gleam/float
import gleam/result

pub fn hypot(x: Float, y: Float) -> Float {
  float.square_root(x *. x +. y *. y)
  |> result.unwrap(0.0)
}

pub type PointWithDirection {
  PointWithDirection(x: Float, y: Float, direction: Float)
}
