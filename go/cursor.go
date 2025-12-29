components {
  id: "cursor"
  component: "/in/cursor.script"
  properties {
    id: "drag"
    value: "false"
    type: PROPERTY_TYPE_BOOLEAN
  }
}
components {
  id: "cursor_helper"
  component: "/logic/script/cursor_helper.script"
}
embedded_components {
  id: "collisionobject"
  type: "collisionobject"
  data: "type: COLLISION_OBJECT_TYPE_TRIGGER\n"
  "mass: 0.0\n"
  "friction: 0.1\n"
  "restitution: 0.5\n"
  "group: \"cursor\"\n"
  "mask: \"ball\"\n"
  "embedded_collision_shape {\n"
  "  shapes {\n"
  "    shape_type: TYPE_SPHERE\n"
  "    position {\n"
  "    }\n"
  "    rotation {\n"
  "    }\n"
  "    index: 0\n"
  "    count: 1\n"
  "    id: \"shape\"\n"
  "  }\n"
  "  data: 10.0\n"
  "}\n"
  ""
}
