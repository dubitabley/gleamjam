import gleam/bool
import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam_community/maths

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

pub fn random_angle() -> Float {
  float.random() *. maths.pi() *. 2.0
}

pub fn random_bool() -> Bool {
  int.random(2) == 1
}

pub fn sum(amounts: List(Int)) -> Int {
  amounts |> list.fold(0, fn(a, b) { a + b })
}

pub fn sign(num: Float) -> Float {
  case num >. 0.0 {
    True -> 1.0
    False ->
      case num <. 0.0 {
        True -> -1.0
        False -> 0.0
      }
  }
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

pub fn check_collision_rect_rect(rect1: Rectangle, rect2: Rectangle) -> Bool {
  let left_1 = rect1.x -. rect1.width /. 2.0
  let top_1 = rect1.y -. rect1.height /. 2.0
  let left_2 = rect2.x -. rect2.width /. 2.0
  let top_2 = rect2.y -. rect2.height /. 2.0
  left_1 <. left_2 +. rect2.width
  && left_1 +. rect1.width >. left_2
  && top_1 <. top_2 +. rect2.height
  && top_1 +. rect1.height >. top_2
}
