#[compute]
#version 450

// Definitions
struct Boid {
  vec2 position;
	vec2 velocity;
};

struct BoidOutput {
  vec2 avoidanceHeading;
	vec2 avgFlockHeading;
  vec2 avgFlockCenter;
};

// Uniforms and buffers
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
layout(set = 0, binding = 0, std140) restrict readonly uniform Settings {
  int viewAngle;
  int distanceSeparation;
  int distanceAlignment;
  int distanceCohesion;
} settings;
layout(set = 0, binding = 1, std430) restrict buffer Boids {
  Boid boids[];
};
layout(set = 0, binding = 2, std430) restrict buffer Output {
  BoidOutput data[];
};

// Functions
float dst(vec2 v1, vec2 v2) {
  float dx = pow(v1.x - v2.x, 2.0);
  float dy = pow(v1.y - v2.y, 2.0);

  return sqrt(dx + dy);
}

void main() {
  uint index = int(gl_GlobalInvocationID.x);
  Boid boid = boids[index];

  vec2 avoidanceHeading = vec2(0.0, 0.0);
  vec2 avgFlockHeading = vec2(0.0, 0.0);
  vec2 avgFlockCenter = vec2(0.0, 0.0);
  int flockmatesHeading = 0;
  int flockmatesCenter = 0;

  for (uint i = 0; i < boids.length(); i++) {
    if (i == index) {
      continue;
    }

    Boid other = boids[i];
    float dist = dst(boid.position, other.position);

    // Separation
    if (dist < settings.distanceSeparation) {
      avoidanceHeading += boid.position - other.position;
    }

    // Alignment
    if (dist < settings.distanceAlignment) {
      avgFlockHeading += other.velocity;
      flockmatesHeading += 1;
    }

    // Cohesion
    if (dist < settings.distanceCohesion) {
      avgFlockCenter += other.position;
      flockmatesCenter += 1;
    }
  }

  if (flockmatesHeading > 0) {
    avgFlockHeading /= float(flockmatesHeading);
  }

  if (flockmatesCenter > 0) {
    avgFlockCenter /= float(flockmatesCenter);
  }

  data[index].avoidanceHeading = avoidanceHeading;
  data[index].avgFlockHeading = avgFlockHeading - boid.velocity;
  data[index].avgFlockCenter = avgFlockCenter - boid.position;
}
