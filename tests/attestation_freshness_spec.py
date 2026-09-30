"""Read-only, targeted freshness report tests for catalog evidence."""

from __future__ import annotations

import copy
import hashlib
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from report_attestation_freshness import build_freshness_report  # noqa: E402
from validate_runtime_attestations import load_json, validate_catalog  # noqa: E402

SCHEMA = load_json(ROOT / "data/canonical/catalog/runtime_attestations.schema.json")
SOURCE_CATALOG_PATH = ROOT / "data/canonical/catalog/runtime_attestations.json"


class AttestationFreshnessSpec(unittest.TestCase):
    def setUp(self) -> None:
        self.catalog = load_json(SOURCE_CATALOG_PATH)
        self.original_bytes = SOURCE_CATALOG_PATH.read_bytes()
        self.temp = tempfile.TemporaryDirectory()
        self.game_root = Path(self.temp.name)
        self.file_by_evidence: dict[str, Path] = {}
        for evidence in self.catalog["evidence"]:
            if evidence["evidenceKind"] != "Hades2NativeFile":
                continue
            target = self.game_root / evidence["filePath"]
            target.parent.mkdir(parents=True, exist_ok=True)
            content = f"fixture:{evidence['evidenceId']}".encode()
            target.write_bytes(content)
            evidence["sha256"] = hashlib.sha256(content).hexdigest().upper()
            self.file_by_evidence[evidence["evidenceId"]] = target
        validate_catalog(self.catalog, SCHEMA)

    def tearDown(self) -> None:
        self.temp.cleanup()
        self.assertEqual(SOURCE_CATALOG_PATH.read_bytes(), self.original_bytes)

    def report(self, observed_game_build: str | None = "test-build") -> dict:
        return build_freshness_report(self.catalog, self.game_root, observed_game_build)

    def claim(self, report: dict, claim_id: str) -> dict:
        return next(row for row in report["claims"] if row["claimId"] == claim_id)

    def evidence(self, report: dict, evidence_id: str) -> dict:
        return next(row for row in report["evidence"] if row["evidenceId"] == evidence_id)

    def test_identical_hashes_are_fresh_and_report_is_deterministic(self) -> None:
        first = self.report()
        second = self.report()
        self.assertEqual(first, second)
        self.assertEqual(first["summary"]["evidenceModified"], 0)
        self.assertEqual(first["summary"]["claimsNeedRevalidation"], 0)
        self.assertEqual(first["summary"]["claimsFreshnessUnknown"], 0)
        self.assertTrue(all(row["freshness"] == "fresh" for row in first["claims"]))
        self.assertEqual(first["observedGameBuild"], "test-build")

    def test_changed_file_only_marks_dependent_claims_for_review(self) -> None:
        evidence_id = "native-file-traitdata_apollo"
        self.file_by_evidence[evidence_id].write_text("changed content", encoding="utf-8")
        result = self.report()
        self.assertEqual(self.evidence(result, evidence_id)["status"], "modified")
        affected = [row for row in result["claims"] if row["freshness"] == "needs_revalidation"]
        self.assertEqual({row["claimId"] for row in affected}, {
            "native-item-ApolloWeaponBoon-type",
            "native-item-DoubleStrikeChanceBoon-type",
        })
        self.assertEqual(self.claim(result, "native-item-HeraWeaponBoon-type")["freshness"], "fresh")
        self.assertEqual(result["summary"]["claimsNeedRevalidation"], 2)

    def test_missing_file_is_explicit_and_does_not_invalidate_claim(self) -> None:
        evidence_id = "native-file-npcdata_artemis"
        self.file_by_evidence[evidence_id].unlink()
        result = self.report()
        item = self.evidence(result, evidence_id)
        self.assertEqual(item["status"], "missing")
        self.assertEqual(item["revalidation"], "freshness_unknown")
        self.assertEqual(self.claim(result, "source-NPC_Artemis_Field_01-type")["freshness"], "unknown")
        self.assertEqual(self.claim(result, "pair-NPC_Artemis_Field_01-InsideCastCritBoon")["freshness"], "unknown")
        claim = next(row for row in self.catalog["offerSources"] if row["offerSource"] == "NPC_Artemis_Field_01")["claims"][0]
        self.assertEqual(claim["status"], "validated")

    def test_multiple_claims_sharing_evidence_resolve_to_each_native_item(self) -> None:
        evidence_id = "native-file-traitdata_apollo"
        self.file_by_evidence[evidence_id].write_text("changed content", encoding="utf-8")
        result = self.report()
        dependencies = self.evidence(result, evidence_id)["claimDependencies"]
        self.assertEqual(len(dependencies), 2)
        self.assertEqual(
            {link["target"]["runtimeItemId"] for link in dependencies},
            {"ApolloWeaponBoon", "DoubleStrikeChanceBoon"},
        )

    def test_unrelated_evidence_does_not_affect_other_claims(self) -> None:
        self.file_by_evidence["native-file-lootdata_chaos"].write_text("changed", encoding="utf-8")
        result = self.report()
        self.assertEqual(self.claim(result, "pair-TrialUpgrade-ChaosHealthBlessing")["freshness"], "needs_revalidation")
        self.assertEqual(self.claim(result, "native-item-ApolloWeaponBoon-type")["freshness"], "fresh")
        self.assertEqual(self.claim(result, "source-TrialUpgrade-type")["freshness"], "needs_revalidation")

    def test_path_outside_game_root_is_indeterminate(self) -> None:
        evidence = next(row for row in self.catalog["evidence"] if row["evidenceId"] == "native-file-traitdata_apollo")
        evidence["filePath"] = "../outside.lua"
        validate_catalog(self.catalog, SCHEMA)
        result = self.report()
        self.assertEqual(self.evidence(result, evidence["evidenceId"])["status"], "indeterminate")
        self.assertEqual(self.claim(result, "native-item-ApolloWeaponBoon-type")["freshness"], "unknown")

    def test_directory_at_evidence_path_is_reported_as_read_error(self) -> None:
        evidence_id = "native-file-traitdata_apollo"
        self.file_by_evidence[evidence_id].unlink()
        self.file_by_evidence[evidence_id].mkdir()
        result = self.report()
        self.assertEqual(self.evidence(result, evidence_id)["status"], "error")
        self.assertEqual(self.claim(result, "native-item-ApolloWeaponBoon-type")["freshness"], "unknown")

    def test_report_does_not_change_claims_ids_or_pairs(self) -> None:
        before = copy.deepcopy(self.catalog)
        result = self.report()
        self.assertFalse(result["automaticCatalogChanges"])
        self.assertEqual(self.catalog, before)
        self.assertEqual(SOURCE_CATALOG_PATH.read_bytes(), self.original_bytes)


if __name__ == "__main__":
    unittest.main(verbosity=2)
