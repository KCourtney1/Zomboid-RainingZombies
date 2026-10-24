# Raining Zombies

Project Zomboid Build 42 mod. Gameplay code lives in `42/media/lua/server`.
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
is needed by the mod itself. The 19 test methods cover the original event traces,
sandbox options, window/fence cases, damage/healing timing, cache invalidation,
stair guards, small drops, invalid objects, timeouts, and counter rollover.

Measured API-call counts in the doubles:

| Scenario | Original | Refactored |
| --- | ---: | ---: |
| Object-list scans for 200 zombies sharing an open-window tile in one tick | 3 | 1 |
| Moving-object list fetches for an impact with 3 occupants | 4 | 1 |

These counts demonstrate less redundant work, not an FPS benchmark. Work still
scales with elevated-zombie callbacks, unique candidate squares, active falls,
and landing-square occupants. There is no hard per-frame work budget yet.

## In-game verification before release

1. Use a disposable singleplayer Build 42 save; install the entire `42` mod folder
   so the entry file and its modules stay together. Check the console for load errors.
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
network ownership, or interaction with other mods. In-game verification has not
been performed. Multiplayer support remains unverified; this pass does not add
network synchronization.

See [community triage](docs/community-issues.md) for reports and follow-up work.
Only the mod files belong in a Workshop upload; exclude `tests`, `docs`, and `.tools`.
