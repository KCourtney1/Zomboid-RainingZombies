# Raining Zombies

Project Zomboid Build 42 mod. Gameplay code lives in `Contents/mods/RainingZombies/42/media/lua/server`.
The mod ID, sandbox option names/defaults, translations, and artwork are unchanged.

## Code structure

| File | Responsibility |
| --- | --- |
| `RainingZombies_Logic.lua` | Register game events, throttle candidates, decide and initiate vaults |
| `RainingZombies/Config.lua` | Read sandbox settings with centralized defaults; preserve explicit false/zero values |
| `RainingZombies/Obstacles.lua` | Cache window/fence searches for one tick |
| `RainingZombies/Falls.lua` | Own active falls, landing detection, timeout, and delayed healing |
| `RainingZombies/Landing.lua` | Apply crawler conversion, sounds/blood, collision damage, fractures, and healing |

Modules use `require` and the `RainingZombies` namespace, without relying on a
return value from the game's module loader. Only the entry file registers events.
Each obstacle cache and fall tracker owns its state; neither exposes its internal tables.

`OnZombieUpdate` selects elevated zombies using the existing stagger/throttle
schedule. Eligible zombies are checked for stairs, windows, ledges, and then fences.
A successful vault starts a fall record. `OnTick` expires obstacle caches and
updates only tracked falls. Four stable height samples after descent trigger a
landing; health recovery follows after more than 30 ticks of delay. Records expire
after more than 300 ticks. These are simulation ticks, not elapsed seconds.

## Changes in this pass

- Split the original deeply nested routine into the modules above.
- Skip fence scans when a window or open ledge already decides the vault result.
- Fetch the landing square's moving-object collection once per impact.
- Reuse the protected height-reading function instead of allocating a closure
  for every active zombie on every tick.
- Exclude current/destination stair tiles from forced vaults, and require a drop
  of at least one floor for impact effects. Small height changes no longer become
  one floor of damage. A tracked small descent can still continue into a real fall.
- Use per-fall elapsed ticks so the scheduler's counter reset cannot delay cleanup
  or healing for another million ticks.
- Skip zombies without a current square.
- Skip new forced vaults while a zombie is attacking. This prevents the mod
  from repositioning a biting/grabbing zombie beside an opening. Existing falls
  continue to be tracked; ordinary vaults can resume once the attack ends.

The original source is preserved in `tests/fixtures/RainingZombies_Logic.original.lua`
as both a backup and a regression-test baseline. This working folder had no Git
repository when the refactor began.

