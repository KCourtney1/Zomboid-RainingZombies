# Community reports and follow-up work

Reviewed both pages of the 73 [Workshop comments](https://steamcommunity.com/sharedfiles/filedetails/comments/3763651059)
on October 23, 2026. Reports are evidence of symptoms, not confirmed diagnoses.

| Priority | Report | Evidence | Current status |
| --- | --- | --- | --- |
| 1 | Stair travel can trigger damage and knockdown | [Marzhall, July 26](https://steamcommunity.com/sharedfiles/filedetails/?id=3763651059#c583929583674430500); [jeff_till, August 5](https://steamcommunity.com/sharedfiles/filedetails/?id=3763651059#c592937761422535348) | Added stair guards and a minimum one-floor impact distance. Engine-double regressions pass. On October 25, the author reported no knockdowns during stair fights in either direction; stair landings and custom-map stairs still need targeted checks. |
| 1 | Severe stuttering around Louisville, especially with other heavy mods | [Cyrisa, August 6](https://steamcommunity.com/sharedfiles/filedetails/?id=3763651059#c592937761422594167); [Ulas, August 6](https://steamcommunity.com/sharedfiles/filedetails/?id=3763651059#c592937761422599109) | Reduced redundant scans, collection fetches, and closure allocations. On October 25, the author reported that stuttering was gone during a high-density Louisville test. This is a qualitative observation, not a frame-time benchmark or a guarantee across mod lists. |
| 1 | Possible wall crossings before a fall | Author playtest, October 25, 2026 | Observation is uncertain because roof falls can look similar. Code inspection and two engine-double scenarios confirm missing boundary/orientation checks; gameplay fix pending. See [playtest notes](playtest-2026-10-25.md). |
| 1 | Attacker disappears beside an upper-floor opening and returns upstairs | Author follow-up, October 25, 2026 | Added an attack-state guard after reproducing repeated forced pushes during attacks in engine doubles. Automated tests pass; the author confirmed the disappearance was fixed in the follow-up in-game test. Boundary validation remains a separate open issue. |
| 2 | Multiplayer behavior and desynchronization concerns | [Karmatic, August 10](https://steamcommunity.com/sharedfiles/filedetails/?id=3763651059#c592938033420142893); [Duke of Montebello, July 14](https://steamcommunity.com/sharedfiles/filedetails/?id=3763651059#c573795381137248983) | Requires ownership, server/client event, and replication investigation. Multiplayer support was not added. |
| 3 | Falling animation looks like floating | [Dank, August 21](https://steamcommunity.com/sharedfiles/filedetails/?id=3763651059#c588435430711745469) | Requires an animation/physics investigation; current shove and fall-on-front behavior preserved. |

Additional requests include Build 41 support and behavior based on zombie
intelligence/toughness. A vague spawning concern lacks reproduction details.
Artwork feedback is outside this code pass.

## Stair investigation

The original code accepted any missing floor ahead as a ledge and used
`math.max(1, startFallZ - currentZ)` for impact damage. Those rules can turn normal
stair movement into a fall impact. This is an inference from the source and the
reports, not a captured game reproduction.

The new guards use `IsoGridSquare:HasStairs()`, confirmed in the installed game's
Lua sources and the [official IsoGridSquare API](https://projectzomboid.com/modding/zombie/iso/IsoGridSquare.html#HasStairs()).
They conservatively skip forced vaults when either checked square has stairs.
Actual falls onto stairs remain eligible for effects when the drop is at least
one full floor. Test stair transitions and custom-map stairs before release.

## Next implementation decisions after profiling

- Measure time spent in candidate scans, active-fall updates, and landing effects
  separately on the same Louisville route.
- If candidate work dominates, design a fair per-tick budget without starving
  zombies as population or callback ordering changes. The existing throttle is
  a sampling ratio, not a fixed budget or guaranteed delay for each zombie.
- If simultaneous impacts dominate, investigate a bounded effects queue while
  keeping gameplay damage timing explicit.
- Verify edge orientation before expanding vault behavior: the preserved logic
  searches the current and forward tiles, but does not check which edge contains
  the window/fence.
- Investigate the preserved landing heuristic: a stable mid-air height can look
  like a landing. Also test delayed healing after a lethal fall and after other
  damage, since it currently restores the pre-fall health baseline.

The author confirmed player impact damage and knockdowns of players and other
zombies in the October 25 playtest. Individual sandbox toggle behavior and
multiplayer replication still need in-game verification.
