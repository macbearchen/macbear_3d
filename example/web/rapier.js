let rapier_exports;
let vec3_buffer_ptr = 0;
let quat_buffer_ptr = 0;
let query_ray_buffer_ptr = 0;
let query_shape_buffer_ptr = 0;
let query_proj_buffer_ptr = 0;
let query_desc_buffer_ptr = 0;
let query_list_buffer_ptr = 0;

// ==========================================
// Initialization & Version
// ==========================================

window.rapier_init = async function () {
    if (rapier_exports) {
        // Already initialized — skip re-loading WASM to avoid replacing the live
        // module instance (which would cause "unreachable" errors from stale handles).
        return;
    }
    const response = await fetch('rapier_ffi.wasm');
    const buffer = await response.arrayBuffer();
    const { instance } = await WebAssembly.instantiate(buffer, {});
    rapier_exports = instance.exports;
    console.log("Rapier WASM loaded", rapier_exports);
};

window.rapier_version = () => {
    const ptr = rapier_exports.rapier_version();
    const memory = new Uint8Array(rapier_exports.memory.buffer);
    let str = "";
    let i = ptr;
    while (memory[i] !== 0) {
        str += String.fromCharCode(memory[i]);
        i++;
    }
    return str;
};

// ==========================================
// World
// ==========================================

window.rapier_world_create = () => rapier_exports.rapier_world_create();
window.rapier_world_destroy = (world) => rapier_exports.rapier_world_destroy(world);
window.rapier_world_set_gravity = (world, x, y, z) => rapier_exports.rapier_world_set_gravity(world, x, y, z);
window.rapier_world_step = (world) => rapier_exports.rapier_world_step(world);
window.rapier_world_get_timestep = (world) => rapier_exports.rapier_world_get_timestep(world);
window.rapier_world_set_timestep = (world, dt) => rapier_exports.rapier_world_set_timestep(world, dt);

// ==========================================
// Rigid Body
// ==========================================

window.rapier_rigid_body_create = (world, x, y, z, type) =>
    rapier_exports.rapier_rigid_body_create(world, x, y, z, type);

window.rapier_rigid_body_get_position = (world, body) => {
    if (vec3_buffer_ptr === 0) {
        vec3_buffer_ptr = rapier_exports.rapier_malloc(12);
    }
    rapier_exports.rapier_rigid_body_get_position(vec3_buffer_ptr, world, body);
    return vec3_buffer_ptr;
};

window.rapier_rigid_body_get_rotation = (world, body) => {
    if (quat_buffer_ptr === 0) {
        quat_buffer_ptr = rapier_exports.rapier_malloc(16);
    }
    rapier_exports.rapier_rigid_body_get_rotation(quat_buffer_ptr, world, body);
    return quat_buffer_ptr;
};

window.rapier_rigid_body_set_position = (world, body, x, y, z) =>
    rapier_exports.rapier_rigid_body_set_position(world, body, x, y, z);

window.rapier_rigid_body_set_rotation = (world, body, x, y, z, w) =>
    rapier_exports.rapier_rigid_body_set_rotation(world, body, x, y, z, w);

window.rapier_rigid_body_wake = (world, body) =>
    rapier_exports.rapier_rigid_body_wake(world, body);

window.rapier_rigid_body_set_ccd = (world, body, enabled) => rapier_exports.rapier_rigid_body_set_ccd(world, body, enabled);
window.rapier_rigid_body_set_linear_damping = (world, handle, damping) => rapier_exports.rapier_rigid_body_set_linear_damping(world, handle, damping);
window.rapier_rigid_body_set_angular_damping = (world, handle, damping) => rapier_exports.rapier_rigid_body_set_angular_damping(world, handle, damping);