On GitHub, the [`original` tag](https://github.com/KCourtney1/Zomboid-RainingZombies/tree/original)
preserves the complete original mod, and [`main`](https://github.com/KCourtney1/Zomboid-RainingZombies/tree/main)
contains the refactored version. [Compare the changes](https://github.com/KCourtney1/Zomboid-RainingZombies/compare/original...main).

## Run tests

From the project root, using Python:

```powershell
python -m pip install --target .tools/python lupa==2.8
python tests/run_tests.py
```

The test runner uses Lupa's **Lua 5.1** runtime and engine doubles. No test dependency
is needed by the mod itself. The 23 test methods cover the original event traces,
sandbox options, window/fence cases, damage/healing timing, cache invalidation,
stair guards, small drops, invalid objects, timeouts, counter rollover, and the
attack-state guard (including normal vaulting after combat).

Measured API-call counts in the doubles:

| Scenario | Original | Refactored |
| --- | ---: | ---: |
| Object-list scans for 200 zombies sharing an open-window tile in one tick | 3 | 1 |
| Moving-object list fetches for an impact with 3 occupants | 4 | 1 |

These counts demonstrate less redundant work, not an FPS benchmark. Work still
scales with elevated-zombie callbacks, unique candidate squares, active falls,
and landing-square occupants. There is no hard per-frame work budget yet.

## In-game verification before release

1. Use a disposable singleplayer Build 42 save; install the entire
   `Contents/mods/RainingZombies` folder into your local `Zomboid/mods` directory
   so the version folder and its modules stay together. Check the console for load errors.
2. Test open, smashed, closed, and barricaded windows; fences; and bare ledges.
   Toggle Instant Glass Shatter and check both current-tile and next-tile obstacles.
3. Fight zombies on stairs in both directions, including the top/bottom transitions.
   Confirm the mod does not shove them or apply fall damage during ordinary stair travel.
4. Test real one-, two-, and three-floor falls near a player and other zombies.
   Verify each sandbox toggle, zero player damage, and 0/50/100 percent healing.
5. Reproduce the Louisville drive/walk route with the same population, mod list,
   and throttle before/after. Record frame times and Lua errors, including large
   numbers of simultaneous falls. Compare normal play and fast-forward.

Automated checks do not simulate the Java/Lua bridge, animations, physics,
network ownership, or interaction with other mods. The author has reported a
successful singleplayer test in high-density Louisville: no observed stuttering
or stair-fight knockdowns, working window/ledge falls, and working impact damage
and knockdowns. Possible wall crossings remain under investigation; see
[October 25 playtest notes](docs/playtest-2026-10-25.md). Multiplayer support
remains unverified; this pass does not add network synchronization.

See [community triage](docs/community-issues.md) for reports and follow-up work.
The uploader sends only `Contents`; `tests`, `docs`, `.git`, and `.tools` stay outside it.


## Workshop upload layout

Select the outer `RainingZombies` folder under `Zomboid/Workshop` in the game's
**Workshop > Create and update items** screen. Its layout is:

```text
RainingZombies/
  workshop.txt
  preview.png
  Contents/
    mods/
      RainingZombies/
        mod.info
        icon.png
        poster.png
        42/
          mod.info
          media/
          ...
  tests/
  docs/
  ...
```

The local `workshop.txt` contains uploader settings and is not part of the
release checkpoint. Before uploading, verify that the selected item is
**3763651059**, titled **Raining Zombies**; a blank ID is not a target for updating
the existing listing. Copy-ready Steam BBCode is in
[the release description](docs/steam-description.txt). The preview reuses the
existing 256 x 256 poster. Back out to the item list and select the folder again
after changing its contents. Review the metadata before submitting; fixing the
local layout does not publish an update.

Edit the Lua files under `Contents/mods/RainingZombies/42` from now on. The
Desktop copy is the earlier backup, not the working Workshop project.


## Local playtesting

This machine has a directory junction from `%USERPROFILE%/Zomboid/mods/RainingZombies`
to this repository's `Contents/mods/RainingZombies`. It exposes the versioned mod
to the local mod selector without copying it after each edit. An older local copy
was preserved under `.tools/local-mod-backups/`. The installed game's local-mod
discovery code has verified this entry and selected its `42` folder.

1. Fully exit and restart Project Zomboid after installing the link or changing Lua.
2. Open **Mods**, find **Raining Zombies**, and enable the local entry.
3. Start a new singleplayer test save with the mod enabled. Use Custom Sandbox to
   inspect the Raining Zombies settings. An existing save has its own enabled-mod
   list; enabling a mod in the main menu alone does not update that save.
4. Test open/closed windows and real falls, then fight on stairs to check that
   ordinary stair travel does not cause impact damage.
5. Read `%USERPROFILE%/Zomboid/console.txt` if Lua errors occur. Keep editing the
   files under `Contents/mods/RainingZombies/42`; the local junction points there.

On another machine, copy the entire `Contents/mods/RainingZombies` folder into
`Zomboid/mods`, retaining `42/mod.info` and `42/media` inside it. Do not copy only
the contents of `42` directly into `Zomboid/mods/RainingZombies`.


## Release and multiplayer branches

`main` holds the tested singleplayer release. The tag
`singleplayer-2026-10-25` preserves this checkpoint, while `original` preserves
the pre-refactor source. `codex/multiplayer-coop` starts from the singleplayer
checkpoint for hosted co-op development. No multiplayer implementation is
included in this checkpoint.

Keep the Workshop checkout on `main` for the pending Steam upload. Perform
multiplayer development in a separate checkout so experimental Lua cannot enter
that upload through the live local-mod junction. The first milestone is one
zombie falling consistently for two players, followed by coordinated damage,
knockdowns, effects, ownership handoffs, and crowd testing.
