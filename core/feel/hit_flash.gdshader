// Hit flash for sprites and controls (canvas_item). Tween `flash` from 1.0 to 0.0 over ~0.1 s.
// Set the parameter once first: on a fresh ShaderMaterial "shader_parameter/flash" is not a
// valid tween property until it has been set, so tween_property(...).from(1.0) alone errors.
//   material.set_shader_parameter("flash", 1.0)
//   create_tween().tween_property(material, "shader_parameter/flash", 0.0, 0.1)
// Give each flashing node its own material (or duplicate()), or every node sharing it flashes.
// Cost: low (one per-sprite shader, Compatibility renderer safe). Written for this template; CC0.
shader_type canvas_item;

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, flash_color.rgb, flash);
}
