# Credits

Project code and original assets: Mozilla Public License 2.0 (see LICENSE).
The third-party assets below keep their own licenses.

- "Nissan Skyline R34 GT-R C-West (1999)" by Thcyrax (https://sketchfab.com/thcyrax),
  licensed under CC BY 4.0 (http://creativecommons.org/licenses/by/4.0/).
  Source: https://sketchfab.com/3d-models/nissan-skyline-r34-gt-r-c-west-1999-90fb84688b954ceba27d36c7d3785ed5
  File: `cars/r34.glb`, unmodified.
- Traffic, police, ambulance, fire truck and wheel loader models from "Car Kit" by Kenney (https://kenney.nl/assets/car-kit),
  CC0 1.0. Files: `cars/kenney/`, unmodified.
- Sounds (all CC0 1.0, from OpenGameArt.org unless noted; files in `audio/`, some trimmed/re-encoded):
  rain.ogg "AMB Rain Loop 1" by Kresiek The Furry · thunder.ogg cut from "Rain + Long Thunder" by WuxiaScrub ·
  siren.ogg "Sirens and Alarm Noise" by aquinn · engine.wav "racing car engine sound loops" by domasx2 ·
  crash.ogg "Crash Collision" by qubodup · whoosh.wav "Swishes Sound Pack" by artisticdude ·
  boost.ogg "Boost or Launch or Thruster Sound Effect" by EZduzziteh ·
  pass.ogg "Race Care" by SoundReality (Pixabay, https://pixabay.com/sound-effects/city-race-care-151963/,
  Pixabay Content License; trimmed) ·
  click.ogg, confirm.ogg "Interface Sounds" by Kenney (kenney.nl).
- Music (CC0 1.0, OpenGameArt.org; re-encoded and loudness-normalized, `audio/music/`):
  "Midnight Drive" by congusbongus · "Space City" by MintoDog · "Synth Wave" by Pro Sensory ·
  "lofi hip hop" and "Chill lofi inspired" by omfgdude · "Midnight Cruiser" by Zane Little Music.
- Traffic and garage cars "Generic passenger car pack" by Comrade1280
  (https://sketchfab.com/3d-models/generic-passenger-car-pack-20f9af9b8a404d5cb022ac6fe87f21f5), CC BY 4.0.
  File: `cars/pack/car_pack.glb`; the vehicles are split, re-centred and recoloured at runtime (`pack.gd`).
- Roadside wreck "Destroyed Car 07 (Raw Scan)" by Renafox
  (https://sketchfab.com/3d-models/destroyed-car-07-raw-scan-916b51c7e5644eb2a6c9b3797ebb08cf), CC BY 4.0.
  File: `cars/wreck/wreck.glb`, decimated from 2.5M to 7k triangles with a 1k texture.
- Single-car models, all CC BY 4.0 from Sketchfab, prepared with `tools/prep_car.py` (metres, wheels
  regrouped, triangles reduced for mobile):
  "Low Poly Car - BMW E30 1985 White" by ROH3D
  (https://sketchfab.com/3d-models/low-poly-car-bmw-e30-1985-white-9dea494b447e442fafbddfc7eccbf158), `cars/e30/`;
  "Phoenix 455 '71 - Low poly model" by Daniel Zhabotinsky
  (https://sketchfab.com/3d-models/phoenix-455-71-low-poly-model-955edc733c6d44fabc0ad7c246a15896), `cars/phoenix/`;
  "Fairheaven LT '80 Cop Cruiser - Low poly model" by Daniel Zhabotinsky
  (https://sketchfab.com/3d-models/fairheaven-lt-80-cop-cruiser-low-poly-model-61766c1e6e1e4b2b803c174f33433a74), `cars/cop/`;
  "Fiat Doblo MK1 2000-2021" by Merc_TV
  (https://sketchfab.com/3d-models/fiat-doblo-mk1-2000-2021-11103d960278407b9e612907d26fc63c), `cars/doblo/`,
  spare wheel copied to the four wheel arches and untextured materials recoloured;
  "BMW M4csl" by Mpgs.studio3DModels
  (https://sketchfab.com/3d-models/bmw-m4csl-b53782a00cc240a191d5d7d005af1423), `cars/m4/`, reduced from 980k to 45k triangles;
  "( FREE ) Dodge Challenger SRT" by SDC PERFORMANCE™️ (@Lambo_SC04)
  (https://sketchfab.com/3d-models/free-dodge-challenger-srt-38a1fd572beb433fa2d26d8c1070c8fa), `cars/challenger/`,
  reduced from 114k to 40k triangles, body recoloured;
  "Nissan GT" by hartwelkisaka
  (https://sketchfab.com/3d-models/nissan-gt-6efe436ad3144dcf8a280daf2965c28d), `cars/gtr/`, front wheels straightened;
  "Honda civic" by Aldios
  (https://sketchfab.com/3d-models/honda-civic-ff844e296f214e709c0d0691d031c68b), `cars/civic/`,
  reduced from 672k to 48k triangles, front wheels straightened;
  "2024 BMW M5 Sedan" by Nazh Design
  (https://sketchfab.com/3d-models/2024-bmw-m5-sedan-d61d5cadc7784d988a0b623ebcba3a9f), `cars/m5/`,
  vertex colours turned into materials, hidden interior removed, reduced from 389k to 47k triangles;
  "2020 Ferrari SF90 Stradale" by Nazh Design
  (https://sketchfab.com/3d-models/2020-ferrari-sf90-stradale-26f20b26a76341089ac81a7a61a94d1a), `cars/sf90/`,
  vertex colours turned into materials, hidden interior removed, reduced from 235k to 48k triangles;
  "Mercedes-Benz Maybach 2022" by Mpgs.studio3DModels
  (https://sketchfab.com/3d-models/mercedes-benz-maybach-2022-979f37a878f04b2a8d888b62ea6027e9), `cars/maybach/`,
  helper boxes and hidden interior removed, glass made opaque, reduced from 2.4M to 96k triangles.
- App icon (`icon.png`): generated for this project with OpenAI image generation via Codex CLI.
