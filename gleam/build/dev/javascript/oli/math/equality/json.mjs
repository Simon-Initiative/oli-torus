/// <reference types="./json.d.mts" />
import * as $gleam_json from "../../../gleam_json/gleam/json.mjs";
import * as $dynamic from "../../../gleam_stdlib/gleam/dynamic.mjs";
import * as $decode from "../../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $int from "../../../gleam_stdlib/gleam/int.mjs";
import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
import { Ok, Error, toList, Empty as $Empty, prepend as listPrepend } from "../../gleam.mjs";
import * as $ast from "../../math/ast.mjs";
import * as $evaluate from "../../math/equality/evaluate.mjs";
import * as $types from "../../math/equality/types.mjs";

function field_error(field, expected, errors) {
  let $ = $list.any(errors, (error) => { return error.found === "Nothing"; });
  if ($) {
    return new $types.MissingField(field);
  } else {
    return new $types.InvalidField(field, "expected " + expected);
  }
}

/**
 * All field reads go through `gleam/dynamic/decode` so JSON structure handling
 * is delegated to the library while Torus still maps failures into stable
 * equality-config error variants.
 * 
 * @ignore
 */
function read_field(dynamic, field, decoder, expected) {
  let $ = $decode.run(dynamic, $decode.field(field, decoder, $decode.success));
  if ($ instanceof Ok) {
    return $;
  } else {
    let errors = $[0];
    return new Error(field_error(field, expected, errors));
  }
}

function read_string_list(dynamic, field) {
  return read_field(
    dynamic,
    field,
    $decode.list($decode.string),
    "string array",
  );
}

function decode_unit_list(dynamic, constructor) {
  let $ = read_string_list(dynamic, "units");
  if ($ instanceof Ok) {
    let units = $[0];
    return new Ok(constructor(units));
  } else {
    return $;
  }
}

function read_string(dynamic, field) {
  return read_field(dynamic, field, $decode.string, "string");
}

function decode_unit_policy(dynamic) {
  let $ = read_string(dynamic, "type");
  if ($ instanceof Ok) {
    let kind = $[0];
    if (kind === "ignored") {
      return new Ok(new $types.UnitsIgnored());
    } else if (kind === "required") {
      return new Ok(new $types.UnitsRequired());
    } else if (kind === "accepted_units") {
      return decode_unit_list(
        dynamic,
        (var0) => { return new $types.AcceptedUnits(var0); },
      );
    } else if (kind === "strict_unit") {
      let $1 = read_string(dynamic, "unit");
      if ($1 instanceof Ok) {
        let unit = $1[0];
        return new Ok(new $types.StrictUnit(unit));
      } else {
        return $1;
      }
    } else if (kind === "convertible_units") {
      return decode_unit_list(
        dynamic,
        (var0) => { return new $types.ConvertibleUnits(var0); },
      );
    } else {
      let other = kind;
      return new Error(new $types.UnknownDiscriminator("policy.type", other));
    }
  } else {
    return $;
  }
}

function read_dynamic(dynamic, field) {
  return read_field(dynamic, field, $decode.dynamic, "value");
}

function decode_unit_comparison(dynamic) {
  let $ = read_string(dynamic, "type");
  if ($ instanceof Ok) {
    let kind = $[0];
    if (kind === "unit_numeric") {
      let $1 = read_string(dynamic, "expectedValue");
      if ($1 instanceof Ok) {
        let expected_value = $1[0];
        let $2 = read_string(dynamic, "expectedUnit");
        if ($2 instanceof Ok) {
          let expected_unit = $2[0];
          return new Ok(
            new $types.UnitNumeric(
              $types.numeric_input(expected_value),
              expected_unit,
            ),
          );
        } else {
          return $2;
        }
      } else {
        return $1;
      }
    } else if (kind === "unit_expression") {
      let $1 = read_string(dynamic, "expectedExpression");
      if ($1 instanceof Ok) {
        let expected_expression = $1[0];
        let $2 = read_string(dynamic, "expectedUnit");
        if ($2 instanceof Ok) {
          let expected_unit = $2[0];
          return new Ok(
            new $types.UnitExpression(expected_expression, expected_unit),
          );
        } else {
          return $2;
        }
      } else {
        return $1;
      }
    } else {
      let other = kind;
      return new Error(
        new $types.UnknownDiscriminator("comparison.type", other),
      );
    }
  } else {
    return $;
  }
}

