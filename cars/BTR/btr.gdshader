shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

// Настройки цвета и яркости в Инспекторе
uniform vec4 core_color : source_color = vec4(1.0, 0.9, 0.5, 1.0); // Центр (бело-желтый)
uniform vec4 edge_color : source_color = vec4(1.0, 0.3, 0.0, 1.0); // Края (огненно-красный)
uniform float glow_power = 4.0; // Сила свечения

// Генератор процедурного шума для рваных краев пламени
float noise(vec3 p) {
    return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453123);
}

void fragment() {
    // Делаем затухание от начала ствола к кончику конуса (по координате Y или V)
    float gradient = smoothstep(1.0, 0.0, UV.y);
    
    // Создаем быструю смену кадров шума (имитация хаотичного взрыва газов)
    float time_step = floor(TIME * 30.0); // 30 изменений в секунду
    float n = noise(vec3(UV * 6.0, time_step));
    
    // Формируем рваный силуэт огня
    float fire_mask = gradient * (n * 1.5);
    float alpha = smoothstep(0.3, 0.7, fire_mask);
    
    // Смешиваем цвета: внутри яркий свет, по краям красный огонь
    vec3 final_color = mix(edge_color.rgb, core_color.rgb, smoothstep(0.4, 0.8, fire_mask));
    
    // Выводим результат
    ALBEDO = final_color * glow_power;
    ALPHA = alpha * gradient;
}
