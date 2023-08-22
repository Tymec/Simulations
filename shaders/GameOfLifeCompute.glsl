#[compute]
#version 450


// Definitions
#define CELL_DEAD 0
#define CELL_ALIVE 1

#define EDGE_BEHAVIOR_WRAP 0
#define EDGE_BEHAVIOR_DEAD 1
#define EDGE_BEHAVIOR_KILL 2


// Inputs
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
layout(set = 0, binding = 0, std430) restrict buffer Grid {
  int data[];
} grid;
layout(set = 0, binding = 1, std430) restrict buffer NextGrid {
  int data[];
} next_grid;
layout(set = 0, binding = 2, std430) restrict buffer Settings {
  int edge_behavior;
  int rule_birth;
  int rule_survival;
} settings;
layout(set = 0, binding = 3, std430) restrict buffer Counters {
  int generation;
  int survival;
  int birth;
  int death;
} counters;

// Wraps a value between min and max (exclusive).
int wrap(int x, int min_x, int max_x) {
  if (x < min_x) {
    return max_x - 1;
  } else if (x >= max_x) {
    return min_x;
  } else {
    return x;
  }
}

// Gets the cell at the given coordinates.
int get_cell(int x, int y) {
  // Check if we're out of bounds
  if (x < 0 || x >= gl_NumWorkGroups.x || y < 0 || y >= gl_NumWorkGroups.y) {
    // Either wrap or return 0 depending on the edge behavior
    if (settings.edge_behavior == EDGE_BEHAVIOR_WRAP) {
      x = wrap(x, 0, int(gl_NumWorkGroups.x));
      y = wrap(y, 0, int(gl_NumWorkGroups.y));
    } else {
      return CELL_DEAD;
    }
  }

  return grid.data[x + y * gl_NumWorkGroups.x];
}

// Kills the cell at the given coordinates.
void kill_cell(int x, int y) {
  // Check if we're out of bounds
  if (x < 0 || x >= gl_NumWorkGroups.x || y < 0 || y >= gl_NumWorkGroups.y) {
    return;
  }

  counters.death += 1;
  next_grid.data[x + y * gl_NumWorkGroups.x] = CELL_DEAD;
}

// Sets the cell at the given coordinates.
void set_cell(int x, int y, int value) {
  // Check if we're out of bounds or on the edge
  if (x < 0 || x >= gl_NumWorkGroups.x || y < 0 || y >= gl_NumWorkGroups.y) {
    // Either wrap or ignore depending on the edge behavior
    if (settings.edge_behavior == EDGE_BEHAVIOR_WRAP) {
      x = wrap(x, 0, int(gl_NumWorkGroups.x));
      y = wrap(y, 0, int(gl_NumWorkGroups.y));
    } else {
      return;
    }
  } else if (x == 0 || x == gl_NumWorkGroups.x - 1 || y == 0 || y == gl_NumWorkGroups.y - 1) {
    // Kill the cell if we're on the edge and the edge behavior is kill
    if (settings.edge_behavior == EDGE_BEHAVIOR_KILL && value == CELL_ALIVE) {
      // Kill the cell
      value = CELL_DEAD;
      counters.death += 1;

      // Kill all neighbours
      kill_cell(x - 1, y - 1);  // Top left
      kill_cell(x, y - 1);      // Top
      kill_cell(x + 1, y - 1);  // Top right

      kill_cell(x - 1, y);      // Left
      kill_cell(x + 1, y);      // Right

      kill_cell(x - 1, y + 1);  // Bottom left
      kill_cell(x, y + 1);      // Bottom
      kill_cell(x + 1, y + 1);  // Bottom right
    }
  }

  next_grid.data[x + y * gl_NumWorkGroups.x] = value;
}

// Gets the number of neighbours of the cell at the given coordinates.
int get_neighbours(int x, int y) {
  int count = 0;

  count += get_cell(x - 1, y - 1);    // Top left
  count += get_cell(x, y - 1);        // Top
  count += get_cell(x + 1, y - 1);    // Top right

  count += get_cell(x - 1, y);        // Left
  count += get_cell(x + 1, y);        // Right

  count += get_cell(x - 1, y + 1);    // Bottom left
  count += get_cell(x, y + 1);        // Bottom
  count += get_cell(x + 1, y + 1);    // Bottom right

  return count;
}

// Returns whether the cell should live or die.
bool should_live(int cell, int neighbours) {
  // settings.rule_* is a bitfield where each bit represents a number of neighbours
  if (cell == CELL_ALIVE) {
    return (settings.rule_survival & (1 << neighbours)) != 0;
  } else {
    return (settings.rule_birth & (1 << neighbours)) != 0;
  }
}

// Main
void main() {
  // Get the coordinates of the current cell
  int x = int(gl_WorkGroupID.x);
  int y = int(gl_WorkGroupID.y);

  // Get the current cell and its neighbour count
  int cell = get_cell(x, y);
  int neighbours = get_neighbours(x, y);

  // Determine whether the cell should live or die
  int value = should_live(cell, neighbours) ? CELL_ALIVE : CELL_DEAD;

  // Update the counters
  if (cell == CELL_ALIVE && value == CELL_DEAD) {
    counters.death += 1;
  } else if (cell == CELL_DEAD && value == CELL_ALIVE) {
    counters.birth += 1;
  } else if (cell == CELL_ALIVE && value == CELL_ALIVE) {
    counters.survival += 1;
  }

  // Update the cell
  set_cell(x, y, value);
}
