#!/usr/bin/env python3
"""
Convert exported banked activity JSON files into a CSV compatible with
the Activity Bank "Bulk Import from CSV" feature.

The converter supports exported banked multiple choice, check-all-that-apply,
ordering, and short-answer activities. Unsupported activity shapes still fail
fast so the generated CSV is safe to import.

Usage:
  Unzip the project export first so the input is a directory of JSON files.
  python /path/to/export_banked_activities_to_csv.py /path/to/export_dir
  python /path/to/export_banked_activities_to_csv.py /path/to/export_dir -o out.csv
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


CSV_HEADERS = [
    "type",
    "title",
    "objectives",
    "tags",
    "stem",
    "choiceA",
    "choiceB",
    "choiceC",
    "choiceD",
    "choiceE",
    "choiceF",
    "answer",
    "correct_feedback",
    "incorrect_feedback",
    "hint1",
    "hint2",
    "hint3",
    "explanation",
]

SUBTYPE_TO_CSV_TYPE = {
    "oli_multiple_choice": "MCQ",
    "oli_check_all_that_apply": "CATA",
    "oli_ordering": "ORDERING",
}

SHORT_ANSWER_INPUT_TYPE_TO_CSV_TYPE = {
    "text": "TEXT",
    "numeric": "NUMBER",
    "math": "MATH",
    "textarea": "PARAGRAPH",
}

CHOICE_LABELS = ["A", "B", "C", "D", "E", "F"]
BRACED_PAYLOAD_RE = re.compile(r"\{((?:\\.|[^}])*)\}")


@dataclass
class ConversionWarning:
    source: str
    message: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Generate a CSV for the Activity Bank bulk import feature from "
            "an exported content directory."
        )
    )
    parser.add_argument(
        "input_dir",
        type=Path,
        help="Directory containing exported JSON files",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Output CSV path. Defaults to <input_dir>/activity_bank_bulk_import.csv",
    )
    return parser.parse_args()


def load_json_documents(input_dir: Path) -> dict[str, dict[str, Any]]:
    if not input_dir.is_dir():
        raise FileNotFoundError(f"Input directory not found: {input_dir}")

    documents: dict[str, dict[str, Any]] = {}

    for path in sorted(input_dir.glob("*.json")):
        with path.open("r", encoding="utf-8") as infile:
            document = json.load(infile)

        document_id = str(document.get("id", path.stem))
        document["_source_path"] = str(path)
        documents[document_id] = document

    return documents


def iter_banked_activities(documents: dict[str, dict[str, Any]]) -> list[dict[str, Any]]:
    activities = [
        document
        for document in documents.values()
        if document.get("scope") == "banked" and document.get("type") == "Activity"
    ]

    def sort_key(document: dict[str, Any]) -> tuple[int, str]:
        raw_id = str(document.get("id", ""))
        return (0, f"{int(raw_id):010d}") if raw_id.isdigit() else (1, raw_id)

    return sorted(activities, key=sort_key)


def stringify_text(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, str):
        return value
    if isinstance(value, (int, float, bool)):
        return str(value)
    return json.dumps(value, ensure_ascii=False)


def extract_plain_text(node: Any) -> str:
    if node is None:
        return ""

    if isinstance(node, str):
        return node

    if isinstance(node, list):
        pieces = [extract_plain_text(item) for item in node]
        return "".join(piece for piece in pieces if piece)

    if not isinstance(node, dict):
        return stringify_text(node)

    if "text" in node:
        return stringify_text(node.get("text"))

    children = node.get("children")
    content = node.get("content")

    if isinstance(children, list):
        return "".join(extract_plain_text(child) for child in children)

    if isinstance(content, list):
        blocks = [extract_plain_text(child).strip("\n") for child in content]
        return "\n".join(block for block in blocks if block != "")

    return ""


def extract_feedback_text(feedback: Any) -> str:
    if isinstance(feedback, dict):
        return extract_plain_text(feedback.get("content")).strip()
    return extract_plain_text(feedback).strip()


def format_bracketed_titles(titles: list[str]) -> str:
    return ",".join(f"[{title}]" for title in titles if title)


def resolve_titles(
    documents: dict[str, dict[str, Any]],
    ids: list[Any],
    expected_type: str,
) -> list[str]:
    titles: list[str] = []

    for raw_id in ids:
        document = documents.get(str(raw_id))
        if not document:
            continue
        if document.get("type") != expected_type:
            continue
        title = stringify_text(document.get("title")).strip()
        if title:
            titles.append(title)

    return titles


def extract_objective_titles(
    activity: dict[str, Any], documents: dict[str, dict[str, Any]]
) -> tuple[list[str], bool]:
    raw_objectives = activity.get("objectives", {})
    if not isinstance(raw_objectives, dict):
        return [], False

    part_titles: list[list[str]] = []
    for raw_ids in raw_objectives.values():
        ids = raw_ids if isinstance(raw_ids, list) else []
        titles = resolve_titles(documents, ids, "Objective")
        part_titles.append(titles)

    deduped: list[str] = []
    for titles in part_titles:
        for title in titles:
            if title not in deduped:
                deduped.append(title)

    distinct_per_part = False
    if part_titles:
        first = part_titles[0]
        distinct_per_part = any(titles != first for titles in part_titles[1:])

    return deduped, distinct_per_part


def extract_tag_titles(activity: dict[str, Any], documents: dict[str, dict[str, Any]]) -> list[str]:
    raw_tags = activity.get("tags", [])
    tag_ids = raw_tags if isinstance(raw_tags, list) else []
    deduped: list[str] = []
    for title in resolve_titles(documents, tag_ids, "Tag"):
        if title not in deduped:
            deduped.append(title)
    return deduped


def extract_choices(content: dict[str, Any]) -> list[dict[str, Any]]:
    raw_choices = content.get("choices", [])
    if not isinstance(raw_choices, list):
        raise ValueError("Activity content does not contain a valid choices list")
    return raw_choices


def extract_content(activity: dict[str, Any]) -> dict[str, Any]:
    content = activity.get("content", {})
    if not isinstance(content, dict):
        raise ValueError("Activity content is not an object")
    return content


def extract_first_part(content: dict[str, Any]) -> dict[str, Any]:
    try:
        part = content["authoring"]["parts"][0]
    except (KeyError, IndexError, TypeError) as exc:
        raise ValueError("Unable to locate the first authoring part") from exc

    if not isinstance(part, dict):
        raise ValueError("The first authoring part is not an object")

    return part


def extract_responses(part: dict[str, Any]) -> list[dict[str, Any]]:
    responses = part.get("responses", [])
    if not isinstance(responses, list) or not responses:
        raise ValueError("Unable to locate authoring responses")
    return responses


def extract_correct_response(responses: list[dict[str, Any]]) -> dict[str, Any]:
    for response in responses:
        if response.get("correct") is True:
            return response
    return responses[0]


def extract_incorrect_response(
    responses: list[dict[str, Any]], correct_response: dict[str, Any]
) -> dict[str, Any] | None:
    for response in responses:
        if response is not correct_response:
            return response
    return None


def extract_rule_payloads(rule: Any) -> list[str]:
    return BRACED_PAYLOAD_RE.findall(stringify_text(rule))


def unescape_rule_input(value: str) -> str:
    return re.sub(r"\\([\\{}])", r"\1", value)


def extract_choice_ids(choices: list[dict[str, Any]]) -> list[str]:
    choice_ids = [stringify_text(choice.get("id")).strip() for choice in choices]
    if any(not choice_id for choice_id in choice_ids):
        raise ValueError("One or more choices are missing ids")
    return choice_ids


def extract_choice_texts(choices: list[dict[str, Any]]) -> list[str]:
    if len(choices) > len(CHOICE_LABELS):
        raise ValueError(
            f"Activity has {len(choices)} choices, exceeding CSV support for {len(CHOICE_LABELS)}"
        )

    choice_texts = [extract_plain_text(choice.get("content")).strip() for choice in choices]
    if any(not choice_text for choice_text in choice_texts):
        raise ValueError("One or more choices flatten to empty text")

    return choice_texts


def map_choice_ids_to_answer(choices: list[dict[str, Any]], selected_ids: list[str]) -> str:
    choice_ids = extract_choice_ids(choices)
    label_by_choice_id: dict[str, str] = {}

    for index, choice_id in enumerate(choice_ids):
        if index >= len(CHOICE_LABELS):
            raise ValueError(
                f"Choice index {index} exceeds CSV template capacity of {len(CHOICE_LABELS)}"
            )
        label_by_choice_id[choice_id] = CHOICE_LABELS[index]

    labels: list[str] = []
    for choice_id in selected_ids:
        if choice_id not in label_by_choice_id:
            raise ValueError(f"Correct choice id {choice_id} not found in choice list")
        label = label_by_choice_id[choice_id]
        if label not in labels:
            labels.append(label)

    if not labels:
        raise ValueError("No correct choices were resolved from the activity")

    return ",".join(labels)


def build_base_row(
    activity: dict[str, Any],
    documents: dict[str, dict[str, Any]],
    csv_type: str,
) -> tuple[dict[str, str], list[ConversionWarning]]:
    warnings: list[ConversionWarning] = []
    source = activity["_source_path"]
    content = extract_content(activity)
    title = stringify_text(activity.get("title")).strip()

    if not title:
        raise ValueError("Activity title is empty")

    objectives, objectives_are_lossy = extract_objective_titles(activity, documents)
    if objectives_are_lossy:
        warnings.append(
            ConversionWarning(
                source=source,
                message=(
                    "per-part objectives were flattened to a single CSV objective list; "
                    "bulk import will attach the same objectives to all parts"
                ),
            )
        )

    row = {header: "" for header in CSV_HEADERS}
    row["type"] = csv_type
    row["title"] = title
    row["objectives"] = format_bracketed_titles(objectives)
    row["tags"] = format_bracketed_titles(extract_tag_titles(activity, documents))
    row["stem"] = extract_plain_text(content.get("stem")).strip()

    return row, warnings


def maybe_warn_about_rich_text(
    warnings: list[ConversionWarning], source: str, nodes: list[Any]
) -> None:
    if any(contains_rich_text_markup(node) for node in nodes):
        warnings.append(
            ConversionWarning(
                source=source,
                message="rich-text formatting will be flattened to plain text in CSV output",
            )
        )


def populate_feedback_hints_and_explanation(
    row: dict[str, str], part: dict[str, Any], responses: list[dict[str, Any]]
) -> None:
    correct_response = extract_correct_response(responses)
    incorrect_response = extract_incorrect_response(responses, correct_response)

    row["correct_feedback"] = (
        extract_feedback_text(correct_response.get("feedback")) or "Correct"
    )
    if incorrect_response is not None:
        row["incorrect_feedback"] = (
            extract_feedback_text(incorrect_response.get("feedback")) or "Incorrect"
        )

    hints = part.get("hints", [])
    if isinstance(hints, list):
        for index, hint in enumerate(hints[:3], start=1):
            row[f"hint{index}"] = extract_feedback_text(hint)

    row["explanation"] = extract_feedback_text(part.get("explanation"))


def determine_csv_type(activity: dict[str, Any]) -> str:
    subtype = stringify_text(activity.get("subType")).strip()
    if subtype == "oli_short_answer":
        content = extract_content(activity)
        input_type = stringify_text(content.get("inputType")).strip()
        csv_type = SHORT_ANSWER_INPUT_TYPE_TO_CSV_TYPE.get(input_type)
        if csv_type is None:
            supported = ", ".join(sorted(SHORT_ANSWER_INPUT_TYPE_TO_CSV_TYPE))
            raise ValueError(
                f"Unsupported oli_short_answer inputType {input_type!r}. "
                f"Supported input types: {supported}"
            )
        return csv_type

    csv_type = SUBTYPE_TO_CSV_TYPE.get(subtype)
    if csv_type is None:
        supported = ", ".join(
            sorted(list(SUBTYPE_TO_CSV_TYPE) + ["oli_short_answer"])
        )
        raise ValueError(
            f"Unsupported activity subtype {subtype!r}. Supported subtypes: {supported}"
        )

    return csv_type


def extract_correct_choice_label(part: dict[str, Any], choices: list[dict[str, Any]]) -> str:
    responses = extract_responses(part)
    correct_response = extract_correct_response(responses)
    payloads = extract_rule_payloads(correct_response.get("rule"))
    if not payloads:
        raise ValueError(f"Unsupported correct response rule: {correct_response.get('rule')}")

    return map_choice_ids_to_answer(choices, [payloads[0]])


def extract_authoring_correct_choice_ids(content: dict[str, Any]) -> list[str] | None:
    authoring = content.get("authoring", {})
    if not isinstance(authoring, dict):
        return None

    raw_correct = authoring.get("correct")
    if not isinstance(raw_correct, list) or not raw_correct:
        return None

    selected = raw_correct[0]
    if not isinstance(selected, list):
        return None

    return [stringify_text(choice_id).strip() for choice_id in selected if stringify_text(choice_id).strip()]


def extract_cata_answer(content: dict[str, Any], part: dict[str, Any], choices: list[dict[str, Any]]) -> str:
    correct_ids = extract_authoring_correct_choice_ids(content)
    if not correct_ids:
        responses = extract_responses(part)
        correct_rule = stringify_text(extract_correct_response(responses).get("rule"))
        choice_ids = extract_choice_ids(choices)
        correct_ids = [
            choice_id
            for choice_id in choice_ids
            if f"input like {{{choice_id}}}" in correct_rule
            and f"!(input like {{{choice_id}}})" not in correct_rule
        ]

    return map_choice_ids_to_answer(choices, correct_ids)


def extract_ordering_answer(
    content: dict[str, Any], part: dict[str, Any], choices: list[dict[str, Any]]
) -> str:
    correct_ids = extract_authoring_correct_choice_ids(content)
    if not correct_ids:
        responses = extract_responses(part)
        payloads = extract_rule_payloads(extract_correct_response(responses).get("rule"))
        if not payloads:
            raise ValueError("Unable to determine the ordering answer")
        correct_ids = [piece for piece in payloads[0].split() if piece]

    return map_choice_ids_to_answer(choices, correct_ids)


def extract_short_answer_value(csv_type: str, correct_rule: str) -> str:
    payloads = extract_rule_payloads(correct_rule)
    if csv_type == "PARAGRAPH":
        return ""

    if len(payloads) != 1:
        raise ValueError(f"Unsupported short answer rule: {correct_rule}")

    payload = payloads[0]
    if csv_type == "TEXT":
        if "input contains" not in correct_rule:
            raise ValueError(f"Unsupported text short answer rule: {correct_rule}")
        return unescape_rule_input(payload)
    if csv_type == "NUMBER":
        if "input = {" not in correct_rule:
            raise ValueError(f"Unsupported numeric short answer rule: {correct_rule}")
        return payload
    if csv_type == "MATH":
        if "input equals" not in correct_rule:
            raise ValueError(f"Unsupported math short answer rule: {correct_rule}")
        return unescape_rule_input(payload)

    raise ValueError(f"Unsupported short answer CSV type: {csv_type}")


def convert_multiple_choice(
    activity: dict[str, Any], documents: dict[str, dict[str, Any]]
) -> tuple[dict[str, str], list[ConversionWarning]]:
    source = activity["_source_path"]
    content = extract_content(activity)
    part = extract_first_part(content)
    responses = extract_responses(part)
    row, warnings = build_base_row(activity, documents, "MCQ")
    choices = extract_choices(content)
    choice_texts = extract_choice_texts(choices)
    row["answer"] = extract_correct_choice_label(part, choices)

    for index, choice_text in enumerate(choice_texts):
        row[f"choice{CHOICE_LABELS[index]}"] = choice_text

    maybe_warn_about_rich_text(
        warnings,
        source,
        [content.get("stem")]
        + [choice.get("content") for choice in choices]
        + [response.get("feedback") for response in responses]
        + list(part.get("hints", []))
        + [part.get("explanation")],
    )
    populate_feedback_hints_and_explanation(row, part, responses)

    return row, warnings


def convert_check_all_that_apply(
    activity: dict[str, Any], documents: dict[str, dict[str, Any]]
) -> tuple[dict[str, str], list[ConversionWarning]]:
    source = activity["_source_path"]
    content = extract_content(activity)
    part = extract_first_part(content)
    responses = extract_responses(part)
    row, warnings = build_base_row(activity, documents, "CATA")
    choices = extract_choices(content)
    choice_texts = extract_choice_texts(choices)
    row["answer"] = extract_cata_answer(content, part, choices)

    for index, choice_text in enumerate(choice_texts):
        row[f"choice{CHOICE_LABELS[index]}"] = choice_text

    maybe_warn_about_rich_text(
        warnings,
        source,
        [content.get("stem")]
        + [choice.get("content") for choice in choices]
        + [response.get("feedback") for response in responses]
        + list(part.get("hints", []))
        + [part.get("explanation")],
    )
    populate_feedback_hints_and_explanation(row, part, responses)

    return row, warnings


def convert_ordering(
    activity: dict[str, Any], documents: dict[str, dict[str, Any]]
) -> tuple[dict[str, str], list[ConversionWarning]]:
    source = activity["_source_path"]
    content = extract_content(activity)
    part = extract_first_part(content)
    responses = extract_responses(part)
    row, warnings = build_base_row(activity, documents, "ORDERING")
    choices = extract_choices(content)
    choice_texts = extract_choice_texts(choices)
    row["answer"] = extract_ordering_answer(content, part, choices)

    for index, choice_text in enumerate(choice_texts):
        row[f"choice{CHOICE_LABELS[index]}"] = choice_text

    maybe_warn_about_rich_text(
        warnings,
        source,
        [content.get("stem")]
        + [choice.get("content") for choice in choices]
        + [response.get("feedback") for response in responses]
        + list(part.get("hints", []))
        + [part.get("explanation")],
    )
    populate_feedback_hints_and_explanation(row, part, responses)

    return row, warnings


def convert_short_answer(
    activity: dict[str, Any], documents: dict[str, dict[str, Any]]
) -> tuple[dict[str, str], list[ConversionWarning]]:
    source = activity["_source_path"]
    content = extract_content(activity)
    part = extract_first_part(content)
    responses = extract_responses(part)
    csv_type = determine_csv_type(activity)
    row, warnings = build_base_row(activity, documents, csv_type)
    correct_rule = stringify_text(extract_correct_response(responses).get("rule")).strip()
    row["answer"] = extract_short_answer_value(csv_type, correct_rule)

    maybe_warn_about_rich_text(
        warnings,
        source,
        [content.get("stem")]
        + [response.get("feedback") for response in responses]
        + list(part.get("hints", []))
        + [part.get("explanation")],
    )
    populate_feedback_hints_and_explanation(row, part, responses)

    if csv_type == "PARAGRAPH":
        warnings.append(
            ConversionWarning(
                source=source,
                message=(
                    "textarea short-answer items map to CSV PARAGRAPH, which does not "
                    "preserve the original answer rule or feedback behavior"
                ),
            )
        )

    return row, warnings


def contains_rich_text_markup(node: Any) -> bool:
    if isinstance(node, list):
        return any(contains_rich_text_markup(item) for item in node)

    if not isinstance(node, dict):
        return False

    formatting_keys = {"bold", "italic", "code", "underline", "strikethrough", "strong", "em"}
    if any(bool(node.get(key)) for key in formatting_keys):
        return True

    for child_key in ("children", "content"):
        child = node.get(child_key)
        if contains_rich_text_markup(child):
            return True

    return False


def convert_activity(
    activity: dict[str, Any], documents: dict[str, dict[str, Any]]
) -> tuple[dict[str, str], list[ConversionWarning]]:
    subtype = stringify_text(activity.get("subType")).strip()
    if subtype == "oli_multiple_choice":
        return convert_multiple_choice(activity, documents)
    if subtype == "oli_check_all_that_apply":
        return convert_check_all_that_apply(activity, documents)
    if subtype == "oli_ordering":
        return convert_ordering(activity, documents)
    if subtype == "oli_short_answer":
        return convert_short_answer(activity, documents)

    raise ValueError(f"No converter implemented for subtype {subtype!r}")


def write_csv(rows: list[dict[str, str]], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8", newline="") as outfile:
        writer = csv.DictWriter(outfile, fieldnames=CSV_HEADERS)
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    args = parse_args()
    documents = load_json_documents(args.input_dir)
    activities = iter_banked_activities(documents)

    if not activities:
        print("No banked Activity JSON files found.", file=sys.stderr)
        return 1

    rows: list[dict[str, str]] = []
    warnings: list[ConversionWarning] = []

    for activity in activities:
        row, row_warnings = convert_activity(activity, documents)
        rows.append(row)
        warnings.extend(row_warnings)

    output_path = (
        args.output
        if args.output is not None
        else args.input_dir / "activity_bank_bulk_import.csv"
    )
    write_csv(rows, output_path)

    print(f"Wrote {len(rows)} activities to {output_path}")

    if warnings:
        print("", file=sys.stderr)
        print("Warnings:", file=sys.stderr)
        for warning in warnings:
            print(f"- {warning.source}: {warning.message}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
