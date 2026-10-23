#ifndef KOOKIE_BOX3D_H
#define KOOKIE_BOX3D_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct kookie_box3d_vec3 { float x, y, z; } kookie_box3d_vec3;
typedef struct kookie_box3d_result {
    kookie_box3d_vec3 position;
    kookie_box3d_vec3 contact_normal;
    uint32_t contact_count;
    uint8_t grounded;
    uint8_t reserved[3];
} kookie_box3d_result;

typedef enum kookie_box3d_error {
    KOOKIE_BOX3D_OK = 0,
    KOOKIE_BOX3D_INVALID_ARGUMENT = 1,
    KOOKIE_BOX3D_CAPACITY_EXCEEDED = 2,
    KOOKIE_BOX3D_ALLOCATION_FAILED = 3,
    KOOKIE_BOX3D_BOX3D_FAILURE = 4,
    KOOKIE_BOX3D_PLANE_CAPACITY_EXCEEDED = 5
} kookie_box3d_error;

/*
 * Inputs and returned position use Kof fixed coordinates: eight ticks per
 * authored world unit (one authored unit maps to one Box3D metre). Position
 * is the capsule bottom center; height is the full end-to-end capsule height.
 * Limits: 65,535 vertices, 32,768 triangles, 128 contact planes per move, and
 * absolute converted geometry/position/dimensions <= 10,000,000 world units.
 * Swept movement and ray casts query static arena geometry; perimeter boxes
 * are handled by allocation-free Zig sweeps. Kof owns gravity, acceleration,
 * jump, glide, flight, timestep, gameplay, and actor-contact policy. Renderers
 * consume authoritative state; they do not run duplicate physics.
 */
int32_t kookie_box3d_create(const float *vertices_fixed_xyz, uint32_t vertex_count,
                            const int32_t *triangle_indices, uint32_t triangle_count,
                            void **out_world);
void kookie_box3d_destroy(void *world);
int32_t kookie_box3d_move(void *world, kookie_box3d_vec3 start_fixed,
                          kookie_box3d_vec3 requested_translation_fixed,
                          float radius_fixed, float full_height_fixed,
                          kookie_box3d_result *out_result);

/* Single Kof web-server arena bridge. Call begin, add exactly triangle_count
 * triangles from BoundedAuthoredCollision coordinates multiplied by eight,
 * then finish. Kof owns the server arena world and serializes all calls on its
 * authoritative simulation thread. Actor slots are adapter-owned identifiers,
 * not caller-owned Box3D handles; clearing/destroying the arena releases their
 * kinematic sensor bodies. Kof supplies fixed positions every tick; Box3D never
 * advances simulation or applies gravity. Creating a slot may allocate during
 * setup; after registration, position synchronization and collision queries do
 * not allocate. Kof retains all gameplay collision policy.
bool kookie_box3d_begin_arena(int32_t triangle_count);
bool kookie_box3d_add_arena_triangle(
    int32_t ax, int32_t ay, int32_t az,
    int32_t bx, int32_t by, int32_t bz,
    int32_t cx, int32_t cy, int32_t cz);
bool kookie_box3d_add_arena_visual_triangle(
    int32_t ax, int32_t ay, int32_t az,
    int32_t bx, int32_t by, int32_t bz,
    int32_t cx, int32_t cy, int32_t cz);
bool kookie_box3d_add_arena_box(
    int32_t min_x, int32_t min_y, int32_t min_z,
    int32_t max_x, int32_t max_y, int32_t max_z);
bool kookie_box3d_finish_arena(void);
void kookie_box3d_destroy_arena(void);
int32_t kookie_box3d_move_fixed(
    int32_t start_x, int32_t start_y, int32_t start_z,
    int32_t end_x, int32_t end_y, int32_t end_z,
    int32_t radius_fixed, int32_t full_height_fixed, bool was_grounded);
/* Static-only raycast: -1 error, 0 clear, 1 static hit. */
int32_t kookie_box3d_cast_ray_fixed(
    int32_t start_x, int32_t start_y, int32_t start_z,
    int32_t end_x, int32_t end_y, int32_t end_z);
/* Registers/updates one of 12 slots; bottom-center coordinates, radius and
 * full capsule height are Kof fixed units (8 per authored world unit). Returns
 * KOOKIE_BOX3D_OK or an error. Clear is idempotent; invalid slots are ignored.
 * Actor capsules are kinematic sensors: they are not stepped and do not affect
 * static-only move/ray APIs. No memory ownership passes to the caller. */
int32_t kookie_box3d_set_actor_capsule(
    int32_t slot, int32_t bottom_x, int32_t bottom_y, int32_t bottom_z,
    int32_t radius_fixed, int32_t full_height_fixed);
void kookie_box3d_clear_actor(int32_t slot);
/* Ray status: -1 error, 0 clear, 1 static hit, 2 actor hit. Pass -1 to ignore
 * no actor, or a registered actor slot to exclude the ray's source. After
 * status 2, kookie_box3d_result_actor_slot() returns the nearest actor slot. */
int32_t kookie_box3d_cast_ray_actors_fixed(
    int32_t ignore_actor_slot,
    int32_t start_x, int32_t start_y, int32_t start_z,
    int32_t end_x, int32_t end_y, int32_t end_z);
/* Tests candidate capsule against registered actor capsules other than slot.
 * It does not test static arena geometry and returns false for invalid input. */
bool kookie_box3d_overlap_actor_capsule_fixed(
    int32_t slot, int32_t bottom_x, int32_t bottom_y, int32_t bottom_z,
    int32_t radius_fixed, int32_t full_height_fixed);
int32_t kookie_box3d_result_actor_slot(void);
int32_t kookie_box3d_result_x_fixed(void);
int32_t kookie_box3d_result_y_fixed(void);
int32_t kookie_box3d_result_z_fixed(void);
bool kookie_box3d_result_grounded(void);
int32_t kookie_box3d_result_contacts(void);

#ifdef __cplusplus
}
#endif
#endif