function decode_unit_spec(dynamic, version) {
  let $ = read_dynamic(dynamic, "comparison");
  if ($ instanceof Ok) {
    let comparison_dynamic = $[0];
    let $1 = decode_unit_comparison(comparison_dynamic);
    if ($1 instanceof Ok) {
      let comparison = $1[0];
      let $2 = read_dynamic(dynamic, "policy");
      if ($2 instanceof Ok) {
        let policy_dynamic = $2[0];
        let $3 = decode_unit_policy(policy_dynamic);
        if ($3 instanceof Ok) {
          let policy = $3[0];
          return new Ok(
            new $types.EqualitySpec(
              version,
              new $types.UnitAware(new $types.UnitSpec(comparison, policy)),
            ),
          );
        } else {
          return $3;
        }
      } else {
        return $2;
      }
    } else {
      return $1;
    }
  } else {
    return $;
  }
}

function read_float(dynamic, field) {
  return read_field(
    dynamic,
    field,
    $decode.one_of(
      $decode.float,
      toList([
        (() => {
          let _pipe = $decode.int;
          return $decode.map(_pipe, $int.to_float);
        })(),
      ]),
    ),
    "number",
  );
}

function decode_domain(dynamic) {
  let $ = read_string(dynamic, "name");
  if ($ instanceof Ok) {
    let name = $[0];
    let $1 = read_float(dynamic, "lower");
    if ($1 instanceof Ok) {
      let lower = $1[0];
      let $2 = read_float(dynamic, "upper");
      if ($2 instanceof Ok) {
        let upper = $2[0];
        return new Ok(new $types.VariableDomain(name, lower, upper));
      } else {
        return $2;
      }
    } else {
      return $1;
    }
  } else {
    return $;
  }
}

function decode_domains(loop$values, loop$acc) {
  while (true) {
    let values = loop$values;
    let acc = loop$acc;
    if (values instanceof $Empty) {
      return new Ok($list.reverse(acc));
    } else {
      let first = values.head;
      let rest = values.tail;
      let $ = decode_domain(first);
      if ($ instanceof Ok) {
        let domain = $[0];
        loop$values = rest;
        loop$acc = listPrepend(domain, acc);
      } else {
        return $;
      }
    }
  }
}

function read_dynamic_list(dynamic, field) {
  return read_field(dynamic, field, $decode.list($decode.dynamic), "array");
}

function function_from_string(raw) {
  if (raw === "sin") {
    return new Ok(new $ast.Sin());
  } else if (raw === "cos") {
    return new Ok(new $ast.Cos());
  } else if (raw === "tan") {
    return new Ok(new $ast.Tan());
  } else if (raw === "ln") {
    return new Ok(new $ast.Ln());
  } else if (raw === "log") {
    return new Ok(new $ast.Log());
  } else if (raw === "log10") {
    return new Ok(new $ast.Log10());
  } else if (raw === "log2") {
    return new Ok(new $ast.Log2());
  } else if (raw === "sqrt") {
    return new Ok(new $ast.Sqrt());
  } else if (raw === "abs") {
    return new Ok(new $ast.Abs());
  } else if (raw === "exp") {
    return new Ok(new $ast.Exp());
  } else {
    let other = raw;
    return new Error(
      new $types.UnknownDiscriminator("allowedFunctions[]", other),
    );
  }
}

function decode_functions_loop(loop$raw_functions, loop$acc) {
  while (true) {
    let raw_functions = loop$raw_functions;
    let acc = loop$acc;
    if (raw_functions instanceof $Empty) {
      return new Ok($list.reverse(acc));
    } else {
      let first = raw_functions.head;
      let rest = raw_functions.tail;
      let $ = function_from_string(first);
      if ($ instanceof Ok) {
        let name = $[0];
        loop$raw_functions = rest;
        loop$acc = listPrepend(name, acc);
      } else {
        return $;
      }
    }
  }
}

function decode_functions(raw_functions) {
  return decode_functions_loop(raw_functions, toList([]));
}

