import gleam/bool
import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam_community/maths
import vec/vec2
import vec/vec2f

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

// https://stackoverflow.com/questions/62028169/how-to-detect-when-rotated-rectangles-are-colliding-each-other
pub fn check_collision_rotated_rectangles(
  rect1: Rectangle,
  rotation1: Float,
  rect2: Rectangle,
  rotation2: Float,
) -> Bool {
  projection_collide(rect1, rotation1, rect2, rotation2)
  && projection_collide(rect2, rotation2, rect1, rotation1)
}

fn projection_collide(
  rect1: Rectangle,
  rotation1: Float,
  rect2: Rectangle,
  rotation2: Float,
) -> Bool {
  let lines = get_axes(rect2, rotation2)
  let corners = get_corners(rect1, rotation1)

  check_line(lines.0, corners, rect2, True)
  && check_line(lines.1, corners, rect2, False)
}

fn check_line(
  line: Line,
  corners: List(vec2.Vec2(Float)),
  rect: Rectangle,
  x_line: Bool,
) -> Bool {
  let half_size = case x_line {
    True -> rect.width /. 2.0
    False -> rect.height /. 2.0
  }

  let #(min, max) =
    corners
    |> list.fold(#(100_000_000.0, -100_000_000.0), fn(accum, corner) {
      let projected = project_vec(corner, line)
      let c_p = projected |> sub_vec(vec2.Vec2(rect.x, rect.y))
      let val_sign = sign(c_p.x *. line.dx +. c_p.y *. line.dy)
      let signed_distance = val_sign *. { hypot(c_p.y, c_p.x) }

      #(
        float.min(accum.0, signed_distance),
        float.max(accum.1, signed_distance),
      )
    })

  {
    min <. 0.0
    && max >. 0.0
    || float.absolute_value(min) <. half_size
    || float.absolute_value(max) <. half_size
  }
}

fn get_axes(rect: Rectangle, rotation: Float) -> #(Line, Line) {
  let o_x = vec2.Vec2(x: 1.0, y: 0.0)
  let o_y = vec2.Vec2(x: 0.0, y: 1.0)

  let r_x = o_x |> vec2f.rotate(rotation)
  let r_y = o_y |> vec2f.rotate(rotation)

  #(
    Line(x: rect.x, y: rect.y, dx: r_x.x, dy: r_x.y),
    Line(x: rect.x, y: rect.y, dx: r_y.x, dy: r_y.y),
  )
}

fn get_corners(rect: Rectangle, rotation: Float) -> List(vec2.Vec2(Float)) {
  let axes = get_axes(rect, rotation)

  let r_x =
    axes.0 |> line_direction() |> vec2.map(fn(x) { x *. rect.width /. 2.0 })
  let r_y =
    axes.1 |> line_direction() |> vec2.map(fn(x) { x *. rect.height /. 2.0 })

  let centre = vec2.Vec2(x: rect.x, y: rect.y)
  [
    centre |> add_vec(r_x) |> add_vec(r_y),
    centre |> add_vec(r_x) |> sub_vec(r_y),
    centre |> sub_vec(r_x) |> sub_vec(r_y),
    centre |> sub_vec(r_x) |> add_vec(r_y),
  ]
}

fn project_vec(vec: vec2.Vec2(Float), line: Line) -> vec2.Vec2(Float) {
  let dot_value =
    line.dx *. { vec.x -. line.x } +. line.dy *. { vec.y -. line.y }
  vec2.Vec2(
    x: line.x +. line.dx *. dot_value,
    y: line.y +. line.dy *. dot_value,
  )
}

fn add_vec(vec_1: vec2.Vec2(Float), vec_2: vec2.Vec2(Float)) -> vec2.Vec2(Float) {
  vec2.map2(vec_1, vec_2, fn(a, b) { a +. b })
}

fn sub_vec(vec_1: vec2.Vec2(Float), vec_2: vec2.Vec2(Float)) -> vec2.Vec2(Float) {
  vec2.map2(vec_1, vec_2, fn(a, b) { a -. b })
}

type Line {
  Line(x: Float, y: Float, dx: Float, dy: Float)
}

fn line_direction(line: Line) -> vec2.Vec2(Float) {
  vec2.Vec2(x: line.dx, y: line.dy)
}