window.rapier_rigid_body_add_force = (world, handle, x, y, z) => rapier_exports.rapier_rigid_body_add_force(world, handle, x, y, z);
window.rapier_rigid_body_add_torque = (world, handle, x, y, z) => rapier_exports.rapier_rigid_body_add_torque(world, handle, x, y, z);
window.rapier_rigid_body_apply_impulse = (world, handle, x, y, z) => rapier_exports.rapier_rigid_body_apply_impulse(world, handle, x, y, z);
window.rapier_rigid_body_apply_torque_impulse = (world, handle, x, y, z) => rapier_exports.rapier_rigid_body_apply_torque_impulse(world, handle, x, y, z);
window.rapier_rigid_body_add_force_at_point = (world, handle, fx, fy, fz, px, py, pz) => rapier_exports.rapier_rigid_body_add_force_at_point(world, handle, fx, fy, fz, px, py, pz);
window.rapier_rigid_body_apply_impulse_at_point = (world, handle, ix, iy, iz, px, py, pz) => rapier_exports.rapier_rigid_body_apply_impulse_at_point(world, handle, ix, iy, iz, px, py, pz);
window.rapier_rigid_body_set_linear_velocity = (world, handle, x, y, z) => rapier_exports.rapier_rigid_body_set_linear_velocity(world, handle, x, y, z);
window.rapier_rigid_body_set_angular_velocity = (world, handle, x, y, z) => rapier_exports.rapier_rigid_body_set_angular_velocity(world, handle, x, y, z);
window.rapier_rigid_body_remove = (world, handle) => rapier_exports.rapier_rigid_body_remove(world, handle);

// ==========================================
// Collider
// ==========================================

window.rapier_collider_create = (world, body, shapeType, hx, hy, hz, r, hh, friction, restitution, density, px, py, pz, rx, ry, rz, rw, isSensor) => {
    const size = 65; // 16 fields * 4 bytes + 1 byte for bool
    const ptr = rapier_exports.rapier_malloc(size);
    const view = new DataView(rapier_exports.memory.buffer);
    view.setUint32(ptr, shapeType, true);
    view.setFloat32(ptr + 4, hx, true);
    view.setFloat32(ptr + 8, hy, true);
    view.setFloat32(ptr + 12, hz, true);
    view.setFloat32(ptr + 16, r, true);
    view.setFloat32(ptr + 20, hh, true);
    view.setFloat32(ptr + 24, friction, true);
    view.setFloat32(ptr + 28, restitution, true);
    view.setFloat32(ptr + 32, density, true);
    view.setFloat32(ptr + 36, px, true);
    view.setFloat32(ptr + 40, py, true);
    view.setFloat32(ptr + 44, pz, true);
    view.setFloat32(ptr + 48, rx, true);
    view.setFloat32(ptr + 52, ry, true);
    view.setFloat32(ptr + 56, rz, true);
    view.setFloat32(ptr + 60, rw, true);
    view.setUint8(ptr + 64, isSensor ? 1 : 0);
    const handle = rapier_exports.rapier_collider_create(world, body, ptr);
    rapier_exports.rapier_free(ptr, size);
    return handle;
};

window.rapier_collider_create_heightfield = (world, body, heights, nrows, ncols, sx, sy, sz) => {
    const len = nrows * ncols;
    const size = len * 4;
    const ptr = rapier_exports.rapier_malloc(size);
    const heap = new Float32Array(rapier_exports.memory.buffer, ptr, len);
    heap.set(heights);
    const handle = rapier_exports.rapier_collider_create_heightfield(world, body, ptr, nrows, ncols, sx, sy, sz);
    rapier_exports.rapier_free(ptr, size);
    return handle;
};

window.rapier_collider_get_position = (world, handle) => {
    if (vec3_buffer_ptr === 0) {
        vec3_buffer_ptr = rapier_exports.rapier_malloc(12);
    }
    rapier_exports.rapier_collider_get_position(vec3_buffer_ptr, world, handle);
    return vec3_buffer_ptr;
};

window.rapier_collider_get_rotation = (world, handle) => {
    if (quat_buffer_ptr === 0) {
        quat_buffer_ptr = rapier_exports.rapier_malloc(16);
    }
    rapier_exports.rapier_collider_get_rotation(quat_buffer_ptr, world, handle);
    return quat_buffer_ptr;
};

window.rapier_collider_get_friction = (world, handle) => rapier_exports.rapier_collider_get_friction(world, handle);
window.rapier_collider_get_restitution = (world, handle) => rapier_exports.rapier_collider_get_restitution(world, handle);
window.rapier_collider_get_density = (world, handle) => rapier_exports.rapier_collider_get_density(world, handle);