function decode_expression_validation(dynamic) {
  let $ = read_string_list(dynamic, "allowedVariables");
  if ($ instanceof Ok) {
    let allowed_variables = $[0];
    let $1 = read_string_list(dynamic, "allowedFunctions");
    if ($1 instanceof Ok) {
      let raw_functions = $1[0];
      let $2 = decode_functions(raw_functions);
      if ($2 instanceof Ok) {
        let allowed_functions = $2[0];
        let $3 = read_dynamic_list(dynamic, "domains");
        if ($3 instanceof Ok) {
          let domain_values = $3[0];
          let $4 = decode_domains(domain_values, toList([]));
          if ($4 instanceof Ok) {
            let domains = $4[0];
            return new Ok(
              new $types.ExpressionValidation(
                allowed_variables,
                allowed_functions,
                domains,
              ),
            );
          } else {
            return $4;
          }
        } else {
          return $3;
        }
      } else {
        return $2;
      }
    } else {
      return $1;
    }
  } else {
    return $;
  }
}

function read_int(dynamic, field) {
  return read_field(dynamic, field, $decode.int, "integer");
}

function decode_sampling(dynamic) {
  let $ = read_int(dynamic, "seed");
  if ($ instanceof Ok) {
    let seed = $[0];
    let $1 = read_int(dynamic, "sampleCount");
    if ($1 instanceof Ok) {
      let sample_count = $1[0];
      return new Ok(new $types.SamplingConfig(seed, sample_count));
    } else {
      return $1;
    }
  } else {
    return $;
  }
}

function decode_expression_comparison(dynamic) {
  let $ = read_string(dynamic, "type");
  if ($ instanceof Ok) {
    let kind = $[0];
    if (kind === "exact_expression") {
      let $1 = read_string(dynamic, "expected");
      if ($1 instanceof Ok) {
        let expected = $1[0];
        return new Ok(new $types.ExactExpression(expected));
      } else {
        return $1;
      }
    } else if (kind === "algebraic_equivalence") {
      let $1 = read_string(dynamic, "expected");
      if ($1 instanceof Ok) {
        let expected = $1[0];
        let $2 = read_dynamic(dynamic, "sampling");
        if ($2 instanceof Ok) {
          let sampling_dynamic = $2[0];
          let $3 = decode_sampling(sampling_dynamic);
          if ($3 instanceof Ok) {
            let sampling = $3[0];
            return new Ok(new $types.AlgebraicEquivalence(expected, sampling));
          } else {
            return $3;
          }
        } else {
          return $2;
        }
      } else {
        return $1;
      }
    } else {
      let other = kind;
      return new Error(
        new $types.UnknownDiscriminator("comparison.type", other),
      );
    }
  } else {
    return $;
  }
}

function decode_expression_spec(dynamic, version) {
  let $ = read_dynamic(dynamic, "comparison");
  if ($ instanceof Ok) {
    let comparison_dynamic = $[0];
    let $1 = decode_expression_comparison(comparison_dynamic);
    if ($1 instanceof Ok) {
      let comparison = $1[0];
      let $2 = read_dynamic(dynamic, "validation");
      if ($2 instanceof Ok) {
        let validation_dynamic = $2[0];
        let $3 = decode_expression_validation(validation_dynamic);
        if ($3 instanceof Ok) {
          let validation = $3[0];
          return new Ok(
            new $types.EqualitySpec(
              version,
              new $types.Expression(
                new $types.ExpressionSpec(comparison, validation),
              ),
            ),
          );
        } else {
          return $3;
        }
      } else {
        return $2;
      }
    } else {
      return $1;
    }
  } else {
    return $;
  }
}

function decimal_rule_from_string(rule) {
  if (rule === "exactly") {
    return new Ok(new $types.Exactly());
  } else if (rule === "at_least") {
    return new Ok(new $types.AtLeast());
  } else if (rule === "at_most") {
    return new Ok(new $types.AtMost());
  } else {
    let other = rule;
    return new Error(new $types.UnknownDiscriminator("precision.rule", other));
  }
}

function decode_decimal_places(dynamic) {
  let $ = read_string(dynamic, "rule");
  if ($ instanceof Ok) {
    let rule = $[0];
    let $1 = decimal_rule_from_string(rule);
    if ($1 instanceof Ok) {
      let decoded_rule = $1[0];
      let $2 = read_int(dynamic, "count");
      if ($2 instanceof Ok) {
        let count = $2[0];
        let $3 = count >= 0;
        if ($3) {
          return new Ok(new $types.DecimalPlaces(decoded_rule, count));
        } else {
          return new Error(
            new $types.InvalidField(
              "precision.count",
              "expected non-negative integer",
            ),
          );
        }
      } else {
        return $2;
      }
    } else {
      return $1;
    }
  } else {
    return $;
  }
}

