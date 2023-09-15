shader_type canvas_item;
uniform sampler2D trailMap;
uniform float deltaTime;
uniform float evaporateSpeed;
uniform float diffuseSpeed;
uniform int blurRadius;


void fragment() {
  vec2 size = vec2(textureSize(trailMap, 0));
	vec3 trail = texture(trailMap, UV).rgb;

  // sick effect
  // vec2 st = UV * 0.5 + 0.25;
  // vec3 trail = texture(trailMap, st).rgb;
  //COLOR = vec4(trail, 1.0);

  // Blur the image
  vec3 blurred = vec3(0.0);
  int count = 0;
  for (int x = -blurRadius; x <= blurRadius; x++) {
    for (int y = -blurRadius; y <= blurRadius; y++) {
      vec2 offset = vec2(float(x), float(y)) / size;
      blurred += texture(trailMap, UV + offset).rgb;
      count++;
    }
  }
  blurred /= float(count);

  // Blend the blurred image with the original
  blurred = mix(trail, blurred, diffuseSpeed * deltaTime);

  // Evaporate the trail
  vec3 color = blurred - evaporateSpeed * deltaTime;
  color = max(color, vec3(0.0));

  COLOR = vec4(color, 1.0);
}
