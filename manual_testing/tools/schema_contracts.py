from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any


SCHEMAS_DIR = Path(__file__).resolve().parents[1] / "schemas"


class SchemaValidationError(ValueError):
    pass


def load_schema(schema_name: str) -> dict[str, Any]:
    schema_path = SCHEMAS_DIR / f"{schema_name}.schema.json"
    return json.loads(schema_path.read_text())


def validate_against_schema(document: Any, schema: dict[str, Any], path: str = "$") -> None:
    expected_type = schema.get("type")

    if expected_type is not None:
        _validate_type(document, expected_type, path)

    enum_values = schema.get("enum")
    if enum_values is not None and document not in enum_values:
        raise SchemaValidationError(f"{path}: expected one of {enum_values}, got {document!r}")

    if isinstance(document, str):
        min_length = schema.get("minLength")
        if min_length is not None and len(document) < min_length:
            raise SchemaValidationError(f"{path}: expected length >= {min_length}")

        pattern = schema.get("pattern")
        if pattern is not None and re.match(pattern, document) is None:
            raise SchemaValidationError(f"{path}: value {document!r} does not match pattern {pattern!r}")

    if isinstance(document, (int, float)) and not isinstance(document, bool):
        minimum = schema.get("minimum")
        maximum = schema.get("maximum")
        if minimum is not None and document < minimum:
            raise SchemaValidationError(f"{path}: expected value >= {minimum}")
        if maximum is not None and document > maximum:
            raise SchemaValidationError(f"{path}: expected value <= {maximum}")

    if expected_type == "object":
        properties = schema.get("properties", {})
        required = schema.get("required", [])
        additional_properties = schema.get("additionalProperties", True)

        for key in required:
            if key not in document:
                raise SchemaValidationError(f"{path}: missing required property {key!r}")

        for key, value in document.items():
            if key in properties:
                validate_against_schema(value, properties[key], f"{path}.{key}")
            elif additional_properties is False:
                raise SchemaValidationError(f"{path}: unexpected property {key!r}")

    if expected_type == "array":
        min_items = schema.get("minItems")
        if min_items is not None and len(document) < min_items:
            raise SchemaValidationError(f"{path}: expected at least {min_items} item(s)")

        item_schema = schema.get("items")
        if item_schema is not None:
            for index, item in enumerate(document):
                validate_against_schema(item, item_schema, f"{path}[{index}]")


def _validate_type(document: Any, expected_type: str, path: str) -> None:
    type_checks = {
        "object": lambda value: isinstance(value, dict),
        "array": lambda value: isinstance(value, list),
        "string": lambda value: isinstance(value, str),
        "number": lambda value: isinstance(value, (int, float)) and not isinstance(value, bool),
        "integer": lambda value: isinstance(value, int) and not isinstance(value, bool),
        "boolean": lambda value: isinstance(value, bool),
    }

    check = type_checks.get(expected_type)
    if check is None:
        raise SchemaValidationError(f"{path}: unsupported schema type {expected_type!r}")
    if not check(document):
        raise SchemaValidationError(f"{path}: expected type {expected_type}, got {type(document).__name__}")