function decode_precision(dynamic) {
  let $ = read_dynamic(dynamic, "precision");
  if ($ instanceof Ok) {
    let precision_dynamic = $[0];
    let $1 = read_string(precision_dynamic, "type");
    if ($1 instanceof Ok) {
      let kind = $1[0];
      if (kind === "none") {
        return new Ok(new $types.NoPrecision());
      } else if (kind === "legacy_significant_figures") {
        let $2 = read_int(precision_dynamic, "count");
        if ($2 instanceof Ok) {
          let count = $2[0];
          let $3 = count > 0;
          if ($3) {
            return new Ok(new $types.LegacySignificantFigures(count));
          } else {
            return new Error(
              new $types.InvalidField(
                "precision.count",
                "expected positive integer",
              ),
            );
          }
        } else {
          return $2;
        }
      } else if (kind === "decimal_places") {
        return decode_decimal_places(precision_dynamic);
      } else {
        let other = kind;
        return new Error(
          new $types.UnknownDiscriminator("precision.type", other),
        );
      }
    } else {
      return $1;
    }
  } else {
    return $;
  }
}

function decode_representation(dynamic) {
  let $ = read_dynamic(dynamic, "representation");
  if ($ instanceof Ok) {
    let representation_dynamic = $[0];
    let $1 = read_string(representation_dynamic, "type");
    if ($1 instanceof Ok) {
      let kind = $1[0];
      if (kind === "any") {
        return new Ok(new $types.AnyRepresentation());
      } else if (kind === "integer") {
        return new Ok(new $types.IntegerRepresentation());
      } else if (kind === "decimal") {
        return new Ok(new $types.DecimalRepresentation());
      } else if (kind === "scientific") {
        return new Ok(new $types.ScientificRepresentation());
      } else {
        let other = kind;
        return new Error(
          new $types.UnknownDiscriminator("representation.type", other),
        );
      }
    } else {
      return $1;
    }
  } else {
    return $;
  }
}

function decode_absolute_or_relative(dynamic) {
  let $ = read_float(dynamic, "absolute");
  if ($ instanceof Ok) {
    let absolute = $[0];
    let $1 = read_float(dynamic, "relative");
    if ($1 instanceof Ok) {
      let relative = $1[0];
      let $2 = (absolute >= 0.0) && (relative >= 0.0);
      if ($2) {
        return new Ok(
          new $types.AbsoluteOrRelativeTolerance(absolute, relative),
        );
      } else {
        return new Error(
          new $types.InvalidField(
            "tolerance",
            "expected non-negative float values",
          ),
        );
      }
    } else {
      return $1;
    }
  } else {
    return $;
  }
}

function decode_float_field(dynamic, field, constructor) {
  let $ = read_float(dynamic, field);
  if ($ instanceof Ok) {
    let value = $[0];
    let $1 = value >= 0.0;
    if ($1) {
      return new Ok(constructor(value));
    } else {
      return new Error(
        new $types.InvalidField(
          "tolerance." + field,
          "expected non-negative float",
        ),
      );
    }
  } else {
    return $;
  }
}

function decode_tolerance(dynamic) {
  let $ = read_dynamic(dynamic, "tolerance");
  if ($ instanceof Ok) {
    let tolerance_dynamic = $[0];
    let $1 = read_string(tolerance_dynamic, "type");
    if ($1 instanceof Ok) {
      let kind = $1[0];
      if (kind === "none") {
        return new Ok(new $types.NoTolerance());
      } else if (kind === "absolute") {
        return decode_float_field(
          tolerance_dynamic,
          "value",
          (var0) => { return new $types.AbsoluteTolerance(var0); },
        );
      } else if (kind === "relative") {
        return decode_float_field(
          tolerance_dynamic,
          "value",
          (var0) => { return new $types.RelativeTolerance(var0); },
        );
      } else if (kind === "absolute_or_relative") {
        return decode_absolute_or_relative(tolerance_dynamic);
      } else {
        let other = kind;
        return new Error(
          new $types.UnknownDiscriminator("tolerance.type", other),
        );
      }
    } else {
      return $1;
    }
  } else {
    return $;
  }
}

