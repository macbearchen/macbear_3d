let rapier_exports;

// ==========================================
// Initialization & Version
// ==========================================

window.rapier_init = async function () {
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

window.rapier_rigid_body_get_position_x = (world, body) => rapier_exports.rapier_rigid_body_get_position_x(world, body);
window.rapier_rigid_body_get_position_y = (world, body) => rapier_exports.rapier_rigid_body_get_position_y(world, body);
window.rapier_rigid_body_get_position_z = (world, body) => rapier_exports.rapier_rigid_body_get_position_z(world, body);

window.rapier_rigid_body_get_rotation_x = (world, body) => rapier_exports.rapier_rigid_body_get_rotation_x(world, body);
window.rapier_rigid_body_get_rotation_y = (world, body) => rapier_exports.rapier_rigid_body_get_rotation_y(world, body);
window.rapier_rigid_body_get_rotation_z = (world, body) => rapier_exports.rapier_rigid_body_get_rotation_z(world, body);
window.rapier_rigid_body_get_rotation_w = (world, body) => rapier_exports.rapier_rigid_body_get_rotation_w(world, body);

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

window.rapier_collider_get_position_x = (world, handle) => rapier_exports.rapier_collider_get_position_x(world, handle);
window.rapier_collider_get_position_y = (world, handle) => rapier_exports.rapier_collider_get_position_y(world, handle);
window.rapier_collider_get_position_z = (world, handle) => rapier_exports.rapier_collider_get_position_z(world, handle);

window.rapier_collider_get_rotation_x = (world, handle) => rapier_exports.rapier_collider_get_rotation_x(world, handle);
window.rapier_collider_get_rotation_y = (world, handle) => rapier_exports.rapier_collider_get_rotation_y(world, handle);
window.rapier_collider_get_rotation_z = (world, handle) => rapier_exports.rapier_collider_get_rotation_z(world, handle);
window.rapier_collider_get_rotation_w = (world, handle) => rapier_exports.rapier_collider_get_rotation_w(world, handle);

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
// Memory Management
// ==========================================

window.rapier_malloc = (size) => rapier_exports.rapier_malloc(size);
window.rapier_free = (ptr, size) => rapier_exports.rapier_free(ptr, size);