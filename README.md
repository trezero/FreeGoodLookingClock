# Clock

A clean, modern desktop clock for Windows 11 — a lightweight, ad-free, fully-local
alternative to apps like *Alarm Clock HD*. Built as a Progressive Web App (PWA) so it
installs like a real program, runs in its own window, and works offline.

## Features

- Big, thin, modern digits (`Segoe UI Variable`)
- AM/PM and seconds stacked to the right, full date below
- **12 / 24-hour** toggle
- **Show / hide seconds**
- **5 built-in background themes** (cycle with the *Theme* button)
- **Use your own photo** as the background (*Photo* button) — saved locally
- **Fullscreen** (button, double-click anywhere, or press `F`)
- Controls auto-hide after a couple seconds of no mouse movement
- Settings persist between launches; no internet, accounts, ads, or telemetry

## Run it (recommended: the desktop shortcut)

Double-click the **Clock** shortcut on the Desktop. It opens a chromeless window
(no tabs / address bar) **always at the same position and size**, then you're done.

How it works: [`clock.vbs`](clock.vbs) launches Edge in *app mode* using a dedicated
Edge profile (`%LOCALAPPDATA%\FreeGoodLookingClock-Edge`). Because the clock has its own
profile, the `--window-position` / `--window-size` flags are honored on every launch, so
it never drifts. It also starts the local file server in the background (hidden) so the
page always loads.

### Move or resize the clock

Edit the placement block near the top of [`clock.vbs`](clock.vbs):

```vbs
posX = 2343 : posY = 1224     ' top-left corner, in screen pixels
sizeW = 403 : sizeH = 175     ' width x height
```

(The current values were captured from where you had the window. Coordinates can be
negative or span past one monitor on a multi-monitor desktop.)

## Open automatically at login

Press `Win + R`, type `shell:startup`, Enter, then drop a **copy of the Desktop `Clock`
shortcut** into that folder. The clock will appear in its fixed spot every time you sign in.

## Alternative: install as a normal app

`start.bat` serves the clock at `http://localhost:8080/` in your *main* Edge; from there
you can **⋯ menu → Apps → Install this site as an app**. An installed PWA remembers its
own window position, but it isn't forced — the desktop-shortcut method above is the one
that guarantees the exact same spot/size every time.

## Customize

Everything is plain HTML/CSS/JS — edit and refresh.

- **Add/replace themes:** edit the `THEMES` array in [`app.js`](app.js). Each entry is any
  CSS `background-image` value — a gradient, or `url("images/your-photo.jpg")`.
- **Fonts / sizes / colors:** [`style.css`](style.css). Time size is the `.time`
  `font-size` (uses `clamp()` to scale with the window); weight is `font-weight: 200`.
- **Default background tint / overlay darkness:** the `.overlay` rule in `style.css`.

## Files

| File | Purpose |
|------|---------|
| `index.html` | Markup |
| `style.css` | All styling |
| `app.js` | Clock logic, settings, background switching |
| `manifest.webmanifest` | PWA metadata (name, icons, standalone window) |
| `sw.js` | Service worker — offline caching / installability |
| `icons/` | App icons (`clock.ico` is used by the desktop shortcut) |
| `clock.vbs` | One-click launcher: chromeless window, fixed position + size |
| `start.bat` | Serves the clock in your main Edge (for installing / re-caching) |
