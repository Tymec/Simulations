#[compute]
#version 450

// Definitions
struct Agent {
  vec2 position;
  float rotation;
  // Required to make the struct 16 bytes
  float padding;
};

// Uniforms and buffers
layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;
layout(set = 0, binding = 0, std430) restrict readonly buffer Settings {
  uint numAgents;
  float agentSpeed;
  ivec2 outputSize;
  int sensorSize;
  float sensorAngle;
  float sensorDistance;
  float turnSpeed;
};
layout(set = 0, binding = 1, std430) restrict readonly buffer Params {
  float deltaTime;
};
layout(set = 0, binding = 2, std430) restrict buffer Agents {
  Agent agents[];
};
layout(rgba8, binding = 3) uniform image2D outputImage;

// Functions
uint hashi(uint x) {
  x ^= x >> uint(16);
  x *= 0x7feb352dU;
  x ^= x >> uint(15);
  x *= 0x846ca68bU;
  x ^= x >> uint(16);
  return x;
}

float random(vec2 t) {
  return float(hashi(uint(t.x) + hashi(uint(t.y)))) / float(0xffffffffU);
}

bool withinBounds(vec2 pos) {
  return pos.x > 0.0 && pos.x < float(outputSize.x) && pos.y > 0.0 && pos.y < float(outputSize.y);
}

float checkSensor(Agent agent, int dir) {
  float angleOffset = sensorAngle * float(dir);
  vec2 direction = vec2(cos(agent.rotation + angleOffset), sin(agent.rotation + angleOffset));
  vec2 pos = agent.position + direction * sensorDistance;

  float total = 0.0;
  for (int x = -sensorSize; x <= sensorSize; x++) {
    for (int y = -sensorSize; y <= sensorSize; y++) {
      vec2 samplePos = pos + vec2(float(x), float(y));

      if (withinBounds(samplePos)) {
        total += imageLoad(outputImage, ivec2(samplePos)).r;
      }
    }
  }
  return total;
}

void main() {
  uint index = uint(gl_GlobalInvocationID.x);
  if (index >= numAgents) {
    return;
  }

  Agent agent = agents[index];
  float rng = random(agent.position * deltaTime);

  // Update position
  float forwardWeight = checkSensor(agent, 0);
  float leftWeight = checkSensor(agent, 1);
  float rightWeight = checkSensor(agent, -1);
  float randomSteer = rng;

  if (forwardWeight > leftWeight && forwardWeight > rightWeight) {
    // Forward
  } else if (forwardWeight < leftWeight && forwardWeight < rightWeight) {
    // Turn in random direction
   agent.rotation += (randomSteer - 0.5) * 2.0 * turnSpeed * deltaTime;
  } else if (leftWeight > rightWeight) {
    // Turn left
    agent.rotation += randomSteer * turnSpeed * deltaTime;
  } else if (rightWeight > leftWeight) {
    // Turn right
    agent.rotation -= randomSteer * turnSpeed * deltaTime;
  }

  vec2 direction = vec2(cos(agent.rotation), sin(agent.rotation));
  agent.position += direction * agentSpeed * deltaTime;

  // Wrap around
  if (!withinBounds(agent.position)) {
    agent.position.x = min(float(outputSize.x) - 0.01, max(0.01, agent.position.x));
    agent.position.y = min(float(outputSize.y) - 0.01, max(0.01, agent.position.y));

    rng = random(agent.position * rng);
    agent.rotation = rng * 2.0 * 3.14159;
  }

  // Write back
  agents[index] = agent;

  // Write to image
  imageStore(outputImage, ivec2(agent.position), vec4(1.0));
}
