#[compute]
#version 450

// Constants
const float PI = 3.14159265359;
const float TAU = 6.28318530718;

// Definitions
struct Boid {
  vec2 position;  // offset: 0, align: 8
	vec2 velocity;  // offset: 8, align: 8
};

// Uniforms and buffers
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
layout(set = 0, binding = 0, std140) restrict readonly buffer Settings {
  float viewAngle;        // offset: 0, align: 4

  int distanceSeparation; // offset: 4, align: 4
  int distanceAlignment;  // offset: 8, align: 4
  int distanceCohesion;   // offset: 12, align: 4

  float weightSeparation; // offset: 16, align: 4
  float weightAlignment;  // offset: 20, align: 4
  float weightCohesion;   // offset: 24, align: 4

  float minSpeed;         // offset: 28, align: 4
  float maxSpeed;         // offset: 32, align: 4

  float edgeAvoidanceWeight; // offset: 36, align: 4
  float edgeMarginLeft;      // offset: 40, align: 4
  float edgeMarginRight;     // offset: 44, align: 4
  float edgeMarginTop;       // offset: 48, align: 4
  float edgeMarginBottom;    // offset: 52, align: 4
} settings;
layout(set = 0, binding = 1, std430) restrict readonly buffer Params {
  vec2 edgeStart; // offset: 0, align: 8
  vec2 edgeEnd;   // offset: 8, align: 8
} params;
layout(set = 0, binding = 2, std430) restrict readonly buffer BoidsIn {
  Boid boidsIn[];
};
layout(set = 0, binding = 3, std430) restrict writeonly buffer BoidsOut {
  Boid boidsOut[];
};

// Functions
float dst(vec2 v1, vec2 v2) {
  float dx = pow(v1.x - v2.x, 2.0);
  float dy = pow(v1.y - v2.y, 2.0);

  return sqrt(dx + dy);
}

bool is_boid_in_fov(vec2 boid_pos, float boid_rot, vec2 other_pos) {
	float angle = atan(other_pos.y - boid_pos.y, other_pos.x - boid_pos.x);
  float angle_diff = abs(angle - boid_rot);
	if (angle_diff > PI) {
		angle_diff = TAU - angle_diff;
	}

	return angle_diff < settings.viewAngle;
}

void main() {
  uint index = int(gl_GlobalInvocationID.x);
  Boid boid = boidsIn[index];

  // Variables
  vec2 acceleration = vec2(0.0, 0.0);
  float rotation = atan(boid.velocity.y, boid.velocity.x);

  vec2 avoidanceHeading = vec2(0.0, 0.0);
  vec2 avgFlockHeading = vec2(0.0, 0.0);
  vec2 avgFlockCenter = vec2(0.0, 0.0);
  int flockmatesHeading = 0;
  int flockmatesCenter = 0;

  // Loop through all boids
  for (uint i = 0; i < boidsIn.length(); i++) {
    if (i == index) {
      continue;
    }

    Boid other = boidsIn[i];
    float dist = dst(boid.position, other.position);

    // Check if boid is in view
    if (!is_boid_in_fov(boid.position, rotation, other.position)) {
      continue;
    }

    if (dist < settings.distanceSeparation) {
      // Separation
      avoidanceHeading += boid.position - other.position;
      continue;
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

  // Apply forces
  acceleration += avoidanceHeading * settings.weightSeparation;
  if (flockmatesHeading > 0) {
    avgFlockHeading /= float(flockmatesHeading);
    acceleration += (avgFlockHeading - boid.velocity) * settings.weightAlignment;
  }
  if (flockmatesCenter > 0) {
    avgFlockCenter /= float(flockmatesCenter);
    acceleration += (avgFlockCenter - boid.position) * settings.weightCohesion;
  }

  // Avoid edges
  if (settings.edgeAvoidanceWeight > 0) {
    if (boid.position.x < params.edgeStart.x + settings.edgeMarginLeft) {
      acceleration.x += settings.edgeAvoidanceWeight;
    } else if (boid.position.x > params.edgeEnd.x - settings.edgeMarginRight) {
      acceleration.x -= settings.edgeAvoidanceWeight;
    }

    if (boid.position.y < params.edgeStart.y + settings.edgeMarginTop) {
      acceleration.y += settings.edgeAvoidanceWeight;
    } else if (boid.position.y > params.edgeEnd.y - settings.edgeMarginBottom) {
      acceleration.y -= settings.edgeAvoidanceWeight;
    }
  }

  // Update velocity
  vec2 velocity = boid.velocity + acceleration;

  // Limit speed
  float speed = clamp(length(velocity), settings.minSpeed, settings.maxSpeed);
  velocity = normalize(velocity) * speed;

  // test, write to position if velocity has been accessed by another thread
  boidsOut[index].velocity = velocity;

  // TODO: Update position

  // TODO: Wrap around screen
}