window.rapier_collider_set_friction = (world, handle, friction) => rapier_exports.rapier_collider_set_friction(world, handle, friction);
window.rapier_collider_set_restitution = (world, handle, restitution) => rapier_exports.rapier_collider_set_restitution(world, handle, restitution);
window.rapier_collider_set_density = (world, handle, density) =>
    rapier_exports.rapier_collider_set_density(world, handle, density);

window.rapier_collider_set_position = (world, handle, x, y, z) =>
    rapier_exports.rapier_collider_set_position(world, handle, x, y, z);

window.rapier_collider_set_rotation = (world, handle, x, y, z, w) =>
    rapier_exports.rapier_collider_set_rotation(world, handle, x, y, z, w);

window.rapier_collider_remove = (world, handle) => rapier_exports.rapier_collider_remove(world, handle);

// ==========================================
// Joint
// ==========================================

window.rapier_joint_create_fixed = (world, b1, b2, a1x, a1y, a1z, r1x, r1y, r1z, r1w, a2x, a2y, a2z, r2x, r2y, r2z, r2w) =>
    rapier_exports.rapier_joint_create_fixed(world, b1, b2, a1x, a1y, a1z, r1x, r1y, r1z, r1w, a2x, a2y, a2z, r2x, r2y, r2z, r2w);

window.rapier_joint_create_spherical = (world, b1, b2, a1x, a1y, a1z, a2x, a2y, a2z) =>
    rapier_exports.rapier_joint_create_spherical(world, b1, b2, a1x, a1y, a1z, a2x, a2y, a2z);

window.rapier_joint_create_revolute = (world, b1, b2, vx, vy, vz, a1x, a1y, a1z, a2x, a2y, a2z) =>
    rapier_exports.rapier_joint_create_revolute(world, b1, b2, vx, vy, vz, a1x, a1y, a1z, a2x, a2y, a2z);

window.rapier_joint_create_prismatic = (world, b1, b2, vx, vy, vz, a1x, a1y, a1z, a2x, a2y, a2z) =>
    rapier_exports.rapier_joint_create_prismatic(world, b1, b2, vx, vy, vz, a1x, a1y, a1z, a2x, a2y, a2z);

window.rapier_joint_create_generic = (world, b1, b2, a1x, a1y, a1z, a2x, a2y, a2z) =>
    rapier_exports.rapier_joint_create_generic(world, b1, b2, a1x, a1y, a1z, a2x, a2y, a2z);

window.rapier_joint_create_rope = (world, b1, b2, a1x, a1y, a1z, a2x, a2y, a2z, maxDist) =>
    rapier_exports.rapier_joint_create_rope(world, b1, b2, a1x, a1y, a1z, a2x, a2y, a2z, maxDist);

window.rapier_joint_lock_axis = (world, joint, axis, locked) =>
    rapier_exports.rapier_joint_lock_axis(world, joint, axis, locked);

window.rapier_joint_set_limits = (world, joint, axis, min, max) =>
    rapier_exports.rapier_joint_set_limits(world, joint, axis, min, max);

window.rapier_joint_configure_motor = (world, joint, axis, targetPos, targetVel, stiffness, damping) =>
    rapier_exports.rapier_joint_configure_motor(world, joint, axis, targetPos, targetVel, stiffness, damping);

window.rapier_joint_configure_revolute_motor = (world, joint, targetPos, targetVel, stiffness, damping) =>
    rapier_exports.rapier_joint_configure_revolute_motor(world, joint, targetPos, targetVel, stiffness, damping);

window.rapier_joint_configure_prismatic_motor = (world, joint, targetPos, targetVel, stiffness, damping) =>
    rapier_exports.rapier_joint_configure_prismatic_motor(world, joint, targetPos, targetVel, stiffness, damping);

window.rapier_joint_remove = (world, handle) => rapier_exports.rapier_joint_remove(world, handle);

// ==========================================
// Kinematic Character Controller
// ==========================================

window.rapier_character_controller_create = (offset) =>
    rapier_exports.rapier_character_controller_create(offset);

