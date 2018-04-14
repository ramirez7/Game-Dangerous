// Vertex shader (program 0, two point lighted object, no texture)
#version 330

layout(location = 0) in vec4 position;
layout(location = 1) in vec4 colour;
layout(location = 2) in vec3 normal;

out vec3 modelPosition;
out vec4 diffColour;
out vec3 vertNormal;
flat out vec3 modLightPos0;
flat out vec3 modLightPos1;
flat out vec4 intensity0;
flat out vec4 intensity1;

uniform mat4 mod_to_world;
uniform mat4 world_to_clip;
uniform mat4 world_to_mod;
uniform vec3 lmap_pos0[100];
uniform vec3 lmap_pos1[100];
uniform vec3 lmap_int0[100];
uniform vec3 lmap_int1[100];

void main() {
modelPosition = position.xyz;
diffColour = colour;
vertNormal = normal;
vec4 worldPos = mod_to_world * position;

int look_up = int(worldPos.x / 10) + int(worldPos.y / 10) * 10;
vec4 worldLightPos0 = vec4(lmap_pos0[look_up], 1);
vec4 worldLightPos1 = vec4(lmap_pos1[look_up], 1);
intensity0 = vec4(lmap_int0[look_up], 1);
intensity1 = vec4(lmap_int1[look_up], 1);
modLightPos0 = (world_to_mod * worldLightPos0).xyz;
modLightPos1 = (world_to_mod * worldLightPos1).xyz;

gl_Position = world_to_clip * worldPos;
}

// Fragment shader (program 0, two point lighted object, no texture)
#version 330

in vec3 modelPosition;
in vec4 diffColour;
in vec3 vertNormal;
flat in vec3 modLightPos0;
flat in vec3 modLightPos1;
flat in vec4 intensity0;
flat in vec4 intensity1;

out vec4 outputColour;

uniform float lmap_t0[240];
uniform float lmap_t1[240];
uniform int t;

float lightAttenuation (in vec3 fragPos, in vec3 lightPos, out vec3 lightDir) {
vec3 lightDifference = fragPos - lightPos;
float distanceSqr = dot(lightDifference, lightDifference);
lightDir = lightDifference * inversesqrt(distanceSqr);
return (1 / distanceSqr);
}

void main() {
vec3 lightDir0; vec3 lightDir1;
float g = 0.4545455;
vec4 gamma = vec4(g, g, g, 1);
float attenuation0 = lightAttenuation(modelPosition, modLightPos0, lightDir0);
float attenuation1 = lightAttenuation(modelPosition, modLightPos1, lightDir1);
float cosAngIncidence0 = dot(vertNormal, lightDir0);
float cosAngIncidence1 = dot(vertNormal, lightDir1);
cosAngIncidence0 = clamp(cosAngIncidence0, 0, 1);
cosAngIncidence1 = clamp(cosAngIncidence1, 0, 1);
float adjust0 = lmap_t0[t];
float adjust1 = lmap_t1[t];
vec4 totalLight = (attenuation0 * adjust0 * cosAngIncidence0 * intensity0 * diffColour) + (attenuation1 * adjust1 * cosAngIncidence1 * intensity1 * diffColour) + (vec4(0.1, 0.1, 0.1, 1) * diffColour);
outputColour = pow(totalLight, gamma);
}

// Vertex shader (program 1, two point lighted object with texture)
#version 330

layout(location = 0) in vec4 position;
layout(location = 1) in vec2 texCoord;
layout(location = 2) in vec3 normal;

out vec3 modelPosition;
out vec2 tex_coord;
out vec3 vertNormal;
flat out vec3 modLightPos0;
flat out vec3 modLightPos1;
flat out vec4 intensity0;
flat out vec4 intensity1;

uniform mat4 mod_to_world;
uniform mat4 world_to_clip;
uniform mat4 world_to_mod;
uniform vec3 lmap_pos0[100];
uniform vec3 lmap_pos1[100];
uniform vec3 lmap_int0[100];
uniform vec3 lmap_int1[100];

