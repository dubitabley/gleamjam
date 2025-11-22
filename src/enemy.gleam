import tiramisu/effect.{type Effect}
import tiramisu/scene
import tiramisu/transform

pub type EnemyModel {
  EnemyModel(enemies: List(Enemy))
}

pub type Enemy {
  Enemy(x: Float, y: Float, health: Int)
}

pub type State {
  Moving
  Idle
  Attacking
}

pub type EnemyMsg {
  Tick
}

pub fn init() -> #(EnemyModel, Effect(EnemyMsg)) {
  #(EnemyModel([]), effect.none())
}

pub fn update(
  model: EnemyModel,
  msg: EnemyMsg,
) -> #(EnemyModel, Effect(EnemyMsg)) {
  case msg {
    Tick -> {
      #(model, effect.none())
    }
  }
}

pub fn view(model: EnemyModel) -> scene.Node(String) {
  scene.empty(id: "Towers", transform: transform.identity, children: [])
}
