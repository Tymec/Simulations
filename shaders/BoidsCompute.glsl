#[compute]
#version 450

// Constants
const float PI = 3.14159265359;
const float TAU = 6.28318530718;

// Definitions
struct Boid {
  vec2 position;    // offset: 0, align: 8
	vec2 velocity;    // offset: 8, align: 8
  int family;       // offset: 16, align: 4
  int is_predator;  // offset: 20, align: 4
};

// Uniforms and buffers
layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;
layout(set = 0, binding = 0, std430) restrict readonly buffer Settings {
  float viewAngle;

  int distanceSeparationSq;
  int distanceAlignmentSq;
  int distanceCohesionSq;
  int distanceFamilySq;
  int distancePredatorSq;

  float weightSeparation;
  float weightAlignment;
  float weightCohesion;
  float weightEdge;
  float weightPredator;

  float minSpeed;
  float maxSpeed;

  float edgeMarginLeft;
  float edgeMarginRight;
  float edgeMarginTop;
  float edgeMarginBottom;

  int edgeWrap;
} settings;
layout(set = 0, binding = 1, std430) restrict readonly buffer Params {
  float xMax;       // offset: 0, align: 4
  float yMax;       // offset: 4, align: 4
  int imageSize;    // offset: 8, align: 4
  float deltaTime;  // offset: 12, align: 4
} params;
layout(set = 0, binding = 2, std430) restrict readonly buffer BoidsIn {
  Boid boidsIn[];
};
layout(set = 0, binding = 3, std430) restrict buffer BoidsOut {
  Boid boidsOut[];
};
layout(rgba32f, binding = 4) uniform image2D outputImage;
layout(rgba32f, binding = 5) uniform image2D colorImage;

// Functions
float dst(vec2 v1, vec2 v2) {
  vec2 diff = v1 - v2;
  return dot(diff, diff);
}

bool is_boid_in_fov(vec2 boid_pos, float boid_rot, vec2 other_pos) {
	float angle = atan(other_pos.y - boid_pos.y, other_pos.x - boid_pos.x);
  float angle_diff = abs(angle - boid_rot);
	if (angle_diff > PI) {
		angle_diff = TAU - angle_diff;
	}

	return angle_diff < settings.viewAngle;
}

vec2 handleNeighbours(uint index) {
  Boid boid = boidsIn[index];
  vec2 acceleration = vec2(0.0, 0.0);
  //float rotation = atan(boid.velocity.y, boid.velocity.x);

  vec2 avoidanceHeading = vec2(0.0, 0.0);
  vec2 avgFlockHeading = vec2(0.0, 0.0);
  vec2 avgFlockCenter = vec2(0.0, 0.0);
  vec2 predatorHeading = vec2(0.0, 0.0);
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
    // if (!is_boid_in_fov(boid.position, rotation, other.position)) {
    //   continue;
    // }

    // Predator
    if (other.is_predator == 1) {
      if (dist < settings.distancePredatorSq) {
        predatorHeading += boid.position - other.position;
      }
      continue;
    }

    // Separation
    if (dist < settings.distanceSeparationSq) {
      avoidanceHeading += boid.position - other.position;
      continue;
    }

    // Avoid boids of other families
    if (boid.family.x != other.family.x) {
      if (dist < settings.distanceFamilySq) {
        avoidanceHeading += boid.position - other.position;
      }
      continue;
    }

    // Alignment
    if (dist < settings.distanceAlignmentSq) {
      avgFlockHeading += other.velocity;
      flockmatesHeading += 1;
    }

    // Cohesion
    if (dist < settings.distanceCohesionSq) {
      avgFlockCenter += other.position;
      flockmatesCenter += 1;
    }
  }

  // Apply forces
  if (predatorHeading != vec2(0.0, 0.0)) {
    acceleration.x += (predatorHeading.x > 0) ? settings.weightPredator : -settings.weightPredator;
    acceleration.y += (predatorHeading.y > 0) ? settings.weightPredator : -settings.weightPredator;
  }

  acceleration += avoidanceHeading * settings.weightSeparation;

  if (flockmatesHeading > 0) {
    avgFlockHeading /= float(flockmatesHeading);
    acceleration += (avgFlockHeading - boid.velocity) * settings.weightAlignment;
  }

  if (flockmatesCenter > 0) {
    avgFlockCenter /= float(flockmatesCenter);
    acceleration += (avgFlockCenter - boid.position) * settings.weightCohesion;
  }

  return acceleration;
}

// Returns a random float between 0 and 1
float randi(vec2 co) {
  return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
  uint index = int(gl_GlobalInvocationID.x);
  Boid boid = boidsIn[index];
  vec2 acceleration = vec2(0.0, 0.0);

  // Handle neighbours (separation, alignment, cohesion)
  if (boid.is_predator == 0) {
    acceleration += handleNeighbours(index);
  }

  // Avoid edges
  if (settings.weightEdge > 0) {
    if (boid.position.x < settings.edgeMarginLeft) {
      acceleration.x += settings.weightEdge;
    } else if (boid.position.x > params.xMax - settings.edgeMarginRight) {
      acceleration.x -= settings.weightEdge;
    }

    if (boid.position.y < settings.edgeMarginTop) {
      acceleration.y += settings.weightEdge;
    } else if (boid.position.y > params.yMax - settings.edgeMarginBottom) {
      acceleration.y -= settings.weightEdge;
    }
  }

  // Update velocity and position
  vec2 velocity = boid.velocity + acceleration;
  if (acceleration != vec2(0.0, 0.0)) {
    // Limit speed
    float speed = clamp(length(velocity), settings.minSpeed, settings.maxSpeed);
    velocity = normalize(velocity) * speed;

    velocity *= params.deltaTime;
  }
  vec2 pos = boid.position + velocity;

  // Wrap around screen
  if (settings.edgeWrap == 1) {
    if (pos.x < 0) {
      pos.x = params.xMax;
    } else if (pos.x > params.xMax) {
      pos.x = 0;
    }
    if (pos.y < 0) {
      pos.y = params.yMax;
    } else if (pos.y > params.yMax) {
      pos.y = 0;
    }
  }

  // Write to buffer
  boidsOut[index].position = pos;
  boidsOut[index].velocity = velocity;
  boidsOut[index].family = boid.family;
  boidsOut[index].is_predator = boid.is_predator;

  // Write to image (R = pos_x, G = pos_y)
  int col = int(mod(index, params.imageSize));
  int row = int(index / params.imageSize);

  imageStore(outputImage, ivec2(col, row), vec4(pos.x, pos.y, 0.0, 0.0));

  vec4 color = vec4(0.0, 0.0, 0.0, 1.0);
  if (boid.is_predator == 1) {
    color.r = 1.0;
  } else {
    // color.r = randi(vec2(index, index));
    color.g = randi(vec2(boid.family, boid.family));
    // color.b = randi(vec2(boid.family, index));
  }
  imageStore(colorImage, ivec2(col, row), color);
}
