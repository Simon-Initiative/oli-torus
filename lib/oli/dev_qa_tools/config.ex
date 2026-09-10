defmodule Oli.DevQATools.Config do
  @moduledoc """
  Defines the compile-time and runtime activation boundary for preview QA tools.

  A runtime flag can activate QA tools only when the application was compiled
  with the immutable preview build marker.
  """

  require Logger

  @preview_build Application.compile_env(:oli, [:dev_qa_tools, :preview_build?], false)
  @enabled_value "true"
  @runtime_flag "DEV_QA_TOOLS_ENABLED"

  @doc "Returns whether this artifact was compiled as a preview build."
  def preview_build?, do: @preview_build

  @doc "Returns whether QA tools are effectively enabled for the current process."
  def enabled? do
    enabled?(@preview_build, System.get_env(@runtime_flag))
  end

  @doc false
  def enabled?(preview_build?, runtime_value) do
    preview_build? and enabled_runtime_value?(runtime_value)
  end

  @doc false
  def enabled_runtime_value?(runtime_value) when is_binary(runtime_value) do
    String.downcase(runtime_value) == @enabled_value
  end

  def enabled_runtime_value?(_runtime_value), do: false

  @doc "Logs the bounded preview QA-tools startup status once when invoked at startup."
  def log_startup_status do
    log_startup_status(@preview_build, System.get_env(@runtime_flag))
  end

  @doc false
  def log_startup_status(false, _runtime_value), do: :ok

  def log_startup_status(true, runtime_value) do
    if enabled?(true, runtime_value) do
      Logger.warning("Preview QA tools are enabled")
    else
      Logger.warning(
        "Preview QA tools are disabled; set DEV_QA_TOOLS_ENABLED=true to enable them"
      )
    end

    :ok
  end
end
