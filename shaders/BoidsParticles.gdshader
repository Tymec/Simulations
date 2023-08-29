shader_type particles;
uniform sampler2D boid_data; // R = pos.x, G = pos.y, B = family
uniform float scale;


void process() {
	int image_size = textureSize(boid_data, 0).x;

	int col = int(mod(float(INDEX), float(image_size)));
	int row = int(INDEX / uint(image_size));

  vec4 boid = texelFetch(boid_data, ivec2(col, row), 0);
	TRANSFORM[3] = vec4(boid.r, boid.g, 0.0, 0.0);

  mat2 scale_mat = mat2(vec2(scale, 0.0), vec2(0.0, scale));
	TRANSFORM[0].xy = scale_mat[0];
	TRANSFORM[1].xy = scale_mat[1];

  // Set color based on family
  int family = int(boid.b);
  if (family == 0) {
    COLOR = vec4(1.0, 0.0, 0.0, 1.0);
  } else if (family == 1) {
    COLOR = vec4(0.0, 1.0, 0.0, 1.0);
  } else if (family == 2) {
    COLOR = vec4(0.0, 0.0, 1.0, 1.0);
  }
}
