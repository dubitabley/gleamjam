import gleam/bool
import gleam/float
import gleam/list
import gleam/result

pub fn hypot(x: Float, y: Float) -> Float {
  float.square_root(x *. x +. y *. y)
  |> result.unwrap(0.0)
}

pub type PointWithDirection {
  PointWithDirection(x: Float, y: Float, direction: Float)
}

pub fn second_tuple(tuple: #(value1, value2)) -> value2 {
  tuple.1
}

/// returns a list of objects that exist in list but not in list2
pub fn list_filter(list1: List(value1), list2: List(value1)) -> List(value1) {
  list1 |> list.filter(fn(val) { list.contains(list2, val) |> bool.negate })
}

pub type Circle {
  Circle(x: Float, y: Float, radius: Float)
}

pub type Rectangle {
  Rectangle(x: Float, y: Float, width: Float, height: Float)
}

pub fn check_collision_circles(circle1: Circle, circle2: Circle) -> Bool {
  let distance = hypot(circle1.y -. circle2.y, circle1.x -. circle2.x)
  distance <. circle1.radius +. circle2.radius
}

// https://stackoverflow.com/questions/401847/circle-rectangle-collision-detection-intersection/402010#402010
pub fn check_collision_circle_rect(circle: Circle, rect: Rectangle) -> Bool {
  let #(dist_x, dist_y) = #(
    float.absolute_value(circle.x -. rect.x),
    float.absolute_value(circle.y -. rect.y),
  )

  case
    dist_x >. { rect.width /. 2.0 +. circle.radius },
    dist_y >. { rect.height /. 2.0 +. circle.radius }
  {
    False, False -> {
      case dist_x <=. { rect.width /. 2.0 }, dist_y <=. { rect.height /. 2.0 } {
        False, False -> {
          let corner_distance_squared =
            {
              { dist_x -. rect.width /. 2.0 } *. { dist_x -. rect.width /. 2.0 }
            }
            +. {
              { dist_y -. rect.height /. 2.0 }
              *. { dist_y -. rect.height /. 2.0 }
            }
          corner_distance_squared <=. circle.radius *. circle.radius
        }
        _, _ -> True
      }
    }
    _, _ -> False
  }
}
