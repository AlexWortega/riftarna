# Riftbound Bodycam — Roblox Studio prototype

This is a separate Roblox/Luau prototype based on the browser arena's elemental
queue. It is a short first-person village scene, not a port of the full 8×8 game.

## Open and play

1. Install Roblox Studio on macOS or Windows and open `Riftbound-Bodycam.rbxlx`.
2. Click **Play**. The server creates the village at runtime. Roblox does not
   need the browser server or Railway for this project.
3. Use `WASD` to move, mouse to look, `Shift` to sprint. Press `Q` for fire,
   `E` for lightning, or `Q` then `E` for stormfire. Left click or press `F` to cast, `C`
   to clear the queue. Aim at a hut, fence, tree, or training raider.

The starting point is at the south end of the village road. Fire spreads among
nearby marked objects, chars them and causes roof/fence chunks to fall. Marks
fade after 15 seconds. Target and fire state run on the server; clients render
the beam, sparks, light and camera reaction.

## Included art kit

`assets/kenney-fantasy-town-kit/` contains twelve **FBX models** from Kenney's
Fantasy Town Kit 2.0 and the original CC0 license. They are included for Studio
import. Rojo cannot embed local FBX into an `.rbxlx` without uploading it to a
Roblox account, so the place opens with a complete procedural village.

To use the included models: import the desired FBX files through Studio's **3D
Importer**, create `ServerStorage/RiftboundArt`, and put imported `MeshPart` or
`Model` templates named `Fence`, `Cart`, or `Lantern` there. The world script
will clone these templates at startup. Set their size and pivot in Studio before
playing. The `Fence` template takes the place of procedural fences and remains
flammable. `Cart` and `Lantern` add props at prepared positions. The remaining
FBX files are modular pieces for constructing a custom `Hut` visual in Studio;
the generated huts remain functional until that visual is assembled.

No third-party scripts are required by the art kit. License details are in
`assets/kenney-fantasy-town-kit/License.txt`.

## Develop

The Luau source is in `src/`. Rebuild the Studio file with Rojo 7.7.1:

```sh
cd roblox
rojo build default.project.json -o Riftbound-Bodycam.rbxlx
```

`SpellRules.luau` is the selected fire/lightning subset of `dist/combat.js`.
`World.server.luau` builds the village and burnable objects. `Magic.server.luau`
validates casts, applies damage and replicates fire/collapse. The client script
controls the camera, viewmodel, HUD and visual effects.

To check the source locally: `luau tests/spell_rules.test.luau`, then compile
each file with `luau-compile --binary` and rebuild with Rojo.

## Verification status

Rojo builds the `.rbxlx` and the Luau parser accepts all scripts. The same
scripts were loaded into a Studio test place through MCP and checked in play
mode: first-person camera, movement, HUD, fire selection and casting worked.
The first playtest revealed an infinite wait for `PlayerModule`; it was fixed.
The village now uses overcast clouds, realistic lighting, textured built-in
materials and denser details. The footage's photorealistic houses, trees,
characters and hand animation still require higher fidelity imported meshes,
textures and animation; the bundled FBX kit is lower fidelity than the video.
