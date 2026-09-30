"""Validate the attestation catalog against its JSON Schema and semantic contract."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
from typing import Any

try:
    from jsonschema import Draft202012Validator, FormatChecker
except ImportError as exc:  # fail explicitly; never fall back to weaker checks
    raise SystemExit(
        "Missing development dependency 'jsonschema'. Create the project venv and "
        "install requirements-dev.txt; see docs/ATTESTATION_CATALOG_VALIDATION.md."
    ) from exc


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SCHEMA = REPOSITORY_ROOT / "data/canonical/catalog/runtime_attestations.schema.json"
DEFAULT_CATALOG = REPOSITORY_ROOT / "data/canonical/catalog/runtime_attestations.json"

# A new TrialUpgrade pair requires an explicit reviewed change to this allowlist
# and its regression tests. The source's broader native trait list is not blanket
# authorization to project every Chaos trait through the Curator/import pipeline.
TRIAL_UPGRADE_ALLOWED_PAIRS = {
    ("TrialUpgrade", "ChaosWeaponBlessing"),
    ("TrialUpgrade", "ChaosHealthBlessing"),
}


class CatalogValidationError(ValueError):
    """Raised when the schema or attestation semantics are invalid."""


def _sort_errors(errors: list[Any]) -> list[Any]:
    return sorted(errors, key=lambda error: (list(map(str, error.absolute_path)), error.message))


def _schema_errors(instance: Any, schema: dict[str, Any]) -> list[str]:
    Draft202012Validator.check_schema(schema)
    validator = Draft202012Validator(schema, format_checker=FormatChecker())
    return [
        f"{list(error.absolute_path) or ['$']}: {error.message}"
        for error in _sort_errors(list(validator.iter_errors(instance)))
    ]


def _unique(values: list[str], label: str, errors: list[str]) -> None:
    seen: set[str] = set()
    for value in values:
        if value in seen:
            errors.append(f"duplicate {label}: {value}")
        seen.add(value)


def validate_catalog(catalog: dict[str, Any], schema: dict[str, Any]) -> None:
    """Validate schema shape, exact references, provenance, and closed pair rules."""
    errors = _schema_errors(catalog, schema)
    if errors:
        raise CatalogValidationError("JSON Schema validation failed:\n- " + "\n- ".join(errors))

    items = catalog["nativeItems"]
    sources = catalog["offerSources"]
    pairs = catalog["sourceBoonPairs"]
    mappings = catalog["externalNameMappings"]
    evidence_records = catalog["evidence"]

    _unique([entry["runtimeItemId"] for entry in items], "runtimeItemId", errors)
    _unique([entry["offerSource"] for entry in sources], "offerSource", errors)
    _unique([entry["pairId"] for entry in pairs], "pairId", errors)
    _unique([entry["mappingId"] for entry in mappings], "mappingId", errors)
    _unique([entry["evidenceId"] for entry in evidence_records], "evidenceId", errors)

    claim_targets: dict[str, tuple[str, dict[str, Any]]] = {}

    def add_claim(claim_id: str, claim_kind: str, record: dict[str, Any]) -> None:
        if claim_id in claim_targets:
            errors.append(f"duplicate claimId: {claim_id}")
        else:
            claim_targets[claim_id] = (claim_kind, record)

    for item in items:
        for claim in item["claims"]:
            suffix = {"nativeType": "type", "nativeSlot": "slot"}.get(claim["predicate"])
            expected_claim_id = f"native-item-{item['runtimeItemId']}-{suffix}"
            if claim["claimId"] != expected_claim_id:
                errors.append(f"native claimId does not match its exact item and predicate: {claim['claimId']}")
            add_claim(claim["claimId"], "native", claim)
    for source in sources:
        for claim in source["claims"]:
            expected_claim_id = f"source-{source['offerSource']}-type"
            if claim["claimId"] != expected_claim_id:
                errors.append(f"source claimId does not match its exact source: {claim['claimId']}")
            add_claim(claim["claimId"], "source", claim)
    for pair in pairs:
        expected_pair_id = f"pair-{pair['offerSource']}-{pair['runtimeItemId']}"
        if pair["claimId"] != expected_pair_id or pair["pairId"] != expected_pair_id:
            errors.append(f"pair identity does not match its exact source and item: {pair['pairId']}")
        add_claim(pair["claimId"], "pair", pair)
    for mapping in mappings:
        add_claim(mapping["claimId"], "mapping", mapping)

    evidence_by_id: dict[str, dict[str, Any]] = {}
    evidence_for_claim: dict[str, set[str]] = {claim_id: set() for claim_id in claim_targets}
    for record in evidence_records:
        evidence_id = record["evidenceId"]
        evidence_by_id[evidence_id] = record
        for claim_id in record["attests"]:
            if claim_id not in claim_targets:
                errors.append(f"evidence {evidence_id} attests unknown claimId: {claim_id}")
                continue
            evidence_for_claim[claim_id].add(evidence_id)

    def check_evidence_links(claim_id: str, evidence_ids: list[str], allowed_kinds: set[str]) -> None:
        listed = set(evidence_ids)
        if listed != evidence_for_claim.get(claim_id, set()):
            errors.append(f"evidence links are not bidirectional for claimId: {claim_id}")
        for evidence_id in listed:
            record = evidence_by_id.get(evidence_id)
            if record is None:
                errors.append(f"claim {claim_id} references unknown evidenceId: {evidence_id}")
            elif record["evidenceKind"] not in allowed_kinds:
                errors.append(
                    f"incompatible evidence kind {record['evidenceKind']} for {claim_id}"
                )

    item_ids = {entry["runtimeItemId"] for entry in items}
    source_ids = {entry["offerSource"] for entry in sources}

    for item in items:
        for claim in item["claims"]:
            check_evidence_links(
                claim["claimId"], claim["evidenceIds"], {"Hades2NativeFile"}
            )
    for source in sources:
        for claim in source["claims"]:
            check_evidence_links(
                claim["claimId"],
                claim["evidenceIds"],
                {"Hades2NativeFile", "Documentary"},
            )
    for pair in pairs:
        check_evidence_links(
            pair["claimId"], pair["evidenceIds"], {"Hades2NativeFile", "Documentary"}
        )
    for mapping in mappings:
        if mapping["runtimeItemId"] not in item_ids:
            errors.append(
                f"unknown or incorrectly cased runtimeItemId in external mapping: {mapping['runtimeItemId']}"
            )
        check_evidence_links(
            mapping["claimId"],
            mapping["evidenceIds"],
            {"MobalyticsPage", "MobalyticsCDN", "Documentary"},
        )

    _unique(
        [f"{pair['offerSource']}|{pair['runtimeItemId']}" for pair in pairs],
        "source/boon pair",
        errors,
    )
    for pair in pairs:
        # Python string/set equality is case-sensitive: no lowercasing or fuzzy match.
        if pair["offerSource"] not in source_ids:
            errors.append(f"unknown or incorrectly cased offerSource: {pair['offerSource']}")
        if pair["runtimeItemId"] not in item_ids:
            errors.append(f"unknown or incorrectly cased runtimeItemId: {pair['runtimeItemId']}")

    actual_trial_pairs = {
        (pair["offerSource"], pair["runtimeItemId"])
        for pair in pairs
        if pair["offerSource"] == "TrialUpgrade"
    }
    if actual_trial_pairs != TRIAL_UPGRADE_ALLOWED_PAIRS:
        errors.append(
            "TrialUpgrade pair allowlist mismatch: expected exactly "
            f"{sorted(TRIAL_UPGRADE_ALLOWED_PAIRS)}, got {sorted(actual_trial_pairs)}"
        )

    # Empty is valid. Any future external-name mapping must carry an explicit,
    # correctly typed evidence record; native game files alone cannot prove it.
    if mappings:
        for mapping in mappings:
            if not mapping["evidenceIds"]:
                errors.append(f"external name mapping lacks evidence: {mapping['mappingId']}")

    if errors:
        raise CatalogValidationError("Catalog semantic validation failed:\n- " + "\n- ".join(errors))


def load_json(path: Path) -> dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8-sig") as source:
            value = json.load(source)
    except (OSError, json.JSONDecodeError) as exc:
        raise CatalogValidationError(f"Could not read valid JSON from {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise CatalogValidationError(f"Expected a JSON object in {path}")
    return value


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    parser.add_argument("--schema", type=Path, default=DEFAULT_SCHEMA)
    args = parser.parse_args()
    try:
        catalog = load_json(args.catalog)
        schema = load_json(args.schema)
        validate_catalog(catalog, schema)
    except CatalogValidationError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    except Exception as exc:  # schema implementation errors must also fail closed
        print(f"Catalog validation could not complete: {exc}", file=sys.stderr)
        return 1
    print(
        "Runtime attestation catalog valid: "
        f"{len(catalog['nativeItems'])} native items, "
        f"{len(catalog['offerSources'])} sources, "
        f"{len(catalog['sourceBoonPairs'])} source/boon pairs, "
        f"{len(catalog['evidence'])} evidence records."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
