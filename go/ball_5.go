components {
  id: "ball"
  component: "/logic/script/ball.script"
  properties {
    id: "ball_number"
    value: "5.0"
    type: PROPERTY_TYPE_NUMBER
  }
}
embedded_components {
  id: "sprite"
  type: "sprite"
  data: "default_animation: \"ball_5\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/main/main.atlas\"\n"
  "}\n"
  ""
}
embedded_components {
  id: "collisionobject"
  type: "collisionobject"
  data: "type: COLLISION_OBJECT_TYPE_DYNAMIC\n"
  "mass: 5.0\n"
  "friction: 0.1\n"
  "restitution: 0.2\n"
  "group: \"ball\"\n"
  "mask: \"bag\"\n"
  "mask: \"ball\"\n"
  "mask: \"detector\"\n"
  "embedded_collision_shape {\n"
  "  shapes {\n"
  "    shape_type: TYPE_SPHERE\n"
  "    position {\n"
  "    }\n"
  "    rotation {\n"
  "    }\n"
  "    index: 0\n"
  "    count: 1\n"
  "  }\n"
  "  data: 90.123535\n"
  "}\n"
  "linear_damping: 0.1\n"
  "angular_damping: 0.1\n"
  ""
}
