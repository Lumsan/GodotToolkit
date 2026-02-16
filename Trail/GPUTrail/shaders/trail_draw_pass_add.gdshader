shader_type spatial;

render_mode world_vertex_coords, cull_disabled, depth_draw_never, shadows_disabled, ambient_light_disabled, blend_add;

uniform sampler2D tex : repeat_disable, source_color, hint_default_white;
uniform bool texture_repeat = true;
uniform sampler2D mask : hint_default_white;
uniform float mask_strength = 1.0;
uniform vec2 uv_offset = vec2(0);
uniform sampler2D color_ramp : repeat_disable, source_color, hint_default_white;
uniform sampler2D curve : repeat_disable, hint_default_white;
uniform mat4 emmission_transform = mat4(1);
uniform int flags = 0;
uniform float trail_length = 100.0;

uniform bool use_path_emission = false;
uniform sampler2D path_texture : filter_linear, repeat_disable;
uniform int path_point_count = 0;
uniform float ribbon_width = 0.05;

uniform float emission_strength : hint_range(0.0, 16.0) = 0.0;

#define vertical_texture  bool(flags & 1)
#define use_red_as_alpha  bool(flags & 2)
#define billboard         bool(flags & 4)
#define dewiggle          bool(flags & 8)
#define snap_to_transform bool(flags & 16)
#define clip_overlaps     bool(flags & 32)

varying float scale_interp;
varying vec2 clip;
varying vec2 mesh_uv;
varying float v_is_path;
varying float v_hide;

void vertex() {
	mesh_uv = UV;
	v_is_path = 0.0;
	v_hide = 0.0;

	mat4 my_model_matrix = MODEL_MATRIX;

	if (use_path_emission && path_point_count > 0) {
		v_is_path = 1.0;

		vec3 old_a = my_model_matrix[0].xyz;
		vec3 new_a = my_model_matrix[1].xyz;
		vec3 new_b = my_model_matrix[2].xyz;
		vec3 old_b = my_model_matrix[3].xyz;

		vec3 old_c = INSTANCE_CUSTOM.xyz;
		vec3 new_c = COLOR.xyz;
		float trail_len = trail_length;
		float particle_age = INSTANCE_CUSTOM.w - 1.0;

		// COLOR.a < 0 means the particle hasn't completed its first cycle yet
		bool has_cycled = COLOR.a > 0.0;

		if (snap_to_transform && INSTANCE_CUSTOM.w == 2.0) {
			vec4 ea = emmission_transform * vec4(0, 1, 0, 1);
			vec4 eb = emmission_transform * vec4(0, -1, 0, 1);
			vec4 ec = emmission_transform * vec4(1, 0, 0, 1);
			new_a = ea.xyz;
			new_b = eb.xyz;
			new_c = ec.xyz;
		}

		// Reconstruct emission transforms
		vec3 old_origin = (old_a + old_b) * 0.5;
		vec3 new_origin = (new_a + new_b) * 0.5;
		vec3 old_y = (old_a - old_b) * 0.5;
		vec3 new_y = (new_a - new_b) * 0.5;
		vec3 old_x = old_c - old_origin;
		vec3 new_x = new_c - new_origin;

		float old_s = length(old_y);
		float new_s = length(new_y);
		vec3 old_z = old_s > 0.0001
			? cross(normalize(old_x), normalize(old_y)) * old_s
			: vec3(0.0, 0.0, 1.0);
		vec3 new_z = new_s > 0.0001
			? cross(normalize(new_x), normalize(new_y)) * new_s
			: vec3(0.0, 0.0, 1.0);

		// UV.x = time (0 = new, 1 = old), UV.y = path parameter (0..1)
		float time_t = UV.x;
		float path_t = UV.y;

		// Interpolate transform along time axis
		vec3 origin_i = mix(new_origin, old_origin, time_t);
		vec3 x_i = mix(new_x, old_x, time_t);
		vec3 y_i = mix(new_y, old_y, time_t);
		vec3 z_i = mix(new_z, old_z, time_t);

		// Sample path position
		vec3 pp = textureLod(path_texture, vec2(path_t, 0.5), 0.0).xyz;
		VERTEX = origin_i + pp.x * x_i + pp.y * y_i + pp.z * z_i;

		// Compute trail_u for this vertex (position along full trail)
		float trail_u = (particle_age - 1.0 + time_t) / max(trail_len - 1.0, 1.0);
		trail_u = clamp(trail_u, 0.0, 1.0);

		// Apply curve as width scaling
		float h = textureLod(curve, vec2(trail_u, 0.5), 0.0).x;

		// Find the center of the path (midpoint) to scale width around it
		vec3 pp_center = textureLod(path_texture, vec2(0.5, 0.5), 0.0).xyz;
		vec3 center_world = origin_i + pp_center.x * x_i + pp_center.y * y_i + pp_center.z * z_i;
		vec3 to_vertex = VERTEX - center_world;

		// Hide particles that haven't completed their first full cycle
		// When uncycled, old and new are initialized to the same values,
		// producing a degenerate zero-length segment that shows as a static blob
		if (!has_cycled) {
			h = 0.0;
			v_hide = 1.0;
		}

		// Also detect zero-length segments (old == new, i.e. stationary emitter)
		// and collapse them so they don't render as a static path shape
		float segment_dist = length(new_origin - old_origin);
		if (segment_dist < 0.0001) {
			h = 0.0;
			v_hide = 1.0;
		}

		VERTEX = center_world + to_vertex * h;

		UV = vec2(trail_u, path_t);

		scale_interp = 1.0;
		clip = vec2(0.0);
		COLOR = vec4(1.0);

	} else {
		// ========== LINE EMISSION (unchanged) ==========
		if (snap_to_transform && INSTANCE_CUSTOM.w == 2.0) {
			my_model_matrix[1] = emmission_transform * vec4(0, 1, 0, 1);
			my_model_matrix[2] = emmission_transform * vec4(0, -1, 0, 1);
		}

		if (billboard) {
			vec3 t0 = my_model_matrix[0].xyz - my_model_matrix[3].xyz;
			vec3 t1 = my_model_matrix[1].xyz - my_model_matrix[2].xyz;
			vec3 up0 = length(t0) * normalize(cross(my_model_matrix[3].xyz - INV_VIEW_MATRIX[3].xyz, t0));
			vec3 up1 = length(t1) * normalize(cross(my_model_matrix[2].xyz - INV_VIEW_MATRIX[3].xyz, t1));
			my_model_matrix[0] = my_model_matrix[3];
			my_model_matrix[1] = my_model_matrix[2];
			my_model_matrix[0].xyz += up0;
			my_model_matrix[3].xyz -= up0;
			my_model_matrix[1].xyz += up1;
			my_model_matrix[2].xyz -= up1;
		}

		vec3 a = mix(my_model_matrix[1].xyz, my_model_matrix[0].xyz, UV.x);
		vec3 b = mix(my_model_matrix[2].xyz, my_model_matrix[3].xyz, UV.x);

		UV.x = (UV.x + INSTANCE_CUSTOM.w - 1.0 - 2.0) / (INSTANCE_CUSTOM.z - 1.0);

		float h = textureLod(curve, vec2(UV.x), 0.0).x;
		VERTEX = mix(a, b, (UV.y - 0.5) * h + 0.5);

		if (dewiggle) {
			scale_interp = h;
			UV *= scale_interp;
		}

		clip.x = dot(VERTEX - INV_VIEW_MATRIX[3].xyz, cross(my_model_matrix[1].xyz - INV_VIEW_MATRIX[3].xyz, my_model_matrix[2].xyz - INV_VIEW_MATRIX[3].xyz));
		clip.y = dot(VERTEX - INV_VIEW_MATRIX[3].xyz, cross(my_model_matrix[3].xyz - INV_VIEW_MATRIX[3].xyz, my_model_matrix[0].xyz - INV_VIEW_MATRIX[3].xyz));
	}
}

