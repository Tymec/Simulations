shader_type particles;
uniform sampler2D boid_data;
uniform sampler2D color_data;
uniform float boid_size;


void process() {
	int image_size = textureSize(boid_data, 0).x;

	int col = int(mod(float(INDEX), float(image_size)));
	int row = int(INDEX / uint(image_size));

  vec4 boid = texelFetch(boid_data, ivec2(col, row), 0);
	TRANSFORM[3] = vec4(boid.r, boid.g, 0.0, 0.0);

  mat2 scale_mat = mat2(vec2(boid_size, 0.0), vec2(0.0, boid_size));
	TRANSFORM[0].xy = scale_mat[0];
	TRANSFORM[1].xy = scale_mat[1];

  vec4 color = texelFetch(color_data, ivec2(col, row), 0);
  COLOR = color;
}