function bounds_from_string(bounds) {
  if (bounds === "inclusive") {
    return new Ok(new $types.Inclusive());
  } else if (bounds === "exclusive") {
    return new Ok(new $types.Exclusive());
  } else {
    let other = bounds;
    return new Error(
      new $types.UnknownDiscriminator("comparison.bounds", other),
    );
  }
}

function decode_range(dynamic, constructor) {
  let $ = read_string(dynamic, "lower");
  if ($ instanceof Ok) {
    let lower = $[0];
    let $1 = read_string(dynamic, "upper");
    if ($1 instanceof Ok) {
      let upper = $1[0];
      let $2 = read_string(dynamic, "bounds");
      if ($2 instanceof Ok) {
        let bounds = $2[0];
        let $3 = bounds_from_string(bounds);
        if ($3 instanceof Ok) {
          let decoded_bounds = $3[0];
          return new Ok(
            constructor(
              $types.numeric_input(lower),
              $types.numeric_input(upper),
              decoded_bounds,
            ),
          );
        } else {
          return $3;
        }
      } else {
        return $2;
      }
    } else {
      return $1;
    }
  } else {
    return $;
  }
}

function decode_threshold(dynamic, constructor) {
  let $ = read_string(dynamic, "threshold");
  if ($ instanceof Ok) {
    let raw = $[0];
    return new Ok(constructor($types.numeric_input(raw)));
  } else {
    return $;
  }
}

function decode_expected(dynamic, constructor) {
  let $ = read_string(dynamic, "expected");
  if ($ instanceof Ok) {
    let raw = $[0];
    return new Ok(constructor($types.numeric_input(raw)));
  } else {
    return $;
  }
}

function decode_numeric_comparison(dynamic) {
  let $ = read_string(dynamic, "type");
  if ($ instanceof Ok) {
    let kind = $[0];
    if (kind === "equal") {
      return decode_expected(
        dynamic,
        (var0) => { return new $types.Equal(var0); },
      );
    } else if (kind === "not_equal") {
      return decode_expected(
        dynamic,
        (var0) => { return new $types.NotEqual(var0); },
      );
    } else if (kind === "greater_than") {
      return decode_threshold(
        dynamic,
        (var0) => { return new $types.GreaterThan(var0); },
      );
    } else if (kind === "greater_than_or_equal") {
      return decode_threshold(
        dynamic,
        (var0) => { return new $types.GreaterThanOrEqual(var0); },
      );
    } else if (kind === "less_than") {
      return decode_threshold(
        dynamic,
        (var0) => { return new $types.LessThan(var0); },
      );
    } else if (kind === "less_than_or_equal") {
      return decode_threshold(
        dynamic,
        (var0) => { return new $types.LessThanOrEqual(var0); },
      );
    } else if (kind === "between") {
      return decode_range(
        dynamic,
        (var0, var1, var2) => { return new $types.Between(var0, var1, var2); },
      );
    } else if (kind === "not_between") {
      return decode_range(
        dynamic,
        (var0, var1, var2) => { return new $types.NotBetween(var0, var1, var2); },
      );
    } else {
      let other = kind;
      return new Error(
        new $types.UnknownDiscriminator("comparison.type", other),
      );
    }
  } else {
    return $;
  }
}

function decode_numeric_spec(dynamic, version) {
  let $ = read_dynamic(dynamic, "comparison");
  if ($ instanceof Ok) {
    let comparison_dynamic = $[0];
    let $1 = decode_numeric_comparison(comparison_dynamic);
    if ($1 instanceof Ok) {
      let comparison = $1[0];
      let $2 = decode_tolerance(dynamic);
      if ($2 instanceof Ok) {
        let tolerance = $2[0];
        let $3 = decode_representation(dynamic);
        if ($3 instanceof Ok) {
          let representation = $3[0];
          let $4 = decode_precision(dynamic);
          if ($4 instanceof Ok) {
            let precision = $4[0];
            return new Ok(
              new $types.EqualitySpec(
                version,
                new $types.Numeric(
                  new $types.NumericSpec(
                    comparison,
                    tolerance,
                    representation,
                    precision,
                  ),
                ),
              ),
            );
          } else {
            return $4;
          }
        } else {
          return $3;
        }
      } else {
        return $2;
      }
    } else {
      return $1;
    }
  } else {
    return $;
  }
}

