defmodule Oli.LearningModel.ConfigTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Oli.LearningModel.Config

  test "loads documented defaults without environment overrides" do
    assert {config, sources} = Config.load_from_env!(fn _name -> nil end)
    assert config == Config.defaults()

    assert sources == %{
             gamma: :default,
             rho: :default,
             recency_decay: :default,
             confidence_saturation: :default
           }
  end

  test "loads all environment overrides through an injectable reader" do
    overrides = %{
      "LKT_AOA_GAMMA" => " 0.25 ",
      "LKT_AOA_RHO" => "1.5",
      "LKT_AOA_RECENCY_DECAY" => "0.75",
      "LKT_AOA_CONFIDENCE_SATURATION" => "4"
    }

    assert {%Config{
              gamma: 0.25,
              rho: 1.5,
              recency_decay: 0.75,
              confidence_saturation: 4.0
            }, sources} = Config.load_from_env!(&Map.get(overrides, &1))

    assert Enum.all?(sources, fn {_key, source} -> source == :override end)
  end

  test "uses defaults only for absent individual variables" do
    assert {%Config{gamma: 0.2, rho: 1.0}, %{gamma: :override, rho: :default}} =
             Config.load_from_env!(fn
               "LKT_AOA_GAMMA" -> "0.2"
               _name -> nil
             end)
  end

  test "preserves application-owned base values when environment overrides are absent" do
    base = [gamma: 0.3, rho: 1.4, recency_decay: 0.8, confidence_saturation: 5.0]

    assert {%Config{gamma: 0.3, rho: 1.4, recency_decay: 0.8, confidence_saturation: 5.0},
            sources} = Config.load_from_env!(base, fn _name -> nil end)

    assert Enum.all?(sources, fn {_key, source} -> source == :default end)
  end

  test "rejects malformed and partially parsed overrides with the variable name" do
    for invalid <- ["not-a-number", "1.0 trailing", "NaN", "Infinity"] do
      error =
        assert_raise ArgumentError, fn ->
          Config.load_from_env!(fn
            "LKT_AOA_GAMMA" -> invalid
            _name -> nil
          end)
        end

      assert error.message =~ "LKT_AOA_GAMMA"
      refute error.message =~ "LKT_AOA_RHO"
    end
  end

  test "enforces the documented value ranges" do
    invalid_values = [
      {"LKT_AOA_GAMMA", "-0.1"},
      {"LKT_AOA_RHO", "-0.1"},
      {"LKT_AOA_RECENCY_DECAY", "0"},
      {"LKT_AOA_RECENCY_DECAY", "1.01"},
      {"LKT_AOA_CONFIDENCE_SATURATION", "0"}
    ]

    for {invalid_name, invalid_value} <- invalid_values do
      error =
        assert_raise ArgumentError, fn ->
          Config.load_from_env!(fn
            ^invalid_name -> invalid_value
            _name -> nil
          end)
        end

      assert error.message =~ invalid_name
    end

    assert {%Config{gamma: gamma, rho: rho, recency_decay: 1.0}, _sources} =
             Config.load_from_env!(fn
               "LKT_AOA_GAMMA" -> "0"
               "LKT_AOA_RHO" -> "0"
               "LKT_AOA_RECENCY_DECAY" -> "1"
               _name -> nil
             end)

    assert gamma == 0.0
    assert rho == 0.0
  end

  test "fetches and validates the application-owned configuration" do
    original = Application.fetch_env(:oli, :lkt_aoa)

    on_exit(fn ->
      case original do
        {:ok, value} -> Application.put_env(:oli, :lkt_aoa, value)
        :error -> Application.delete_env(:oli, :lkt_aoa)
      end
    end)

    Application.put_env(:oli, :lkt_aoa,
      gamma: 0.2,
      rho: 1.2,
      recency_decay: 0.8,
      confidence_saturation: 4.0
    )

    assert Config.fetch!() == %Config{
             gamma: 0.2,
             rho: 1.2,
             recency_decay: 0.8,
             confidence_saturation: 4.0
           }
  end

  test "logs only bounded effective configuration and source information" do
    {config, sources} = Config.load_from_env!(fn _name -> nil end)
    original_level = Logger.level()

    log =
      try do
        Logger.configure(level: :info)
        capture_log([level: :info], fn -> Config.log_effective(config, sources) end)
      after
        Logger.configure(level: original_level)
      end

    assert log =~ "Loaded LKT-AOA configuration"
    assert log =~ "gamma=0.1 (default)"
    assert log =~ "confidence_saturation=3.0 (default)"
    refute log =~ "LKT_AOA_GAMMA"
  end

  test "runtime configuration applies defaults and environment overrides" do
    assert {default_output, 0} = read_runtime_config()
    assert default_output =~ "gamma: 0.1"
    assert default_output =~ "recency_decay: 0.9"

    assert {override_output, 0} = read_runtime_config(%{"LKT_AOA_GAMMA" => "0.35"})
    assert override_output =~ "gamma: 0.35"
    assert override_output =~ "rho: 1.0"
  end

  test "runtime configuration rejects malformed environment overrides at startup" do
    assert {output, exit_status} = read_runtime_config(%{"LKT_AOA_RHO" => "invalid"})
    assert exit_status != 0
    assert output =~ "LKT_AOA_RHO"
    assert output =~ "must be a finite number"
  end

  defp read_runtime_config(overrides \\ %{}) do
    executable = System.find_executable("elixir") || raise "elixir executable not found"

    code_path_arguments =
      Enum.flat_map(:code.get_path(), fn path -> ["-pa", List.to_string(path)] end)

    script = ~S'''
    runtime_config = Config.Reader.read!(Path.expand("config/runtime.exs"), env: :test)
    IO.inspect(get_in(runtime_config, [:oli, :lkt_aoa]), label: "LKT_AOA_RESULT")
    '''

    cleared_environment =
      Enum.map(
        [
          "LKT_AOA_GAMMA",
          "LKT_AOA_RHO",
          "LKT_AOA_RECENCY_DECAY",
          "LKT_AOA_CONFIDENCE_SATURATION"
        ],
        &{&1, nil}
      )

    override_environment = Enum.map(overrides, fn {name, value} -> {name, value} end)

    System.cmd(executable, code_path_arguments ++ ["-e", script],
      env: cleared_environment ++ override_environment,
      stderr_to_stdout: true
    )
  end
end