window.rapier_character_controller_destroy = (ctrl) =>
    rapier_exports.rapier_character_controller_destroy(ctrl);

window.rapier_character_controller_set_up = (ctrl, x, y, z) =>
    rapier_exports.rapier_character_controller_set_up(ctrl, x, y, z);

window.rapier_character_controller_set_max_slope = (ctrl, angleRadians) =>
    rapier_exports.rapier_character_controller_set_max_slope(ctrl, angleRadians);

window.rapier_character_controller_set_min_slope = (ctrl, angleRadians) =>
    rapier_exports.rapier_character_controller_set_min_slope(ctrl, angleRadians);

window.rapier_character_controller_set_snap_to_ground = (ctrl, distance, enabled) =>
    rapier_exports.rapier_character_controller_set_snap_to_ground(ctrl, distance, enabled);

window.rapier_character_controller_set_autostep = (ctrl, maxHeight, minWidth, includeDynamicBodies) =>
    rapier_exports.rapier_character_controller_set_autostep(ctrl, maxHeight, minWidth, includeDynamicBodies);

window.rapier_character_controller_move = (world, ctrl, colliderHandle, dx, dy, dz, dt) => {
    if (vec3_buffer_ptr === 0) {
        vec3_buffer_ptr = rapier_exports.rapier_malloc(12);
    }
    rapier_exports.rapier_character_controller_move(vec3_buffer_ptr, world, ctrl, colliderHandle, dx, dy, dz, dt);
    return vec3_buffer_ptr;
};

window.rapier_character_controller_is_grounded = (ctrl) =>
    rapier_exports.rapier_character_controller_is_grounded(ctrl) !== 0;

window.rapier_character_controller_is_on_wall = (ctrl) =>
    rapier_exports.rapier_character_controller_is_on_wall(ctrl) !== 0;

window.rapier_character_controller_is_on_ceiling = (ctrl) =>
    rapier_exports.rapier_character_controller_is_on_ceiling(ctrl) !== 0;

window.rapier_vec3_get_x = (ptr) => {
    const view = new DataView(rapier_exports.memory.buffer);
    return view.getFloat32(ptr, true);
};

window.rapier_vec3_get_y = (ptr) => {
    const view = new DataView(rapier_exports.memory.buffer);
    return view.getFloat32(ptr + 4, true);
};

window.rapier_vec3_get_z = (ptr) => {
    const view = new DataView(rapier_exports.memory.buffer);
    return view.getFloat32(ptr + 8, true);
};

window.rapier_quat_get_x = (ptr) => {
    const view = new DataView(rapier_exports.memory.buffer);
    return view.getFloat32(ptr, true);
};

window.rapier_quat_get_y = (ptr) => {
    const view = new DataView(rapier_exports.memory.buffer);
    return view.getFloat32(ptr + 4, true);
};

window.rapier_quat_get_z = (ptr) => {
    const view = new DataView(rapier_exports.memory.buffer);
    return view.getFloat32(ptr + 8, true);
};

window.rapier_quat_get_w = (ptr) => {
    const view = new DataView(rapier_exports.memory.buffer);
    return view.getFloat32(ptr + 12, true);
};

window.rapier_world_cast_ray = (world, ox, oy, oz, dx, dy, dz, max_toi, solid, exclude_collider, exclude_rigid_body) => {
    if (query_ray_buffer_ptr === 0) {
        query_ray_buffer_ptr = rapier_exports.rapier_malloc(40);
    }
    rapier_exports.rapier_world_cast_ray(query_ray_buffer_ptr, world, ox, oy, oz, dx, dy, dz, max_toi, solid ? 1 : 0, exclude_collider, exclude_rigid_body);
    return query_ray_buffer_ptr;
};

window.rapier_world_cast_ray_and_get_normal = (world, ox, oy, oz, dx, dy, dz, max_toi, solid, exclude_collider, exclude_rigid_body) => {
    if (query_ray_buffer_ptr === 0) {
        query_ray_buffer_ptr = rapier_exports.rapier_malloc(40);
    }
    rapier_exports.rapier_world_cast_ray_and_get_normal(query_ray_buffer_ptr, world, ox, oy, oz, dx, dy, dz, max_toi, solid ? 1 : 0, exclude_collider, exclude_rigid_body);
    return query_ray_buffer_ptr;
};