function decode_supported_spec(dynamic, version) {
  let $ = read_string(dynamic, "mode");
  if ($ instanceof Ok) {
    let mode = $[0];
    if (mode === "numeric") {
      return decode_numeric_spec(dynamic, version);
    } else if (mode === "expression") {
      return decode_expression_spec(dynamic, version);
    } else if (mode === "unit_aware") {
      return decode_unit_spec(dynamic, version);
    } else {
      let other = mode;
      return new Error(new $types.UnknownDiscriminator("mode", other));
    }
  } else {
    return $;
  }
}

function default_version_probe(version) {
  return new $types.EqualitySpec(
    version,
    new $types.Numeric(
      $types.default_numeric_options(
        new $types.Equal($types.numeric_input("0")),
      ),
    ),
  );
}

function decode_spec(dynamic) {
  let $ = read_int(dynamic, "version");
  if ($ instanceof Ok) {
    let version = $[0];
    let $1 = $evaluate.validate_spec(default_version_probe(version));
    if ($1 instanceof Ok) {
      return decode_supported_spec(dynamic, version);
    } else {
      return $1;
    }
  } else {
    return $;
  }
}

/**
 * Decode the future `equalityConfig` JSON shape into the typed contract.
 * `gleam_json` owns JSON parsing here; this module owns only the Torus
 * equality-config semantics layered on top of that package.
 */
export function decode_equality_config(source) {
  let $ = $gleam_json.parse(source, $decode.dynamic);
  if ($ instanceof Ok) {
    let dynamic = $[0];
    return decode_spec(dynamic);
  } else {
    return new Error(new $types.InvalidJson("could not parse JSON"));
  }
}

function string_array(values) {
  return $gleam_json.array(values, $gleam_json.string);
}

function unit_policy_to_json(policy) {
  if (policy instanceof $types.UnitsIgnored) {
    return $gleam_json.object(toList([["type", $gleam_json.string("ignored")]]));
  } else if (policy instanceof $types.UnitsRequired) {
    return $gleam_json.object(
      toList([["type", $gleam_json.string("required")]]),
    );
  } else if (policy instanceof $types.AcceptedUnits) {
    let units = policy.units;
    return $gleam_json.object(
      toList([
        ["type", $gleam_json.string("accepted_units")],
        ["units", string_array(units)],
      ]),
    );
  } else if (policy instanceof $types.StrictUnit) {
    let unit = policy.unit;
    return $gleam_json.object(
      toList([
        ["type", $gleam_json.string("strict_unit")],
        ["unit", $gleam_json.string(unit)],
      ]),
    );
  } else {
    let units = policy.units;
    return $gleam_json.object(
      toList([
        ["type", $gleam_json.string("convertible_units")],
        ["units", string_array(units)],
      ]),
    );
  }
}

function numeric_to_json(input) {
  return $gleam_json.string(input.raw);
}

function unit_comparison_to_json(comparison) {
  if (comparison instanceof $types.UnitNumeric) {
    let expected_value = comparison.expected_value;
    let expected_unit = comparison.expected_unit;
    return $gleam_json.object(
      toList([
        ["type", $gleam_json.string("unit_numeric")],
        ["expectedValue", numeric_to_json(expected_value)],
        ["expectedUnit", $gleam_json.string(expected_unit)],
      ]),
    );
  } else {
    let expected_expression = comparison.expected_expression;
    let expected_unit = comparison.expected_unit;
    return $gleam_json.object(
      toList([
        ["type", $gleam_json.string("unit_expression")],
        ["expectedExpression", $gleam_json.string(expected_expression)],
        ["expectedUnit", $gleam_json.string(expected_unit)],
      ]),
    );
  }
}

function domain_to_json(domain) {
  return $gleam_json.object(
    toList([
      ["name", $gleam_json.string(domain.name)],
      ["lower", $gleam_json.float(domain.lower)],
      ["upper", $gleam_json.float(domain.upper)],
    ]),
  );
}

function json_array(values, encoder) {
  return $gleam_json.preprocessed_array($list.map(values, encoder));
}

