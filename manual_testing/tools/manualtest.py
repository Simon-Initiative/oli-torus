from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from manual_testing.tools.conversion import convert_csv_to_cases
from manual_testing.tools.reporting import normalize_runtime_result, write_run_report, write_suite_summary
from manual_testing.tools.runtime_contract import build_execution_requests
from manual_testing.tools.validation import format_validation_error, lint_file, validate_file


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="manualtest.py")
    subparsers = parser.add_subparsers(dest="command", required=True)

    validate_parser = subparsers.add_parser("validate")
    validate_parser.add_argument("path")
    validate_parser.add_argument("--type", choices=["case", "suite", "run"])

    lint_parser = subparsers.add_parser("lint")
    lint_parser.add_argument("path")
    lint_parser.add_argument("--type", choices=["case", "suite", "run"])

    convert_parser = subparsers.add_parser("convert")
    convert_parser.add_argument("--input", required=True)
    convert_parser.add_argument("--output-dir", required=True)

    prepare_parser = subparsers.add_parser("prepare-run")
    target_group = prepare_parser.add_mutually_exclusive_group(required=True)
    target_group.add_argument("--suite")
    target_group.add_argument("--case")
    prepare_parser.add_argument("--environment-label", required=True)
    prepare_parser.add_argument("--credentials-source-ref", required=True)
    prepare_parser.add_argument("--base-url")
    prepare_parser.add_argument("--release-ref")
    prepare_parser.add_argument("--run-label")
    prepare_parser.add_argument("--doc-context-path", action="append", default=[])

    normalize_parser = subparsers.add_parser("normalize-run")
    normalize_parser.add_argument("--manifest", required=True)
    normalize_parser.add_argument("--result", required=True)
    normalize_parser.add_argument("--results-root", required=True)
    normalize_parser.add_argument("--write-suite-summary", action="store_true")

    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)

    if args.command == "validate":
        return _run_validate(Path(args.path), args.type)
    if args.command == "lint":
        return _run_lint(Path(args.path), args.type)
    if args.command == "convert":
        return _run_convert(Path(args.input), Path(args.output_dir))
    if args.command == "prepare-run":
        return _run_prepare_run(args)
    if args.command == "normalize-run":
        return _run_normalize_run(Path(args.manifest), Path(args.result), Path(args.results_root), args.write_suite_summary)

    print(f"Unsupported command: {args.command}", file=sys.stderr)
    return 1


def _run_validate(path: Path, doc_type: str | None) -> int:
    try:
        result = validate_file(path, doc_type)
    except Exception as error:
        print(format_validation_error(error), file=sys.stderr)
        return 1

    print(json.dumps({"ok": True, "type": result["type"], "path": str(path)}))
    return 0


def _run_lint(path: Path, doc_type: str | None) -> int:
    try:
        issues = lint_file(path, doc_type)
    except Exception as error:
        print(format_validation_error(error), file=sys.stderr)
        return 1

    payload = {"ok": len(issues) == 0, "issues": issues, "path": str(path)}
    print(json.dumps(payload))
    return 0 if not issues else 1


def _run_convert(input_path: Path, output_dir: Path) -> int:
    try:
        payload = convert_csv_to_cases(input_path, output_dir)
    except Exception as error:
        print(str(error), file=sys.stderr)
        return 1

    print(json.dumps({"ok": True, "converted": payload}, indent=2))
    return 0


def _run_prepare_run(args: argparse.Namespace) -> int:
    target_type = "suite" if args.suite else "case"
    target_id = args.suite or args.case
    try:
        payload = build_execution_requests(
            manual_testing_root=Path(__file__).resolve().parents[1],
            target_type=target_type,
            target_id=target_id,
            environment_label=args.environment_label,
            credentials_source_ref=args.credentials_source_ref,
            doc_context_paths=args.doc_context_path,
            base_url=args.base_url,
            release_ref=args.release_ref,
            run_label=args.run_label,
        )
    except Exception as error:
        print(str(error), file=sys.stderr)
        return 1

    print(json.dumps({"ok": True, "requests": payload}, indent=2))
    return 0


def _run_normalize_run(
    manifest_path: Path,
    result_path: Path,
    results_root: Path,
    write_suite_summary_flag: bool,
) -> int:
    try:
        manifest = json.loads(manifest_path.read_text())
        runtime_result = json.loads(result_path.read_text())
        report = normalize_runtime_result(manifest, runtime_result)
        report_path = write_run_report(report, results_root)
        payload: dict[str, object] = {"ok": True, "report_path": str(report_path)}
        if write_suite_summary_flag and "suite_id" in report:
            summary_path = write_suite_summary(
                suite_id=report["suite_id"],
                suite_run_id=manifest.get("suite_run_id", report["run_id"]),
                reports=[report],
                results_root=results_root,
            )
            payload["summary_path"] = str(summary_path)
    except Exception as error:
        print(str(error), file=sys.stderr)
        return 1

    print(json.dumps(payload, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
