defmodule Mix.Tasks.Oli.BenchmarkMcqSchemaTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Oli.BenchmarkMcqSchema

  test "benchmarks the cached public API and malformed-content error path" do
    report =
      capture_io(fn ->
        BenchmarkMcqSchema.run([
          "test/support/fixtures/multiple_choice_model.json",
          "--iterations",
          "3"
        ])
      end)
      |> Jason.decode!()

    assert report["iterations"] == 3
    assert report["model_bytes"] > 0
    assert is_integer(report["cold_build_us"])

    for kind <- ["valid", "invalid"] do
      assert is_number(report[kind]["mean_us"])
      assert report[kind]["reductions_per_validation"] > 0
    end
  end

  test "requires a file and positive iteration count" do
    assert_raise Mix.Error, fn -> BenchmarkMcqSchema.run([]) end
    assert_raise Mix.Error, fn -> BenchmarkMcqSchema.run(["unused", "--iterations", "0"]) end
  end
end
