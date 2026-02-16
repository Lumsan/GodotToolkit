shader_type particles;

render_mode keep_data, disable_force, disable_velocity;

uniform bool use_path_emission = false;

void process() {
	float amount = LIFETIME;

	vec4 a = EMISSION_TRANSFORM * vec4(0, 1, 0, 1);
	vec4 b = EMISSION_TRANSFORM * vec4(0, -1, 0, 1);

	if (CUSTOM.w == 0.0) {
		CUSTOM.w = float(INDEX) + 1.0;
		TRANSFORM = mat4(a, a, b, b);

		if (use_path_emission) {
			vec4 c = EMISSION_TRANSFORM * vec4(1, 0, 0, 1);
			CUSTOM.xyz = c.xyz;
			// Mark as not yet cycled
			COLOR = vec4(c.xyz, -1.0);
		} else {
			CUSTOM.z = amount;
		}
	}

	if (CUSTOM.w == amount + 1.0) {
		CUSTOM.w = 1.0;
	}

	if (CUSTOM.w == 1.0) {
		TRANSFORM = mat4(a, a, b, b);

		if (use_path_emission) {
			vec4 c = EMISSION_TRANSFORM * vec4(1, 0, 0, 1);
			CUSTOM.xyz = c.xyz;
			// Mark as properly cycled
			COLOR = vec4(c.xyz, amount);
		}
	}

	if (CUSTOM.w == 2.0) {
		TRANSFORM[1] = a;
		TRANSFORM[2] = b;

		if (use_path_emission) {
			vec4 c = EMISSION_TRANSFORM * vec4(1, 0, 0, 1);
			COLOR = vec4(c.xyz, amount);
		}
	}

	CUSTOM.w++;
}