void main() {
modelPosition = position.xyz;
tex_coord = texCoord;
vertNormal = normal;
vec4 worldPos = mod_to_world * position;

int look_up = int(worldPos.x / 10) + int(worldPos.y / 10) * 10;
vec4 worldLightPos0 = vec4(lmap_pos0[look_up], 1);
vec4 worldLightPos1 = vec4(lmap_pos1[look_up], 1);
intensity0 = vec4(lmap_int0[look_up], 1);
intensity1 = vec4(lmap_int1[look_up], 1);
modLightPos0 = (world_to_mod * worldLightPos0).xyz;
modLightPos1 = (world_to_mod * worldLightPos1).xyz;

gl_Position = world_to_clip * worldPos;
}

// Fragment shader (program 1, two point lighted object with texture)
#version 330

in vec3 modelPosition;
in vec2 tex_coord;
in vec3 vertNormal;
flat in vec3 modLightPos0;
flat in vec3 modLightPos1;
flat in vec4 intensity0;
flat in vec4 intensity1;

out vec4 outputColour;

uniform sampler2D tex_unit0;
uniform float lmap_t0[240];
uniform float lmap_t1[240];
uniform int t;

float lightAttenuation (in vec3 fragPos, in vec3 lightPos, out vec3 lightDir) {
vec3 lightDifference = fragPos - lightPos;
float distanceSqr = dot(lightDifference, lightDifference);
lightDir = lightDifference * inversesqrt(distanceSqr);
return (1 / distanceSqr);
}

void main() {
vec3 lightDir0; vec3 lightDir1;
float g = 0.4545455;
vec4 gamma = vec4(g, g, g, 1);
float attenuation0 = lightAttenuation(modelPosition, modLightPos0, lightDir0);
float attenuation1 = lightAttenuation(modelPosition, modLightPos1, lightDir1);
float cosAngIncidence0 = dot(vertNormal, lightDir0);
float cosAngIncidence1 = dot(vertNormal, lightDir1);
cosAngIncidence0 = clamp(cosAngIncidence0, 0, 1);
cosAngIncidence1 = clamp(cosAngIncidence1, 0, 1);
vec4 diffColour = texture(tex_unit0, tex_coord);
//vec4 diffColour = vec4(tex_coord.x, 0, tex_coord.y, 1);
float adjust0 = lmap_t0[t];
float adjust1 = lmap_t1[t];
vec4 totalLight = (attenuation0 * adjust0 * cosAngIncidence0 * intensity0 * diffColour) + (attenuation1 * adjust1 * cosAngIncidence1 * intensity1 * diffColour) + (vec4(0.1, 0.1, 0.1, 1) * diffColour);
outputColour = pow(totalLight, gamma);
}

// Vertex shader (program 2, torch lighted object, no texture)
#version 330

layout(location = 0) in vec4 position;
layout(location = 1) in vec4 colour;
layout(location = 2) in vec3 normal;

out vec3 modelPosition;
out vec4 diffColour;
out vec3 vertNormal;
out vec3 modTorchPos;

uniform mat4 mod_to_world;
uniform mat4 world_to_clip;
uniform mat4 world_to_mod;
uniform vec4 worldTorchPos;

void main() {
modelPosition = position.xyz;
diffColour = colour;
vertNormal = normal;
vec4 modTorchPos_ = world_to_mod * worldTorchPos;
modTorchPos = modTorchPos_.xyz;
vec4 worldPos = mod_to_world * position;
gl_Position = world_to_clip * worldPos;
}

// Fragment shader (program 2, torch lighted object, no texture)
#version 330

in vec3 modelPosition;
in vec4 diffColour;
in vec3 vertNormal;
in vec3 modTorchPos;

out vec4 outputColour;

uniform int timer;

