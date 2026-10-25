"""Run with Python + lupa (Lua 5.1); no running game or third-party test framework needed."""
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".tools" / "python"))
try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    raise SystemExit("Install the test runtime: python -m pip install --target .tools/python lupa==2.8")

MOD_ROOT = ROOT / "Contents/mods/RainingZombies"
SERVER = MOD_ROOT / "42/media/lua/server"
ORIGINAL = ROOT / "tests/fixtures/RainingZombies_Logic.original.lua"


def runtime(original=False, setup=""):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute((ROOT / "tests/support.lua").read_text(encoding="utf-8"))
    loaded = set()

    def require(name):
        if name not in loaded:
            loaded.add(name)
            lua.execute((SERVER / (name + ".lua")).read_text(encoding="utf-8-sig"))
        # The game module convention must not depend on Lua package return values.

    lua.globals().require = require
    lua.execute(setup)
    source = ORIGINAL if original else SERVER / "RainingZombies_Logic.lua"
    lua.execute(source.read_text(encoding="utf-8-sig"))
    return lua


class RefactorTests(unittest.TestCase):
    def compare(self, scenario, setup=""):
        old, new = runtime(True, setup), runtime(False, setup)
        for lua in (old, new):
            lua.execute(scenario)
        self.assertEqual(old.eval("trace()"), new.eval("trace()"))
        return old, new

    def test_normal_falls_match_original_for_each_sandbox_option(self):
        settings = ["", "SandboxVars.RainingZombies = nil"]
        for name in ("PlayerKnockdown", "PlayerFractures", "CrawlerConversion",
                     "ZombieChainReaction", "AudioVisualPolish"):
            settings.append(f"SandboxVars.RainingZombies.{name} = false")
        for name, values in {"FallDamageReduction": (0, 25, 50, 100),
                             "PlayerDamagePerFloor": (0, 5, 100),
                             "HordeThrottle": (0, 1, 15, 60)}.items():
            settings.extend(f"SandboxVars.RainingZombies.{name} = {v}" for v in values)
        for setting in settings:
            with self.subTest(setting=setting):
                self.compare("for i = 1, 60 do Events.OnZombieUpdate.fire(zombie) end; land()", setting)

    def test_windows_fences_ledges_and_floor_match_original(self):
        cases = [
            "ahead = nil",
            "ahead = square({}, true)",
            "origin.objects = {window(true)}",
            "ahead.objects = {window(true)}",
            "origin.objects = {window(false, true)}",
            "origin.objects = {window(false)}",
            "origin.objects = {window(false)}; SandboxVars.RainingZombies.InstantGlassShatter = true",
            "origin.objects = {window(false, false, true)}; ahead = square({}, true)",
            "origin.objects = {fence('is')}; ahead = square({}, true)",
            "ahead = square({fence('Is')}, true)",
            "origin.objects = {window(false), fence()}",
            "origin.objects = {window(false)}; ahead.objects = {window(true)}",
        ]
        for setup in cases:
            with self.subTest(setup=setup):
                self.compare("Events.OnZombieUpdate.fire(zombie); land()", setup)

    def test_fall_heights_match_original(self):
        for start, end in ((1, 0), (2, 0), (3, 1), (6, 0), (3, 1.5)):
            with self.subTest(start=start, end=end):
                self.compare(f"Events.OnZombieUpdate.fire(zombie); land({end})", f"zombie.z = {start}")

    def test_ground_and_climbing_zombies_are_skipped(self):
        for setup in ("zombie.z = 0", "zombie.climbing = true"):
            old, new = self.compare("Events.OnZombieUpdate.fire(zombie)", setup)
            self.assertEqual(new.eval("trace()"), "")
            self.assertEqual(new.eval("scans"), 0)

    def test_attacking_zombie_is_not_shoved_off_a_ledge_or_window(self):
        # Keep attacking longer than the fall tracker timeout. The old code
        # repeatedly pushes, even though the zombie has never left its attack.
        for setup in ("", "origin.objects = {window(true)}"):
            with self.subTest(setup=setup):
                old, new = runtime(True, setup), runtime(False, setup)
                for lua in (old, new):
                    lua.execute("""
                        zombie.attacking = true
                        for i = 1, 650 do
                            Events.OnZombieUpdate.fire(zombie)
                            ticks(1)
                        end
                    """)
                self.assertGreater(old.eval("zombie.x"), 10.2)
                self.assertEqual(new.eval("zombie.x"), 10.2)
                self.assertIsNone(new.eval("zombie.fallOnFront"))
                self.assertEqual(new.eval("scans"), 0)

    def test_attacking_zombie_does_not_shatter_glass(self):
        lua = runtime(setup="""
            origin.objects = {window(false)}
            SandboxVars.RainingZombies.InstantGlassShatter = true
            zombie.attacking = true
        """)
        lua.execute("Events.OnZombieUpdate.fire(zombie)")
        self.assertFalse(lua.eval("origin.objects[1]:isSmashed() or false"))
        self.assertEqual(lua.eval("trace()"), "")
        self.assertEqual(lua.eval("scans"), 0)

    def test_vaulting_resumes_when_attack_ends(self):
        lua = runtime(setup="zombie.attacking = true")
        lua.execute("Events.OnZombieUpdate.fire(zombie); ticks(1)")
        self.assertEqual(lua.eval("zombie.x"), 10.2)
        lua.execute("zombie.attacking = false; Events.OnZombieUpdate.fire(zombie)")
        self.assertAlmostEqual(lua.eval("zombie.x"), 10.8)
        self.assertTrue(lua.eval("zombie.fallOnFront"))
        lua.execute("land()")
        self.assertEqual(lua.eval("player.health"), 40)
        self.assertEqual(lua.eval("zombie.health"), 1)

    def test_attack_state_does_not_abandon_an_existing_fall(self):
        self.compare("""
            Events.OnZombieUpdate.fire(zombie)
            zombie.attacking = true
            land()
        """)

    def test_missing_current_square_does_not_start_a_fall(self):
        lua = runtime(setup="zombie.square = nil")
        lua.execute("Events.OnZombieUpdate.fire(zombie)")
        self.assertEqual(lua.eval("trace()"), "")

    def test_stairs_do_not_trigger_vault_or_impact(self):
        for setup in ("origin.stairs = true", "ahead.stairs = true"):
            old, new = runtime(True, setup), runtime(False, setup)
            for lua in (old, new):
                lua.execute("Events.OnZombieUpdate.fire(zombie); land()")
            self.assertLess(old.eval("player.health"), 100)  # reproduces the old logic error
            self.assertEqual(new.eval("player.health"), 100)
            self.assertEqual(new.eval("zombie.x"), 10.2)
            self.assertEqual(new.eval("scans"), 0)

    def test_small_drop_does_not_cause_one_floor_damage(self):
        old, new = runtime(True), runtime()
        for lua in (old, new):
            lua.execute("Events.OnZombieUpdate.fire(zombie); land(2.75)")
        self.assertEqual(old.eval("player.health"), 80)
        self.assertEqual(new.eval("player.health"), 100)
        self.assertNotIn(".sound", new.eval("trace()"))

    def test_small_drop_can_continue_into_a_real_fall(self):
        lua = runtime()
        lua.execute("Events.OnZombieUpdate.fire(zombie); land(2.75, 6); land(0)")
        self.assertEqual(lua.eval("player.health"), 40)

    def test_landing_is_once_and_healing_waits_31_ticks(self):
        old, new = self.compare("Events.OnZombieUpdate.fire(zombie); land(0, 5)")
        self.assertEqual(new.eval("player.health"), 40)
        self.assertEqual(new.eval("zombie.health"), 0.25)
        for lua in (old, new):
            lua.execute("ticks(30)")
            self.assertEqual(lua.eval("zombie.health"), 0.25)
            lua.execute("ticks(1)")
            self.assertEqual(lua.eval("zombie.health"), 1)
            lua.execute("ticks(50)")
            self.assertEqual(lua.eval("player.health"), 40)
        self.assertEqual(old.eval("trace()"), new.eval("trace()"))

    def test_timeout_and_removed_zombie_release_tracking(self):
        for scenario in (
            "Events.OnZombieUpdate.fire(zombie); ticks(301); Events.OnZombieUpdate.fire(zombie)",
            "Events.OnZombieUpdate.fire(zombie); zombie.invalid = true; ticks(1); zombie.invalid = false; Events.OnZombieUpdate.fire(zombie)",
        ):
            with self.subTest(scenario=scenario):
                _, new = self.compare(scenario)
                self.assertAlmostEqual(new.eval("zombie.x"), 11.4)

    def test_landing_without_square_still_heals(self):
        self.compare("Events.OnZombieUpdate.fire(zombie); zombie.z = 0; zombie.square = nil; zombie.health = 0.25; ticks(40)")

    def test_settings_changes_take_effect_in_game(self):
        _, new = self.compare("""
            Events.OnZombieUpdate.fire(zombie)
            SandboxVars.RainingZombies.PlayerKnockdown = false
            SandboxVars.RainingZombies.PlayerDamagePerFloor = 0
            land(0, 5)
            SandboxVars.RainingZombies.FallDamageReduction = 50
            ticks(31)
        """)
        self.assertEqual(new.eval("player.health"), 100)
        self.assertIsNone(new.eval("player.knockedDown"))
        self.assertEqual(new.eval("zombie.health"), 0.625)

    def test_shared_square_cache_and_fence_short_circuit(self):
        scenario = """
            for i = 1, 200 do
                local z = character('z' .. i, 'IsoZombie', 3, 1)
                z.square = origin
                Events.OnZombieUpdate.fire(z)
            end
        """
        old, new = self.compare(scenario, "origin.objects = {window(true)}")
        self.assertEqual(old.eval("scans"), 3)
        self.assertEqual(new.eval("scans"), 1)
        print(f"\nShared-window horde (200 zombies): object-list scans {old.eval('scans')} -> {new.eval('scans')}")

    def test_negative_cache_expires_next_tick(self):
        lua = runtime(setup="ahead = square({}, true)")
        lua.execute("""
            Events.OnZombieUpdate.fire(zombie)
            Events.OnZombieUpdate.fire(zombie)
        """)
        self.assertEqual(lua.eval("scans"), 4)
        lua.execute("origin.objects = {window(true)}; ticks(1); Events.OnZombieUpdate.fire(zombie)")
        self.assertAlmostEqual(lua.eval("zombie.x"), 10.8)

    def test_collision_list_is_fetched_once(self):
        old, new = self.compare("Events.OnZombieUpdate.fire(zombie); land()")
        self.assertEqual(old.eval("movingLookups"), 4)
        self.assertEqual(new.eval("movingLookups"), 1)

    def test_tick_rollover_does_not_leak_active_falls(self):
        # Drive the public event across the real counter boundary, no internal mutation.
        old, new = runtime(True), runtime()
        for lua in (old, new):
            lua.execute("ticks(999999); Events.OnZombieUpdate.fire(zombie); ticks(301); Events.OnZombieUpdate.fire(zombie)")
        self.assertAlmostEqual(old.eval("zombie.x"), 10.8)
        self.assertAlmostEqual(new.eval("zombie.x"), 11.4)

    def test_healing_across_tick_rollover(self):
        lua = runtime()
        lua.execute("ticks(999999); Events.OnZombieUpdate.fire(zombie); land()")
        self.assertEqual(lua.eval("zombie.health"), 1)

    def test_defaults_match_sandbox_schema(self):
        lua = runtime(setup="SandboxVars = {}")
        schema = (MOD_ROOT / "42/media/sandbox-options.txt").read_text()
        options = re.findall(r"option RainingZombies\.(\w+)\s*\{[^}]*?default\s*=\s*(\w+)", schema)
        self.assertEqual(len(options), 9)
        for name, value in options:
            expected = {"true": True, "false": False}.get(value)
            if expected is None:
                expected = int(value)
            self.assertEqual(lua.globals().RainingZombies.Config.get(name), expected)

    def test_single_registration_and_modules_do_not_add_handlers(self):
        lua = runtime()
        for path in sorted((SERVER / "RainingZombies").glob("*.lua")):
            lua.globals().require("RainingZombies/" + path.stem)
        self.assertEqual(lua.eval("Events.OnTick.count()"), 1)
        self.assertEqual(lua.eval("Events.OnZombieUpdate.count()"), 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
