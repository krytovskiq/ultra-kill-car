shader_type canvas_item;

// Текстура экрана подтягивается Godot автоматически
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
// Сила эффекта (0.0 - нет, 1.0 - максимум помех)
uniform float effect_strength : hint_range(0.0, 1.0) = 0.0;

// Генератор случайного шума
float rand(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // Эффект работает только при активации смерти
    if (effect_strength > 0.01) {
        // 1. Создаем горизонтальные сдвиги строк (Glitch-полосы)
        float glitch_lines = step(0.92, rand(vec2(floor(uv.y * 15.0), TIME * 10.0)));
        uv.x += glitch_lines * 0.02 * sin(TIME * 50.0) * effect_strength;
        
        // 2. Дополнительные мелкие хаотичные помехи
        if (rand(vec2(TIME, uv.y)) > 0.98 - (0.1 * effect_strength)) {
            uv.x += rand(vec2(uv.y, TIME)) * 0.03 * effect_strength;
        }
    }
    
    // 3. Эффект раздвоения каналов (Красный и Синий контур / RGB Split)
    float shift = 0.007 * effect_strength;
    float r = texture(screen_texture, vec2(uv.x + shift, uv.y)).r;
    float g = texture(screen_texture, uv).g;
    float b = texture(screen_texture, vec2(uv.x - shift, uv.y)).b;
    
    vec3 final_color = vec3(r, g, b);
    
    // 4. Добавляем черную виньетку и багровые темные полосы по краям
    vec2 dist = UV - vec2(0.5);
    float vignette = dot(dist, dist);
    // Края экрана плавно уходят в темно-багровый цвет сажи и крови
    vec3 dark_red = vec3(0.12, 0.0, 0.01);
    final_color = mix(final_color, dark_red, smoothstep(0.1, 0.45, vignette) * effect_strength * 0.9);
    
    // 5. Мелкое зерно (шум) по всему экрану для текстуры «сломанного экрана»
    float noise = (rand(uv + vec2(TIME)) - 0.5) * 0.12 * effect_strength;
    final_color += vec3(noise);
    
    COLOR = vec4(final_color, 1.0);
}