float lightAttenuation (in vec3 fragPos, in vec3 lightPos, out vec3 lightDir) {
vec3 lightDifference = fragPos - lightPos;
float distanceSqr = dot(lightDifference, lightDifference);
lightDir = lightDifference * inversesqrt(distanceSqr);
return (1 / distanceSqr);
}

void main() {
vec3 torchDir; float adjust;
if (timer > 0)
  adjust = 1;
else
  adjust = 0;
float g = 0.4545455;
vec4 gamma = vec4(g, g, g, 1);
float attenuation = lightAttenuation(modelPosition, modTorchPos, torchDir);
float cosAngIncidence = dot(vertNormal, torchDir);
cosAngIncidence = clamp(cosAngIncidence, 0, 1);

vec4 totalLight = attenuation * adjust * cosAngIncidence * vec4(3, 3, 3, 1) * diffColour;
outputColour = pow(totalLight, gamma);
}

// Vertex shader (program 3, torch lighted object with texture)
#version 330

layout(location = 0) in vec4 position;
layout(location = 1) in vec2 texCoord;
layout(location = 2) in vec3 normal;

out vec3 modelPosition;
out vec2 tex_coord;
out vec3 vertNormal;
out vec3 modTorchPos;

uniform mat4 mod_to_world;
uniform mat4 world_to_clip;
uniform mat4 world_to_mod;
uniform vec4 worldTorchPos;

void main() {
modelPosition = position.xyz;
tex_coord = texCoord;
vertNormal = normal;
vec4 modTorchPos_ = world_to_mod * worldTorchPos;
modTorchPos = modTorchPos_.xyz;
vec4 worldPos = mod_to_world * position;
gl_Position = world_to_clip * worldPos;
}

// Fragment shader (program 3, torch lighted object with texture)
#version 330

in vec3 modelPosition;
in vec2 tex_coord;
in vec3 vertNormal;
in vec3 modTorchPos;

out vec4 outputColour;

uniform sampler2D tex_unit0;
uniform int timer;

float lightAttenuation (in vec3 fragPos, in vec3 lightPos, out vec3 lightDir) {
vec3 lightDifference = fragPos - lightPos;
float distanceSqr = dot(lightDifference, lightDifference);
lightDir = lightDifference * inversesqrt(distanceSqr);
return (1 / distanceSqr);
}

void main() {
vec3 torchDir; float adjust;
if (timer > 0)
  adjust = 1;
else
  adjust = 0;
float g = 0.4545455;
vec4 gamma = vec4(g, g, g, 1);
float attenuation = lightAttenuation(modelPosition, modTorchPos, torchDir);
float cosAngIncidence = dot(vertNormal, torchDir);
cosAngIncidence = clamp(cosAngIncidence, 0, 1);
vec4 diffColour = texture(tex_unit0, tex_coord);

vec4 totalLight = attenuation * adjust * cosAngIncidence * vec4(3, 3, 3, 1) * diffColour;
outputColour = pow(totalLight, gamma);
}

// Vertex shader (program 4, message tile)
#version 330

layout(location = 0) in vec4 position;
layout(location = 1) in vec2 texCoord;
layout(location = 2) in vec3 normal;
out vec2 tex_coord;

uniform mat4 tt_matrix;

void main() {
tex_coord = texCoord;
gl_Position = tt_matrix * position;
}

// Fragment shader (program 4, message tile)
#version 330

in vec2 tex_coord;
out vec4 outputColour;

uniform sampler2D tex_unit0;
uniform int mode;

void main() {
vec4 tex_colour = texture(tex_unit0, tex_coord);
vec4 highlight = vec4 (0, 0.75, 0, 1);
if (mode == 0)
  outputColour = tex_colour;
else
  outputColour = mix (highlight, tex_colour, 0.5);
}

// Vertex shader (program 5, two point lighted character model)
#version 330
layout(location = 0) in vec4 position;
layout(location = 1) in vec2 texCoord;
layout(location = 2) in vec3 normal;

