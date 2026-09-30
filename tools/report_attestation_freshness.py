"""Report which catalog attestations need review against an installed game tree.

This tool is read-only with respect to the catalog. It never changes claim
statuses, evidence, hashes, identities, or source/boon pairs.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
from typing import Any

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPOSITORY_ROOT / "tools"))

from validate_runtime_attestations import (  # noqa: E402
    CatalogValidationError,
    load_json,
    validate_catalog,
)


def _claim_targets(catalog: dict[str, Any]) -> dict[str, dict[str, Any]]:
    targets: dict[str, dict[str, Any]] = {}
    for item in catalog["nativeItems"]:
        for claim in item["claims"]:
            targets[claim["claimId"]] = {
                "kind": "nativeItem",
                "runtimeItemId": item["runtimeItemId"],
            }
    for source in catalog["offerSources"]:
        for claim in source["claims"]:
            targets[claim["claimId"]] = {
                "kind": "offerSource",
                "offerSource": source["offerSource"],
            }
    for pair in catalog["sourceBoonPairs"]:
        targets[pair["claimId"]] = {
            "kind": "sourceBoonPair",
            "offerSource": pair["offerSource"],
            "runtimeItemId": pair["runtimeItemId"],
        }
    for mapping in catalog["externalNameMappings"]:
        targets[mapping["claimId"]] = {
            "kind": "externalNameMapping",
            "mappingId": mapping["mappingId"],
            "provider": mapping["provider"],
            "externalName": mapping["externalName"],
            "runtimeItemId": mapping["runtimeItemId"],
        }
    return targets


def _claim_evidence(catalog: dict[str, Any]) -> dict[str, list[str]]:
    evidence_ids: dict[str, list[str]] = {}

    def add(claim: dict[str, Any]) -> None:
        evidence_ids[claim["claimId"]] = sorted(claim["evidenceIds"])

    for item in catalog["nativeItems"]:
        for claim in item["claims"]:
            add(claim)
    for source in catalog["offerSources"]:
        for claim in source["claims"]:
            add(claim)
    for pair in catalog["sourceBoonPairs"]:
        evidence_ids[pair["claimId"]] = sorted(pair["evidenceIds"])
    for mapping in catalog["externalNameMappings"]:
        evidence_ids[mapping["claimId"]] = sorted(mapping["evidenceIds"])
    return evidence_ids


def _claim_statuses(catalog: dict[str, Any]) -> dict[str, str]:
    statuses: dict[str, str] = {}
    for section, key in (("nativeItems", "claims"), ("offerSources", "claims")):
        for record in catalog[section]:
            for claim in record[key]:
                statuses[claim["claimId"]] = claim["status"]
    for section in ("sourceBoonPairs", "externalNameMappings"):
        for record in catalog[section]:
            statuses[record["claimId"]] = record["status"]
    return statuses


def _hash_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def build_freshness_report(
    catalog: dict[str, Any],
    game_root: Path,
    observed_game_build: str | None = None,
) -> dict[str, Any]:
    """Compare recorded native-file hashes and return a deterministic report."""
    game_root = game_root.resolve(strict=True)
    if not game_root.is_dir():
        raise ValueError(f"Game root is not a directory: {game_root}")

    targets = _claim_targets(catalog)
    claim_evidence = _claim_evidence(catalog)
    claim_statuses = _claim_statuses(catalog)
    evidence_status: dict[str, str] = {}
    evidence_results: list[dict[str, Any]] = []

    for record in sorted(catalog["evidence"], key=lambda row: row["evidenceId"]):
        result: dict[str, Any] = {
            "evidenceId": record["evidenceId"],
            "evidenceKind": record["evidenceKind"],
            "recordedGameBuild": record.get("gameBuild"),
            "filePath": record.get("filePath"),
            "expectedSha256": record.get("sha256"),
            "claimDependencies": [
                {"claimId": claim_id, "target": targets[claim_id]}
                for claim_id in sorted(record["attests"])
            ],
        }
        if record["evidenceKind"] != "Hades2NativeFile":
            status = "not_file_backed"
            result["revalidation"] = "not_applicable"
        else:
            relative = Path(record["filePath"])
            if relative.is_absolute() or ".." in relative.parts:
                status = "indeterminate"
                result["error"] = "catalog filePath is not a safe path beneath --game-root"
            else:
                try:
                    path = (game_root / relative).resolve()
                    path.relative_to(game_root)
                    if not path.exists():
                        status = "missing"
                    elif not path.is_file():
                        status = "error"
                        result["error"] = "evidence path exists but is not a regular file"
                    else:
                        try:
                            current_hash = _hash_file(path)
                        except OSError as exc:
                            status = "error"
                            result["error"] = f"{type(exc).__name__}: {exc}"
                        else:
                            result["observedSha256"] = current_hash
                            status = (
                                "unchanged"
                                if current_hash == record["sha256"].upper()
                                else "modified"
                            )
                except ValueError:
                    status = "indeterminate"
                    result["error"] = "resolved filePath escapes --game-root"
                except (OSError, RuntimeError) as exc:
                    status = "error"
                    result["error"] = f"{type(exc).__name__}: {exc}"
            result["revalidation"] = {
                "unchanged": "none",
                "modified": "required",
                "missing": "freshness_unknown",
                "error": "freshness_unknown",
                "indeterminate": "freshness_unknown",
            }[status]
        evidence_status[record["evidenceId"]] = status
        result["status"] = status
        if observed_game_build is not None:
            result["observedGameBuild"] = observed_game_build
        evidence_results.append(result)

    claim_results: list[dict[str, Any]] = []
    for claim_id in sorted(targets):
        dependencies = claim_evidence[claim_id]
        changed = [evidence_id for evidence_id in dependencies if evidence_status[evidence_id] == "modified"]
        unknown = [
            evidence_id
            for evidence_id in dependencies
            if evidence_status[evidence_id] in {"missing", "error", "indeterminate"}
        ]
        if changed:
            freshness = "needs_revalidation"
        elif unknown:
            freshness = "unknown"
        else:
            freshness = "fresh"
        claim_results.append(
            {
                "claimId": claim_id,
                "target": targets[claim_id],
                "catalogStatus": claim_statuses[claim_id],
                "freshness": freshness,
                "evidenceIds": dependencies,
                "modifiedEvidenceIds": changed,
                "unavailableEvidenceIds": unknown,
            }
        )

    statuses = [result["status"] for result in evidence_results]
    summary = {
        "evidenceUnchanged": statuses.count("unchanged"),
        "evidenceModified": statuses.count("modified"),
        "evidenceMissing": statuses.count("missing"),
        "evidenceErrors": statuses.count("error"),
        "evidenceIndeterminate": statuses.count("indeterminate"),
        "evidenceNotFileBacked": statuses.count("not_file_backed"),
        "claimsFresh": sum(row["freshness"] == "fresh" for row in claim_results),
        "claimsNeedRevalidation": sum(row["freshness"] == "needs_revalidation" for row in claim_results),
        "claimsFreshnessUnknown": sum(row["freshness"] == "unknown" for row in claim_results),
    }
    report: dict[str, Any] = {
        "reportVersion": 1,
        "catalogSchemaVersion": catalog["schemaVersion"],
        "observedGameBuild": observed_game_build,
        "summary": summary,
        "evidence": evidence_results,
        "claims": claim_results,
        "automaticCatalogChanges": False,
    }
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, default=REPOSITORY_ROOT / "data/canonical/catalog/runtime_attestations.json")
    parser.add_argument("--schema", type=Path, default=REPOSITORY_ROOT / "data/canonical/catalog/runtime_attestations.schema.json")
    parser.add_argument("--game-root", type=Path, required=True, help="Root of the Hades II installation containing Content/Scripts")
    parser.add_argument("--game-build", help="Observed game build/version, if known")
    parser.add_argument("--output", type=Path, help="Optional JSON report path; catalog is never used as an output")
    args = parser.parse_args()

    try:
        catalog = load_json(args.catalog)
        schema = load_json(args.schema)
        validate_catalog(catalog, schema)
        report = build_freshness_report(catalog, args.game_root, args.game_build)
        rendered = json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
        if args.output is None:
            sys.stdout.write(rendered)
        else:
            output_path = args.output.resolve()
            protected_inputs = {
                os.path.normcase(str(args.catalog.resolve())),
                os.path.normcase(str(args.schema.resolve())),
            }
            game_root = args.game_root.resolve(strict=True)
            for evidence in catalog["evidence"]:
                if evidence["evidenceKind"] != "Hades2NativeFile":
                    continue
                relative = Path(evidence["filePath"])
                if relative.is_absolute() or ".." in relative.parts:
                    continue
                try:
                    evidence_path = (game_root / relative).resolve()
                    evidence_path.relative_to(game_root)
                except (OSError, RuntimeError, ValueError):
                    continue
                protected_inputs.add(os.path.normcase(str(evidence_path)))
            if os.path.normcase(str(output_path)) in protected_inputs:
                raise ValueError("Report output cannot overwrite the catalog, schema, or evidence files.")
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_text(rendered, encoding="utf-8")
    except (CatalogValidationError, OSError, ValueError) as exc:
        print(f"Attestation freshness report could not complete: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
