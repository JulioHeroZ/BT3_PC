# Video quality controls

The in-game Video tab and Qt launcher provide independent internal-resolution controls:

- **Auto** keeps the existing window-height mapping: up to 720p = 1x, up to 1080p = 2x, above 1080p = 3x.
- **1x, 2x, 3x** keep the selected internal scale when changing window size or fullscreen mode.
- OpenGL scale changes take effect after restarting the game. paraLLEl-GS applies its existing supersampling mapping when settings are applied.
- Software rendering does not expose the in-game internal-scale selection. Environment overrides (`PS2X_RENDER_SCALE`, `PS2X_RENDERSCALE`, `PS2X_PGS_SSAA`) retain priority.

Internal scale multiplies the game's scene buffers; it is separate from the output window resolution. Higher scales increase GPU workload and memory consumption. 4x remains outside the new selection pending broader rendering validation.

**Anisotropic Filtering** offers Off, 2x, 4x, 8x and 16x in OpenGL. The runtime detects support and limits the applied level to the GPU's supported maximum. The in-game selector only lists supported levels. Bilinear filtering must be enabled; draws that request point sampling retain anisotropy 1 to protect pixel data and palette/mask operations. Turning the option off or changing its level updates already-cached texture state when next drawn.

Anisotropic filtering improves texture sampling at oblique angles; it is not polygon-edge antialiasing. This option does not affect paraLLEl-GS or software rendering. No mipmap generation or FXAA pass is added.

Preferences are stored in the shared settings TOML under `[video]`:

```toml
render_scale_auto = false
render_scale = 2
anisotropy = 8
```

Older settings default to automatic scale and disabled anisotropy. The launcher preserves these preferences when saving other settings.

## Preference regression checks

With Qt 6 development packages installed, the standalone check verifies manual-scale preservation when changing the window, preference persistence, anisotropy selection and bilinear gating, and automatic mode. It does not require an ISO.

```sh
cmake -S tools/validation/video-controls -B build/video-controls-check
cmake --build build/video-controls-check
ctest --test-dir build/video-controls-check --output-on-failure
```

Visual quality and game-specific rendering effects still require validation in gameplay.