out vec3 modelPosition;
out vec2 tex_coord;
out vec3 vertNormal;
flat out vec3 modLightPos0;
flat out vec3 modLightPos1;
flat out vec4 intensity0;
flat out vec4 intensity1;

uniform mat4 mod_to_world;
uniform mat4 world_to_clip;
uniform mat4 world_to_mod;
uniform mat4 normal_transf;
uniform vec3 lmap_pos0[100];
uniform vec3 lmap_pos1[100];
uniform vec3 lmap_int0[100];
uniform vec3 lmap_int1[100];

void main() {
modelPosition = position.xyz;
tex_coord = texCoord;
vertNormal = (normal_transf * vec4(normal, 1)).xyz;
vec4 worldPos = mod_to_world * position;
int look_up = int(worldPos.x / 10) + int(worldPos.y / 10) * 10;
vec4 worldLightPos0 = vec4(lmap_pos0[look_up], 1);
vec4 worldLightPos1 = vec4(lmap_pos1[look_up], 1);
intensity0 = vec4(lmap_int0[look_up], 1);
intensity1 = vec4(lmap_int1[look_up], 1);
modLightPos0 = (world_to_mod * worldLightPos0).xyz;
modLightPos1 = (world_to_mod * worldLightPos1).xyz;

gl_Position = world_to_clip * worldPos;
}

// Fragment shader (program 5, two point lighted character model)
#version 330
in vec3 modelPosition;
in vec2 tex_coord;
in vec3 vertNormal;
flat in vec3 modLightPos0;
flat in vec3 modLightPos1;
flat in vec4 intensity0;
flat in vec4 intensity1;

out vec4 outputColour;

uniform sampler2D tex_unit0;
uniform float lmap_t0[240];
uniform float lmap_t1[240];
uniform int t;

float lightAttenuation (in vec3 fragPos, in vec3 lightPos, out vec3 lightDir) {
vec3 lightDifference = fragPos - lightPos;
float distanceSqr = dot(lightDifference, lightDifference);
lightDir = lightDifference * inversesqrt(distanceSqr);
return (1 / distanceSqr);
}

void main() {
vec3 lightDir0; vec3 lightDir1;
float g = 0.4545455;
vec4 gamma = vec4(g, g, g, 1);
float attenuation0 = lightAttenuation(modelPosition, modLightPos0, lightDir0);
float attenuation1 = lightAttenuation(modelPosition, modLightPos1, lightDir1);
float cosAngIncidence0 = dot(vertNormal, lightDir0);
float cosAngIncidence1 = dot(vertNormal, lightDir1);
cosAngIncidence0 = clamp(cosAngIncidence0, 0, 1);
cosAngIncidence1 = clamp(cosAngIncidence1, 0, 1);
vec4 diffColour = texture(tex_unit0, tex_coord);
float adjust0 = lmap_t0[t];
float adjust1 = lmap_t1[t];
vec4 totalLight = (attenuation0 * adjust0 * cosAngIncidence0 * intensity0 * diffColour) + (attenuation1 * adjust1 * cosAngIncidence1 * intensity1 * diffColour) + (vec4(0.1, 0.1, 0.1, 1) * diffColour);
outputColour = pow(totalLight, gamma);
}

// Vertex shader (program 6, character model in dark area)
#version 330
layout(location = 0) in vec4 position;
layout(location = 1) in vec2 texCoord;

out vec2 tex_coord;

uniform mat4 mod_to_world;
uniform mat4 world_to_clip;

void main() {
tex_coord = texCoord;
vec4 worldPos = mod_to_world * position;
gl_Position = world_to_clip * worldPos;
}

// Fragment shader (program 6, character model in dark area)
#version 330
in vec2 tex_coord;

out vec4 outputColour;

uniform sampler2D tex_unit0;

void main() {
outputColour = texture(tex_unit0, tex_coord);
}