function function_to_string(name) {
  if (name instanceof $ast.Sin) {
    return "sin";
  } else if (name instanceof $ast.Cos) {
    return "cos";
  } else if (name instanceof $ast.Tan) {
    return "tan";
  } else if (name instanceof $ast.Ln) {
    return "ln";
  } else if (name instanceof $ast.Log) {
    return "log";
  } else if (name instanceof $ast.Log10) {
    return "log10";
  } else if (name instanceof $ast.Log2) {
    return "log2";
  } else if (name instanceof $ast.Sqrt) {
    return "sqrt";
  } else if (name instanceof $ast.Abs) {
    return "abs";
  } else {
    return "exp";
  }
}

function expression_validation_to_json(validation) {
  return $gleam_json.object(
    toList([
      ["allowedVariables", string_array(validation.allowed_variables)],
      [
        "allowedFunctions",
        string_array(
          $list.map(validation.allowed_functions, function_to_string),
        ),
      ],
      ["domains", json_array(validation.domains, domain_to_json)],
    ]),
  );
}

function sampling_to_json(sampling) {
  return $gleam_json.object(
    toList([
      ["seed", $gleam_json.int(sampling.seed)],
      ["sampleCount", $gleam_json.int(sampling.sample_count)],
    ]),
  );
}

function expression_comparison_to_json(comparison) {
  if (comparison instanceof $types.ExactExpression) {
    let expected = comparison.expected;
    return $gleam_json.object(
      toList([
        ["type", $gleam_json.string("exact_expression")],
        ["expected", $gleam_json.string(expected)],
      ]),
    );
  } else {
    let expected = comparison.expected;
    let sampling = comparison.sampling;
    return $gleam_json.object(
      toList([
        ["type", $gleam_json.string("algebraic_equivalence")],
        ["expected", $gleam_json.string(expected)],
        ["sampling", sampling_to_json(sampling)],
      ]),
    );
  }
}

function decimal_rule_to_string(rule) {
  if (rule instanceof $types.Exactly) {
    return "exactly";
  } else if (rule instanceof $types.AtLeast) {
    return "at_least";
  } else {
    return "at_most";
  }
}

function precision_to_json(precision) {
  if (precision instanceof $types.NoPrecision) {
    return $gleam_json.object(toList([["type", $gleam_json.string("none")]]));
  } else if (precision instanceof $types.LegacySignificantFigures) {
    let count = precision.count;
    return $gleam_json.object(
      toList([
        ["type", $gleam_json.string("legacy_significant_figures")],
        ["count", $gleam_json.int(count)],
      ]),
    );
  } else {
    let rule = precision.rule;
    let count = precision.count;
    return $gleam_json.object(
      toList([
        ["type", $gleam_json.string("decimal_places")],
        ["rule", $gleam_json.string(decimal_rule_to_string(rule))],
        ["count", $gleam_json.int(count)],
      ]),
    );
  }
}

function representation_to_json(representation) {
  if (representation instanceof $types.AnyRepresentation) {
    return $gleam_json.object(toList([["type", $gleam_json.string("any")]]));
  } else if (representation instanceof $types.IntegerRepresentation) {
    return $gleam_json.object(toList([["type", $gleam_json.string("integer")]]));
  } else if (representation instanceof $types.DecimalRepresentation) {
    return $gleam_json.object(toList([["type", $gleam_json.string("decimal")]]));
  } else {
    return $gleam_json.object(
      toList([["type", $gleam_json.string("scientific")]]),
    );
  }
}

function tolerance_to_json(tolerance) {
  if (tolerance instanceof $types.NoTolerance) {
    return $gleam_json.object(toList([["type", $gleam_json.string("none")]]));
  } else if (tolerance instanceof $types.AbsoluteTolerance) {
    let value = tolerance.value;
    return $gleam_json.object(
      toList([
        ["type", $gleam_json.string("absolute")],
        ["value", $gleam_json.float(value)],
      ]),
    );
  } else if (tolerance instanceof $types.RelativeTolerance) {
    let value = tolerance.value;
    return $gleam_json.object(
      toList([
        ["type", $gleam_json.string("relative")],
        ["value", $gleam_json.float(value)],
      ]),
    );
  } else {
    let absolute = tolerance.absolute;
    let relative = tolerance.relative;
    return $gleam_json.object(
      toList([
        ["type", $gleam_json.string("absolute_or_relative")],
        ["absolute", $gleam_json.float(absolute)],
        ["relative", $gleam_json.float(relative)],
      ]),
    );
  }
}