window.rapier_world_cast_shape = (world, px, py, pz, rx, ry, rz, rw, vx, vy, vz, shapeType, hx, hy, hz, radius, halfHeight, friction, restitution, density, locX, locY, locZ, rotX, rotY, rotZ, rotW, isSensor, maxToi, stopAtPenetration, excludeCollider, excludeRigidBody) => {
    if (query_shape_buffer_ptr === 0) {
        query_shape_buffer_ptr = rapier_exports.rapier_malloc(40);
    }
    if (query_desc_buffer_ptr === 0) {
        query_desc_buffer_ptr = rapier_exports.rapier_malloc(72);
    }
    const view = new DataView(rapier_exports.memory.buffer);
    view.setUint32(query_desc_buffer_ptr, shapeType, true);
    view.setFloat32(query_desc_buffer_ptr + 4, hx, true);
    view.setFloat32(query_desc_buffer_ptr + 8, hy, true);
    view.setFloat32(query_desc_buffer_ptr + 12, hz, true);
    view.setFloat32(query_desc_buffer_ptr + 16, radius, true);
    view.setFloat32(query_desc_buffer_ptr + 20, halfHeight, true);
    view.setFloat32(query_desc_buffer_ptr + 24, friction, true);
    view.setFloat32(query_desc_buffer_ptr + 28, restitution, true);
    view.setFloat32(query_desc_buffer_ptr + 32, density, true);
    view.setFloat32(query_desc_buffer_ptr + 36, locX, true);
    view.setFloat32(query_desc_buffer_ptr + 40, locY, true);
    view.setFloat32(query_desc_buffer_ptr + 44, locZ, true);
    view.setFloat32(query_desc_buffer_ptr + 48, rotX, true);
    view.setFloat32(query_desc_buffer_ptr + 52, rotY, true);
    view.setFloat32(query_desc_buffer_ptr + 56, rotZ, true);
    view.setFloat32(query_desc_buffer_ptr + 60, rotW, true);
    view.setUint8(query_desc_buffer_ptr + 64, isSensor ? 1 : 0);

    rapier_exports.rapier_world_cast_shape(query_shape_buffer_ptr, world, px, py, pz, rx, ry, rz, rw, vx, vy, vz, query_desc_buffer_ptr, maxToi, stopAtPenetration ? 1 : 0, excludeCollider, excludeRigidBody);
    return query_shape_buffer_ptr;
};

window.rapier_world_project_point = (world, px, py, pz, solid, excludeCollider, excludeRigidBody) => {
    if (query_proj_buffer_ptr === 0) {
        query_proj_buffer_ptr = rapier_exports.rapier_malloc(24);
    }
    rapier_exports.rapier_world_project_point(query_proj_buffer_ptr, world, px, py, pz, solid ? 1 : 0, excludeCollider, excludeRigidBody);
    return query_proj_buffer_ptr;
};

window.rapier_world_intersections_with_point = (world, px, py, pz, excludeCollider, excludeRigidBody) => {
    if (query_list_buffer_ptr === 0) {
        query_list_buffer_ptr = rapier_exports.rapier_malloc(512);
    }
    const count = rapier_exports.rapier_world_intersections_with_point(world, px, py, pz, excludeCollider, excludeRigidBody, query_list_buffer_ptr, 128);
    const view = new DataView(rapier_exports.memory.buffer);
    const result = [];
    for (let i = 0; i < count && i < 128; i++) {
        result.push(view.getUint32(query_list_buffer_ptr + i * 4, true));
    }
    return result;
};

