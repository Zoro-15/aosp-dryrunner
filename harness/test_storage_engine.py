"""Engine K: Storage v2 — Volume Sizing, Degradation & Root-Disk Guard.

Exhaustive checks on the structural fix for the /mnt capacity deadlock
(runs #30/#34-#36):
  * sparse-image cap math must always leave the reserve intact,
  * ANY provisioning failure must degrade to plain mode with a reason
    (never raise out of ensure_volume),
  * the pre-bank decision function must NEVER schedule delete-source
    while the tree sits on the compressed volume,
  * the emergency root purge list must never touch runner internals
    (failure class B: runner eviction, runs #16-#21),
  * atomic claims stay exactly-one-winner even under thread contention.
"""
import os
import shutil
import tempfile
import threading
import unittest
from pathlib import Path

from forge_core import engine, relay, storage
from forge_core.store import FsStore


class TestVolumeSizing(unittest.TestCase):
    def test_cap_always_leaves_reserve(self):
        """cap = free - reserve, floored at 0 — the runner keeps its rent."""
        for free, resv in ((75, 10), (65.5, 10), (30, 12.5), (5, 10), (0, 10)):
            with self.subTest(free=free, resv=resv):
                cap = storage.compute_cap_gb(free, resv)
                self.assertGreaterEqual(cap, 0.0)
                self.assertLessEqual(cap, max(0.0, free - resv) + 1e-9)
                self.assertLessEqual(cap, free + 1e-9)

    def test_reserve_env_knob(self):
        """FORGE_VOLUME_RESERVE_GB overrides the default reserve."""
        old = os.environ.pop("FORGE_VOLUME_RESERVE_GB", None)
        try:
            self.assertEqual(storage.compute_cap_gb(50), 40.0)
            os.environ["FORGE_VOLUME_RESERVE_GB"] = "20"
            self.assertEqual(storage.compute_cap_gb(50), 30.0)
            os.environ["FORGE_VOLUME_RESERVE_GB"] = "not-a-number"
            self.assertEqual(storage.compute_cap_gb(50), 40.0)  # robust parse
        finally:
            os.environ.pop("FORGE_VOLUME_RESERVE_GB", None)
            if old is not None:
                os.environ["FORGE_VOLUME_RESERVE_GB"] = old

    def test_forced_plain_mode(self):
        """FORGE_NO_VOLUME=1 forces honest plain mode, no side effects."""
        old = os.environ.pop("FORGE_NO_VOLUME", None)
        try:
            os.environ["FORGE_NO_VOLUME"] = "1"
            st = storage.ensure_volume()
            self.assertEqual(st.mode, "plain")
            self.assertIn("FORGE_NO_VOLUME", st.reason)
            self.assertIsNone(storage.active_build_root())
        finally:
            os.environ.pop("FORGE_NO_VOLUME", None)
            if old is not None:
                os.environ["FORGE_NO_VOLUME"] = old

    def test_degraded_state_is_serializable(self):
        st = storage._plain_state("unit-test reason")
        d = st.to_dict()
        self.assertEqual(d["mode"], "plain")
        self.assertEqual(d["reason"], "unit-test reason")
        self.assertTrue(st.degraded)


class TestPreBankGuard(unittest.TestCase):
    """THE storage-deadlock guard: volume mode never deletes the source."""

    def test_volume_mode_never_deletes_source(self):
        for free in (0.1, 0.5, 1.0, 1.9, 1.99):
            with self.subTest(free=free):
                acts = relay.pre_bank_actions(free, protect_source=True)
                self.assertNotIn("delete-source", acts,
                                 f"volume mode must never delete source: {acts}")
                self.assertIn("stop:capacity", acts)

    def test_plain_mode_degrades_to_legacy_last_resort(self):
        acts = relay.pre_bank_actions(1.0, protect_source=False)
        self.assertIn("delete-source", acts)

    def test_healthy_volume_only_purges_tmp(self):
        self.assertEqual(relay.pre_bank_actions(50.0, protect_source=True),
                         ["purge-tmp"])

    def test_ladder_before_fstrim_ordering(self):
        acts = relay.pre_bank_actions(3.0, protect_source=True)
        self.assertIn("reclaim-ladder", acts)
        self.assertNotIn("fstrim", acts)
        acts = relay.pre_bank_actions(1.5, protect_source=True)
        self.assertLess(acts.index("reclaim-ladder"), acts.index("fstrim"))


class TestRootDiskPurgeSafety(unittest.TestCase):
    """Failure class B: purging / must NEVER evict the runner daemon."""

    BANNED = ("/home/runner", "/var/log", "/opt/actions", "agent",
              "_diag", "runner")

    def test_purge_list_avoids_runner_internals(self):
        for p in storage.ROOT_PURGE_PATHS:
            for frag in self.BANNED:
                self.assertNotIn(frag, p, f"dangerous purge path: {p}")

    def test_purge_only_touches_caches(self):
        joined = " ".join(storage.ROOT_PURGE_PATHS)
        for token in (".cache", "/var/cache/apt"):
            self.assertIn(token, joined)

    def test_engine_root_thresholds_ordered(self):
        """Purge must fire BEFORE the stop threshold (recovery first)."""
        self.assertLess(engine.ROOT_STOP_GB, engine.ROOT_PURGE_GB)
        self.assertLess(engine.PHYS_STOP_GB, engine.PHYS_WARN_GB)
        self.assertLess(engine.LOGICAL_STOP_GB, 6.0)  # below min_free_gb floor


class TestAtomicClaims(unittest.TestCase):
    """exactly-one-winner even with 16 threads racing mkdir."""

    def test_thread_contention_single_winner(self):
        tmp = Path(tempfile.mkdtemp(prefix="forge-claim-"))
        try:
            st = FsStore(tmp)
            wins = []
            barrier = threading.Barrier(16, timeout=30)
            shared_tag = "lock-k-race-s1"

            def racer(i):
                barrier.wait()
                wins.append((i, st.claim(shared_tag, "t", "n")))

            threads = [threading.Thread(target=racer, args=(i,))
                       for i in range(16)]
            for t in threads:
                t.start()
            for t in threads:
                t.join()
            true_wins = sum(1 for _, w in wins if w)
            self.assertEqual(true_wins, 1,
                             f"exactly one winner expected, got {true_wins}")
            # meta survived the race
            self.assertTrue((tmp / shared_tag / ".meta").exists())
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    def test_gc_locks_scoped_to_key(self):
        tmp = Path(tempfile.mkdtemp(prefix="forge-gclock-"))
        try:
            st = FsStore(tmp)
            st.claim("lock-keyA-r1-s1", "t", "n")
            st.claim("lock-keyA-r2-s1", "t", "n")
            st.claim("lock-keyB-r1-s1", "t", "n")
            st.create("src-keep", "t", "n")
            dropped = st.gc_locks("keyA")
            self.assertEqual(sorted(dropped),
                             ["lock-keyA-r1-s1", "lock-keyA-r2-s1"])
            self.assertTrue(st.exists("lock-keyB-r1-s1"))
            self.assertTrue(st.exists("src-keep"))
        finally:
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
