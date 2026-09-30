"""Regression tests for the shared runtime attestation catalog."""

from __future__ import annotations

import copy
from pathlib import Path
import sys
import unittest

from jsonschema.exceptions import SchemaError

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from validate_runtime_attestations import (  # noqa: E402
    CatalogValidationError,
    TRIAL_UPGRADE_ALLOWED_PAIRS,
    load_json,
    validate_catalog,
)

SCHEMA_PATH = ROOT / "data/canonical/catalog/runtime_attestations.schema.json"
CATALOG_PATH = ROOT / "data/canonical/catalog/runtime_attestations.json"


class RuntimeAttestationCatalogSpec(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.schema = load_json(SCHEMA_PATH)
        cls.catalog = load_json(CATALOG_PATH)

    def mutated(self) -> dict:
        return copy.deepcopy(self.catalog)

    def assert_invalid(self, catalog: dict, match: str) -> None:
        with self.assertRaisesRegex(CatalogValidationError, match):
            validate_catalog(catalog, self.schema)

    def test_schema_is_valid_and_migrated_catalog_passes_formal_validation(self) -> None:
        validate_catalog(self.catalog, self.schema)

    def test_invalid_schema_definition_fails_closed(self) -> None:
        schema = copy.deepcopy(self.schema)
        schema["type"] = "not-a-json-schema-type"
        with self.assertRaises(SchemaError):
            validate_catalog(self.catalog, schema)

    def test_claim_and_record_ids_must_be_unique(self) -> None:
        value = self.mutated()
        value["nativeItems"][1]["runtimeItemId"] = value["nativeItems"][0]["runtimeItemId"]
        self.assert_invalid(value, "duplicate runtimeItemId")

        value = self.mutated()
        value["nativeItems"][1]["claims"][0]["claimId"] = value["nativeItems"][0]["claims"][0]["claimId"]
        self.assert_invalid(value, "duplicate claimId")

        value = self.mutated()
        value["sourceBoonPairs"].append(copy.deepcopy(value["sourceBoonPairs"][0]))
        self.assert_invalid(value, "duplicate pairId")

        value = self.mutated()
        value["evidence"].append(copy.deepcopy(value["evidence"][0]))
        self.assert_invalid(value, "duplicate evidenceId")

    def test_evidence_references_must_resolve_in_both_directions(self) -> None:
        value = self.mutated()
        value["evidence"][0]["attests"].append("missing-claim")
        self.assert_invalid(value, "attests unknown claimId")

        value = self.mutated()
        value["nativeItems"][0]["claims"][0]["evidenceIds"] = ["missing-evidence"]
        self.assert_invalid(value, "bidirectional")

    def test_evidence_kind_must_match_claim_kind(self) -> None:
        value = self.mutated()
        native_claim_id = value["nativeItems"][0]["claims"][0]["claimId"]
        evidence = next(record for record in value["evidence"] if native_claim_id in record["attests"])
        evidence["evidenceKind"] = "MobalyticsCDN"
        self.assert_invalid(value, "incompatible evidence kind")

    def test_status_enum_is_enforced_by_json_schema(self) -> None:
        for status in ("validated", "needs_revalidation", "invalid", "deprecated"):
            with self.subTest(status=status):
                value = self.mutated()
                value["nativeItems"][0]["claims"][0]["status"] = status
                validate_catalog(value, self.schema)

        value = self.mutated()
        value["nativeItems"][0]["claims"][0]["status"] = "approved-ish"
        self.assert_invalid(value, "is not one of")

    def test_identifier_pattern_and_date_format_are_enforced(self) -> None:
        value = self.mutated()
        value["nativeItems"][0]["runtimeItemId"] = "id with spaces"
        self.assert_invalid(value, "does not match")

        value = self.mutated()
        value["evidence"][0]["reviewedAt"] = "30/09/2026"
        self.assert_invalid(value, "is not a 'date'")

    def test_ids_are_exact_case_sensitive_references(self) -> None:
        value = self.mutated()
        value["sourceBoonPairs"][0]["runtimeItemId"] = "insidecastcritboon"
        self.assert_invalid(value, "unknown or incorrectly cased runtimeItemId")

    def test_unknown_source_is_rejected(self) -> None:
        value = self.mutated()
        value["sourceBoonPairs"][0]["offerSource"] = "NPC_Unknown_01"
        self.assert_invalid(value, "unknown or incorrectly cased offerSource")

    def test_trial_upgrade_is_a_closed_exact_allowlist(self) -> None:
        current = {
            (pair["offerSource"], pair["runtimeItemId"])
            for pair in self.catalog["sourceBoonPairs"]
            if pair["offerSource"] == "TrialUpgrade"
        }
        self.assertEqual(current, TRIAL_UPGRADE_ALLOWED_PAIRS)

        value = self.mutated()
        extra = copy.deepcopy(next(pair for pair in value["sourceBoonPairs"] if pair["offerSource"] == "TrialUpgrade"))
        extra["pairId"] = "pair-TrialUpgrade-ChaosSpecialBlessing"
        extra["claimId"] = extra["pairId"]
        extra["runtimeItemId"] = "ChaosSpecialBlessing"
        value["sourceBoonPairs"].append(extra)
        self.assert_invalid(value, "TrialUpgrade pair allowlist mismatch")

    def test_unattested_source_boon_pair_is_rejected(self) -> None:
        value = self.mutated()
        pair = value["sourceBoonPairs"][0]
        pair["runtimeItemId"] = "ApolloWeaponBoon"
        pair["pairId"] = "pair-NPC_Artemis_Field_01-ApolloWeaponBoon"
        pair["claimId"] = pair["pairId"]
        self.assert_invalid(value, "bidirectional")

    def test_build_specific_fields_are_forbidden(self) -> None:
        for field in ("corePlan", "godPool", "priority", "scoring", "recommendationRole"):
            with self.subTest(field=field):
                value = self.mutated()
                value[field] = {}
                self.assert_invalid(value, "Additional properties are not allowed")

    def test_external_name_mapping_requires_typed_independent_evidence(self) -> None:
        # The migrated catalog deliberately has no external mappings yet.
        self.assertEqual(self.catalog["externalNameMappings"], [])

        value = self.mutated()
        value["externalNameMappings"].append(
            {
                "mappingId": "mobalytics-unproven-name",
                "provider": "Mobalytics",
                "externalName": "Unproven Name",
                "runtimeItemId": "ApolloWeaponBoon",
                "claimId": "external-name-unproven",
                "status": "validated",
                "evidenceIds": ["native-file-traitdata_apollo"],
            }
        )
        self.assert_invalid(value, "incompatible evidence kind")

        value = self.mutated()
        value["externalNameMappings"].append(
            {
                "mappingId": "mobalytics-name-without-proof",
                "provider": "Mobalytics",
                "externalName": "Unproven Name",
                "runtimeItemId": "ApolloWeaponBoon",
                "claimId": "external-name-without-proof",
                "status": "validated",
                "evidenceIds": [],
            }
        )
        self.assert_invalid(value, "should be non-empty")


if __name__ == "__main__":
    unittest.main(verbosity=2)