window.rapier_world_intersection_with_shape = (world, px, py, pz, rx, ry, rz, rw, shapeType, hx, hy, hz, radius, halfHeight, friction, restitution, density, locX, locY, locZ, rotX, rotY, rotZ, rotW, isSensor, excludeCollider, excludeRigidBody) => {
    if (query_desc_buffer_ptr === 0) {
        query_desc_buffer_ptr = rapier_exports.rapier_malloc(72);
    }
    const view = new DataView(rapier_exports.memory.buffer);
    view.setUint32(query_desc_buffer_ptr, shapeType, true);
    view.setFloat32(query_desc_buffer_ptr + 4, hx, true);
    view.setFloat32(query_desc_buffer_ptr + 8, hy, true);
    view.setFloat32(query_desc_buffer_ptr + 12, hz, true);
    view.setFloat32(query_desc_buffer_ptr + 16, radius, true);
    view.setFloat32(query_desc_buffer_ptr + 20, halfHeight, true);
    view.setFloat32(query_desc_buffer_ptr + 24, friction, true);
    view.setFloat32(query_desc_buffer_ptr + 28, restitution, true);
    view.setFloat32(query_desc_buffer_ptr + 32, density, true);
    view.setFloat32(query_desc_buffer_ptr + 36, locX, true);
    view.setFloat32(query_desc_buffer_ptr + 40, locY, true);
    view.setFloat32(query_desc_buffer_ptr + 44, locZ, true);
    view.setFloat32(query_desc_buffer_ptr + 48, rotX, true);
    view.setFloat32(query_desc_buffer_ptr + 52, rotY, true);
    view.setFloat32(query_desc_buffer_ptr + 56, rotZ, true);
    view.setFloat32(query_desc_buffer_ptr + 60, rotW, true);
    view.setUint8(query_desc_buffer_ptr + 64, isSensor ? 1 : 0);

    return rapier_exports.rapier_world_intersection_with_shape(world, px, py, pz, rx, ry, rz, rw, query_desc_buffer_ptr, excludeCollider, excludeRigidBody);
};

window.rapier_ray_get_collider = (ptr) => new DataView(rapier_exports.memory.buffer).getUint32(ptr, true);
window.rapier_ray_get_rigid_body = (ptr) => new DataView(rapier_exports.memory.buffer).getUint32(ptr + 4, true);
window.rapier_ray_get_toi = (ptr) => new DataView(rapier_exports.memory.buffer).getFloat32(ptr + 8, true);
window.rapier_ray_get_point_x = (ptr) => new DataView(rapier_exports.memory.buffer).getFloat32(ptr + 12, true);
window.rapier_ray_get_point_y = (ptr) => new DataView(rapier_exports.memory.buffer).getFloat32(ptr + 16, true);
window.rapier_ray_get_point_z = (ptr) => new DataView(rapier_exports.memory.buffer).getFloat32(ptr + 20, true);
window.rapier_ray_get_normal_x = (ptr) => new DataView(rapier_exports.memory.buffer).getFloat32(ptr + 24, true);
window.rapier_ray_get_normal_y = (ptr) => new DataView(rapier_exports.memory.buffer).getFloat32(ptr + 28, true);
window.rapier_ray_get_normal_z = (ptr) => new DataView(rapier_exports.memory.buffer).getFloat32(ptr + 32, true);
window.rapier_ray_get_hit = (ptr) => new DataView(rapier_exports.memory.buffer).getUint8(ptr + 36) !== 0;

window.rapier_proj_get_collider = (ptr) => new DataView(rapier_exports.memory.buffer).getUint32(ptr, true);
window.rapier_proj_get_rigid_body = (ptr) => new DataView(rapier_exports.memory.buffer).getUint32(ptr + 4, true);
window.rapier_proj_get_point_x = (ptr) => new DataView(rapier_exports.memory.buffer).getFloat32(ptr + 8, true);
window.rapier_proj_get_point_y = (ptr) => new DataView(rapier_exports.memory.buffer).getFloat32(ptr + 12, true);
window.rapier_proj_get_point_z = (ptr) => new DataView(rapier_exports.memory.buffer).getFloat32(ptr + 16, true);
window.rapier_proj_get_is_inside = (ptr) => new DataView(rapier_exports.memory.buffer).getUint8(ptr + 20) !== 0;
window.rapier_proj_get_hit = (ptr) => new DataView(rapier_exports.memory.buffer).getUint8(ptr + 21) !== 0;


// ==========================================
// Memory Management
// ==========================================

window.rapier_malloc = (size) => rapier_exports.rapier_malloc(size);
window.rapier_free = (ptr, size) => rapier_exports.rapier_free(ptr, size);