void fragment() {
    if (v_is_path > 0.5 && v_hide > 0.5) {
        discard;
    }

    vec2 base_uv = UV;

    if (v_is_path < 0.5 && dewiggle) {
        base_uv /= scale_interp;
    }

    vec2 raw_uv = base_uv;
    base_uv -= uv_offset;

    if (vertical_texture) {
        base_uv = base_uv.yx;
    }

    vec2 tex_uv = base_uv;
    if (texture_repeat) {
        tex_uv = fract(tex_uv);
    } else {
        tex_uv = clamp(tex_uv, vec2(0.0), vec2(1.0));
    }

    vec4 T = textureLod(tex, tex_uv, 0.0);
    vec3 col = T.rgb;
    ALPHA = T.a;

    if (use_red_as_alpha) {
        col = vec3(1);
        ALPHA = T.r;
    }

    vec2 ramp_uv = raw_uv;
    if (v_is_path > 0.5) {
        ramp_uv = vec2(raw_uv.x, 0.5);
    }
    T = textureLod(color_ramp, ramp_uv, 0.0);
    col *= T.rgb;
    ALPHA *= T.a;

    vec4 M = textureLod(mask, tex_uv, 0.0);
    ALPHA *= (M.r * mask_strength);

    if (v_is_path < 0.5 && clip_overlaps) {
        float ababab = clip.x * clip.y;
        if (ababab < 0.0) {
            if (abs(mesh_uv.x - 0.5) < 0.5)
                discard;
        }
    }

    ALBEDO = vec3(0.0);
    SPECULAR = 0.0;
    ROUGHNESS = 1.0;
    METALLIC = 0.0;
    EMISSION = col * (1.0 + emission_strength);
}