function bounds_to_string(bounds) {
  if (bounds instanceof $types.Inclusive) {
    return "inclusive";
  } else {
    return "exclusive";
  }
}

function range_json(kind, lower, upper, bounds) {
  return $gleam_json.object(
    toList([
      ["type", $gleam_json.string(kind)],
      ["lower", numeric_to_json(lower)],
      ["upper", numeric_to_json(upper)],
      ["bounds", $gleam_json.string(bounds_to_string(bounds))],
    ]),
  );
}

function numeric_comparison_to_json(comparison) {
  if (comparison instanceof $types.Equal) {
    let expected = comparison.expected;
    return $gleam_json.object(
      toList([
        ["type", $gleam_json.string("equal")],
        ["expected", numeric_to_json(expected)],
      ]),
    );
  } else if (comparison instanceof $types.NotEqual) {
    let expected = comparison.expected;
    return $gleam_json.object(
      toList([
        ["type", $gleam_json.string("not_equal")],
        ["expected", numeric_to_json(expected)],
      ]),
    );
  } else if (comparison instanceof $types.GreaterThan) {
    let threshold = comparison.threshold;
    return $gleam_json.object(
      toList([
        ["type", $gleam_json.string("greater_than")],
        ["threshold", numeric_to_json(threshold)],
      ]),
    );
  } else if (comparison instanceof $types.GreaterThanOrEqual) {
    let threshold = comparison.threshold;
    return $gleam_json.object(
      toList([
        ["type", $gleam_json.string("greater_than_or_equal")],
        ["threshold", numeric_to_json(threshold)],
      ]),
    );
  } else if (comparison instanceof $types.LessThan) {
    let threshold = comparison.threshold;
    return $gleam_json.object(
      toList([
        ["type", $gleam_json.string("less_than")],
        ["threshold", numeric_to_json(threshold)],
      ]),
    );
  } else if (comparison instanceof $types.LessThanOrEqual) {
    let threshold = comparison.threshold;
    return $gleam_json.object(
      toList([
        ["type", $gleam_json.string("less_than_or_equal")],
        ["threshold", numeric_to_json(threshold)],
      ]),
    );
  } else if (comparison instanceof $types.Between) {
    let lower = comparison.lower;
    let upper = comparison.upper;
    let bounds = comparison.bounds;
    return range_json("between", lower, upper, bounds);
  } else {
    let lower = comparison.lower;
    let upper = comparison.upper;
    let bounds = comparison.bounds;
    return range_json("not_between", lower, upper, bounds);
  }
}

function spec_to_json(spec) {
  let $ = spec.mode;
  if ($ instanceof $types.Numeric) {
    let numeric = $[0];
    return $gleam_json.object(
      toList([
        ["version", $gleam_json.int(spec.version)],
        ["mode", $gleam_json.string("numeric")],
        ["comparison", numeric_comparison_to_json(numeric.comparison)],
        ["tolerance", tolerance_to_json(numeric.tolerance)],
        ["representation", representation_to_json(numeric.representation)],
        ["precision", precision_to_json(numeric.precision)],
      ]),
    );
  } else if ($ instanceof $types.Expression) {
    let expression = $[0];
    return $gleam_json.object(
      toList([
        ["version", $gleam_json.int(spec.version)],
        ["mode", $gleam_json.string("expression")],
        ["comparison", expression_comparison_to_json(expression.comparison)],
        ["validation", expression_validation_to_json(expression.validation)],
      ]),
    );
  } else {
    let unit = $[0];
    return $gleam_json.object(
      toList([
        ["version", $gleam_json.int(spec.version)],
        ["mode", $gleam_json.string("unit_aware")],
        ["comparison", unit_comparison_to_json(unit.comparison)],
        ["policy", unit_policy_to_json(unit.policy)],
      ]),
    );
  }
}

/**
 * Encode the typed equality config into the stable JSON field names that later
 * Response storage and cross-target fixtures will treat as the public contract.
 */
export function encode_equality_config(spec) {
  let _pipe = spec_to_json(spec);
  return $gleam_json.to_string(_pipe);
}
