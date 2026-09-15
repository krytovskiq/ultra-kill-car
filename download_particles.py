import os
import urllib.request

# Каталог для текстур
tex_dir = r"C:\Users\Cron\Documents\ultra-kill-car\assets\particles"
os.makedirs(tex_dir, exist_ok=True)

# Прямые ссылки на бесплатные текстуры Кенни (Kenney Particle Pack - Public Domain)
textures = {
    "smoke.png": "https://raw.githubusercontent.com/KenneyNL/Particles/master/PNG%20(Transparent)/smoke_04.png",
    "blood.png": "https://raw.githubusercontent.com/KenneyNL/Particles/master/PNG%20(Transparent)/dirt_02.png",
    "spark.png": "https://raw.githubusercontent.com/KenneyNL/Particles/master/PNG%20(Transparent)/trace_01.png"
}

for filename, url in textures.items():
    filepath = os.path.join(tex_dir, filename)
    print(f"Downloading {filename}...")
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req) as response:
        with open(filepath, 'wb') as f:
            f.write(response.read())

print("All textures downloaded successfully.")
