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
  int isPredator;   // offset: 20, align: 4
};

// Uniforms and buffers
layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;
layout(set = 0, binding = 0, std430) restrict readonly buffer Settings {
  int numBoids;
  int separationDistance;
  int alignmentDistance;
  int cohesionDistance;
  int edgeWrap;
  int edgeMarginLeft;
  int edgeMarginRight;
  int edgeMarginTop;
  int edgeMarginBottom;
  int numFamilies;
  int familyAvoidanceDistance;
  int numPredators;
  int predatorSpeed;
  int predatorAvoidanceDistance;
  int mouseAvoidanceDistance;
  int imageSize;

  float size;
  float speedMin;
  float speedMax;
  float separationWeight;
  float alignmentWeight;
  float cohesionWeight;
  float edgeAvoidanceWeight;
  float familyAvoidanceWeight;
  float predatorAvoidanceWeight;
  float mouseAvoidanceWeight;
} settings;
layout(set = 0, binding = 1, std430) restrict readonly buffer Params {
  float xMax;
  float yMax;

  float mouseX;
  float mouseY;

  float deltaTime;
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

	//return angle_diff < settings.viewAngle;
  return false;
}

vec2 handleNeighbours(uint index) {
  Boid boid = boidsIn[index];
  vec2 acceleration = vec2(0.0, 0.0);
  //float rotation = atan(boid.velocity.y, boid.velocity.x);

  vec2 avoidanceHeading = vec2(0.0, 0.0);
  vec2 avgFlockHeading = vec2(0.0, 0.0);
  vec2 avgFlockCenter = vec2(0.0, 0.0);
  vec2 predatorAvoidanceHeading = vec2(0.0, 0.0);
  vec2 familyAvoidanceHeading = vec2(0.0, 0.0);
  int flockmatesHeading = 0;
  int flockmatesCenter = 0;

  // Loop through all boids
  for (uint i = 0; i < settings.numBoids + settings.numPredators; i++) {
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
    if (other.isPredator == 1) {
      if (dist < settings.predatorAvoidanceDistance) {
        predatorAvoidanceHeading += boid.position - other.position;
      }
      continue;
    }

    // Separation
    if (dist < settings.separationDistance) {
      avoidanceHeading += boid.position - other.position;
      continue;
    }

    // Avoid boids of other families
    if (boid.family != other.family) {
      if (dist < settings.familyAvoidanceDistance) {
        familyAvoidanceHeading += boid.position - other.position;
      }
      continue;
    }

    // Alignment
    if (dist < settings.alignmentDistance) {
      avgFlockHeading += other.velocity;
      flockmatesHeading += 1;
    }

    // Cohesion
    if (dist < settings.cohesionDistance) {
      avgFlockCenter += other.position;
      flockmatesCenter += 1;
    }
  }

  // Apply forces
  if (predatorAvoidanceHeading != vec2(0.0, 0.0)) {
    //acceleration.x += (predatorHeading.x > 0) ? settings.weightPredator : -settings.weightPredator;
    //acceleration.y += (predatorHeading.y > 0) ? settings.weightPredator : -settings.weightPredator;
    acceleration += predatorAvoidanceHeading * settings.predatorAvoidanceWeight;
  }

  // Avoid mouse if close and not out of screen
  if (params.mouseX > 0 && params.mouseX < params.xMax && params.mouseY > 0 && params.mouseY < params.yMax) {
    vec2 mousePos = vec2(params.mouseX, params.mouseY);
    float dist = dst(boid.position, mousePos);

    if (dist < settings.mouseAvoidanceDistance) {
      acceleration += (boid.position - mousePos) * settings.mouseAvoidanceWeight;
    }
  }

  acceleration += avoidanceHeading * settings.separationWeight;

  if (flockmatesHeading > 0) {
    avgFlockHeading /= float(flockmatesHeading);
    acceleration += (avgFlockHeading - boid.velocity) * settings.alignmentWeight;
  }

  if (flockmatesCenter > 0) {
    avgFlockCenter /= float(flockmatesCenter);
    acceleration += (avgFlockCenter - boid.position) * settings.cohesionWeight;
  }

  return acceleration;
}

// Returns a random float between 0 and 1
float randi(vec2 co) {
  return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
  uint index = int(gl_GlobalInvocationID.x);
  if (index >= settings.numBoids + settings.numPredators) {
    return;
  }

  Boid boid = boidsIn[index];
  vec2 acceleration = vec2(0.0, 0.0);

  // Handle neighbours (separation, alignment, cohesion)
  if (boid.isPredator == 0) {
    acceleration += handleNeighbours(index);
  }

  // Avoid edges
  // TODO: Revisit naming or avoid like separation
  if (settings.edgeAvoidanceWeight > 0) {
    if (boid.position.x < settings.edgeMarginLeft) {
      acceleration.x += settings.edgeAvoidanceWeight;
    } else if (boid.position.x > params.xMax - settings.edgeMarginRight) {
      acceleration.x -= settings.edgeAvoidanceWeight;
    }

    if (boid.position.y < settings.edgeMarginTop) {
      acceleration.y += settings.edgeAvoidanceWeight;
    } else if (boid.position.y > params.yMax - settings.edgeMarginBottom) {
      acceleration.y -= settings.edgeAvoidanceWeight;
    }
  }

  // Update velocity and position
  vec2 velocity = boid.velocity + acceleration;
  if (acceleration != vec2(0.0, 0.0)) {
    // Limit speed
    float speed = 0;
    if (boid.isPredator == 1) {
      speed = settings.predatorSpeed;
    } else {
      speed = clamp(length(velocity), settings.speedMin, settings.speedMax);
    }
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
  boidsOut[index].isPredator = boid.isPredator;

  // Write to image (R = pos_x, G = pos_y)

  // Remap position to image coordinates
  int col = int(mod(index, float(settings.imageSize)));
  int row = int(index / float(settings.imageSize));

  imageStore(outputImage, ivec2(col, row), vec4(pos.x, pos.y, 0.0, 0.0));

  vec4 color = vec4(0.0, 0.0, 0.0, 1.0);
  if (boid.isPredator == 1) {
    color.r = 1.0;
  } else {
    color.r = randi(vec2(0, boid.family));
    color.g = randi(vec2(boid.family, boid.family));
    color.b = randi(vec2(boid.family, 0));
  }
  imageStore(colorImage, ivec2(col, row), color);
}
