defmodule Oli.Seeding.Runtime do
  @moduledoc """
  Boots the dedicated companion runtime used by development and preview seeding commands.

  The role starts persistence, evaluation support, distributed cache coordination, and
  job production without starting the HTTP endpoint, normal job consumers, upload
  pipelines, or application boot-recovery work.
  """

  @role_key :application_role

  @doc "Runs a seeding function inside the dedicated application role."
  @spec run((-> result)) :: result when result: term()
  def run(fun) when is_function(fun, 0) do
    already_started? = application_started?()
    previous_role = Application.get_env(:oli, @role_key)
    Application.put_env(:oli, @role_key, :seeding)

    try do
      with {:ok, _applications} <- Application.ensure_all_started(:oli) do
        fun.()
      else
        {:error, reason} -> raise "could not start seeding runtime (#{failure_category(reason)})"
      end
    after
      restore_role(previous_role)

      case already_started? do
        true -> :ok
        false -> Application.stop(:oli)
      end
    end
  end

  @doc "Boots the seeding role and delegates command-line arguments to the shared CLI."
  @spec main([String.t()]) :: no_return()
  def main(args) do
    run(fn -> Oli.Seeding.CLI.main(args) end)
  end

  defp application_started? do
    Enum.any?(Application.started_applications(), fn {application, _description, _version} ->
      application == :oli
    end)
  end

  defp restore_role(nil), do: Application.delete_env(:oli, @role_key)
  defp restore_role(role), do: Application.put_env(:oli, @role_key, role)

  defp failure_category(reason) when is_atom(reason), do: Atom.to_string(reason)

  defp failure_category(reason) when is_tuple(reason) do
    case Tuple.to_list(reason) do
      [tag | _] when is_atom(tag) -> Atom.to_string(tag)
      _ -> "runtime_error"
    end
  end

  defp failure_category(%{__struct__: module}), do: module |> Module.split() |> List.last()
  defp failure_category(_reason), do: "runtime_error"
end
