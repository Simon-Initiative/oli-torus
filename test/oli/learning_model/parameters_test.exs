defmodule Oli.LearningModel.ParametersTest do
  use ExUnit.Case, async: true

  alias Oli.LearningModel.Parameters
  alias Oli.LearningModel.Parameters.Type

  alias Oli.LearningModel.V2.{
    ActivityParameters,
    LearningObjectiveParameters,
    PartParameters
  }

  test "decodes and canonically encodes learning-objective parameters" do
    source = %{
      "schema_version" => 1,
      "model" => "lkt_aoa",
      "model_version" => 2,
      "parameter_type" => "learning_objective",
      "payload" => %{"beta_lo" => -0.42}
    }

    assert {:ok,
            %Parameters{
              schema_version: 1,
              model: :lkt_aoa,
              model_version: 2,
              parameter_type: :learning_objective,
              payload: %LearningObjectiveParameters{beta_lo: -0.42}
            } = decoded} = Parameters.decode(source)

    assert Parameters.encode(decoded) == {:ok, source}
  end

  test "decodes activity parameters by string part ID and normalizes integers" do
    source = %{
      schema_version: 1,
      model: :lkt_aoa,
      model_version: 2,
      parameter_type: :activity,
      payload: %{
        parts: %{
          "part-1" => %{beta_difficulty: 0},
          "part-2" => %PartParameters{beta_difficulty: 2}
        }
      }
    }

    assert {:ok,
            %Parameters{
              parameter_type: :activity,
              payload: %ActivityParameters{parts: parts}
            }} = Parameters.decode(source)

    assert parts["part-1"].beta_difficulty == 0.0
    assert parts["part-2"].beta_difficulty == 2.0
  end

  test "keeps missing parameters distinct from an explicitly trained zero" do
    assert Parameters.decode(nil) == {:ok, nil}
    assert Parameters.encode(nil) == {:ok, nil}

    parameters = %Parameters{
      schema_version: 1,
      model: :lkt_aoa,
      model_version: 2,
      parameter_type: :learning_objective,
      payload: %LearningObjectiveParameters{beta_lo: 0.0}
    }

    assert {:ok, %Parameters{payload: %LearningObjectiveParameters{beta_lo: beta_lo}}} =
             Parameters.decode(parameters)

    assert beta_lo == 0.0
  end

  test "the Ecto type casts, loads, and dumps typed values" do
    source = %{
      "schema_version" => 1,
      "model" => "lkt_aoa",
      "model_version" => 2,
      "parameter_type" => "activity",
      "payload" => %{
        "parts" => %{"part-1" => %{"beta_difficulty" => -0.18}}
      }
    }

    assert {:ok, %Parameters{} = typed} = Type.cast(source)
    assert {:ok, ^typed} = Type.load(source)
    assert {:ok, ^source} = Type.dump(typed)
    assert {:ok, nil} = Type.cast(nil)
    assert {:ok, nil} = Type.load(nil)
    assert {:ok, nil} = Type.dump(nil)
  end

  test "the Ecto type round-trips learning-objective parameters" do
    source = %{
      "schema_version" => 1,
      "model" => "lkt_aoa",
      "model_version" => 2,
      "parameter_type" => "learning_objective",
      "payload" => %{"beta_lo" => -0.42}
    }

    assert {:ok, %Parameters{} = typed} = Type.cast(source)
    assert {:ok, ^typed} = Type.load(source)
    assert {:ok, ^source} = Type.dump(typed)
  end

  test "rejects unsupported envelope dispatch values" do
    base = %{
      "schema_version" => 1,
      "model" => "lkt_aoa",
      "model_version" => 2,
      "parameter_type" => "learning_objective",
      "payload" => %{"beta_lo" => 0.5}
    }

    assert Parameters.decode(%{base | "schema_version" => 3}) ==
             {:error, {:unsupported_schema_version, 3}}

    assert Parameters.decode(%{base | "model" => "other"}) ==
             {:error, {:unsupported_model, "other"}}

    assert Parameters.decode(%{base | "model_version" => 3}) ==
             {:error, {:unsupported_model_version, 3}}

    assert Parameters.decode(%{base | "parameter_type" => "page"}) ==
             {:error, {:unsupported_parameter_type, "page"}}

    assert Type.cast(%{base | "model_version" => 3}) == :error
    assert Type.load(%{base | "schema_version" => 3}) == :error
  end

  test "rejects malformed payloads and non-numeric coefficients" do
    lo = %{
      "schema_version" => 1,
      "model" => "lkt_aoa",
      "model_version" => 2,
      "parameter_type" => "learning_objective",
      "payload" => %{"beta_lo" => "NaN"}
    }

    activity = %{
      "schema_version" => 1,
      "model" => "lkt_aoa",
      "model_version" => 2,
      "parameter_type" => "activity",
      "payload" => %{"parts" => %{12 => %{"beta_difficulty" => 0.1}}}
    }

    assert Parameters.decode(lo) == {:error, {:invalid_finite_number, :beta_lo}}
    assert Parameters.decode(activity) == {:error, {:invalid_part_id, 12}}
    assert Type.dump(%{lo | "payload" => %{}}) == :error
  end

  test "rejects integers too large for a finite float without raising" do
    oversized_integer = Integer.pow(10, 10_000)

    learning_objective = %{
      schema_version: 1,
      model: :lkt_aoa,
      model_version: 2,
      parameter_type: :learning_objective,
      payload: %{beta_lo: oversized_integer}
    }

    activity = %{
      schema_version: 1,
      model: :lkt_aoa,
      model_version: 2,
      parameter_type: :activity,
      payload: %{parts: %{"part-1" => %{beta_difficulty: oversized_integer}}}
    }

    assert Parameters.decode(learning_objective) ==
             {:error, {:invalid_finite_number, :beta_lo}}

    assert Parameters.decode(activity) ==
             {:error, {:invalid_finite_number, {:beta_difficulty, "part-1"}}}

    assert Type.cast(learning_objective) == :error
    assert Type.load(activity) == :error
  end

  test "requires all envelope and payload fields" do
    assert Parameters.decode(%{}) == {:error, {:missing_parameter_field, :schema_version}}

    assert Parameters.decode(%{
             schema_version: 1,
             model: :lkt_aoa,
             model_version: 2,
             parameter_type: :activity,
             payload: %{}
           }) == {:error, {:missing_parameter_field, :parts}}
  end
end
