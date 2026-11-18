defmodule Oli.Validation.PageDomain do
  @moduledoc """
  Standalone domain validation for schema-valid Basic Page content.

  Indexes IDs and typed resource references before making a single bulk resolution
  call. The caller supplies a scoped resolver; this module has no database access.
  Diagnostics use the same bounded JSON Pointer format as activity validation.
  """
  alias Oli.Validation.ActivityDomain.{Issue, Limits}
  alias Oli.Validation.PageDomain.Index

  @types ~w(page container activity objective secondary tag bibentry alternatives)
  @type resolver :: ([pos_integer()] -> {:ok, %{pos_integer() => String.t()}} | {:error, term()})

  @doc """
  Validates IDs, bank logic/counts, and typed resource references without mutation.

  `resolve` receives sorted distinct positive resource IDs exactly once (zero calls
  for an empty batch). It returns `{:ok, %{id => "activity" | "tag" | ...}}`;
  omitted IDs mean missing, deleted, or inaccessible resources. Resolver failures
  fail closed with `resource_resolution_failed`, without exposing internal errors.
  All occurrences retain their source paths, including repeated references.

  Run JSON Schema validation separately first. Adaptive pages are unsupported.
  IDs in every object in the content model, including extension data, are checked.
  At most 100 issues are returned; the complete reference batch is still resolved.
  """
  @spec validate(term(), resolver()) :: :ok | {:error, [Issue.t()]}
  def validate(content, resolve) when is_function(resolve, 1) do
    with :ok <- check_limits(content),
         :ok <- shape(content) do
      state = Index.collect(content)
      refs = Enum.reverse(state.references)
      ids = refs |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> Enum.sort()

      state =
        case resolve(ids, resolve) do
          {:ok, resources} ->
            Enum.reduce(refs, state, &check_reference(&1, &2, resources))

          :error ->
            Index.issue(state, "resource_resolution_failed", [], "Resource resolution failed")
        end

      case Enum.reverse(state.issues) do
        [] -> :ok
        issues -> {:error, issues}
      end
    end
  end

  def validate(_, _),
    do: {:error, [Issue.new("invalid_resolver", [], "A bulk resource resolver is required")]}

  defp check_limits(content) do
    case Limits.check(content) do
      :ok ->
        :ok

      {:error, issues} ->
        {:error,
         Enum.map(
           issues,
           &%{&1 | message: "Page content exceeds JSON size, depth, or node limits"}
         )}
    end
  end

  defp shape(%{"advancedAuthoring" => true}), do: unsupported()
  defp shape(%{"advancedDelivery" => true}), do: unsupported()
  defp shape(%{"model" => model}) when is_list(model), do: :ok

  defp shape(_),
    do:
      {:error, [Issue.new("invalid_input_shape", [], "Expected schema-valid Basic Page content")]}

  defp unsupported,
    do:
      {:error,
       [Issue.new("unsupported_page_type", [], "Adaptive page domain validation is unsupported")]}

  defp resolve([], _), do: {:ok, %{}}

  defp resolve(ids, resolver) do
    case resolver.(ids) do
      {:ok, resources} when is_map(resources) ->
        case Enum.all?(resources, fn {id, type} ->
               is_integer(id) and id > 0 and type in @types
             end) do
          true -> {:ok, resources}
          false -> :error
        end

      _ ->
        :error
    end
  rescue
    _ -> :error
  end

  defp check_reference({id, expected, path}, state, resources) do
    case Map.fetch(resources, id) do
      :error ->
        Index.issue(
          state,
          "missing_resource",
          path,
          "Referenced #{expected} is missing or inaccessible"
        )

      {:ok, ^expected} ->
        state

      {:ok, _} ->
        Index.issue(
          state,
          "resource_type_mismatch",
          path,
          "Referenced resource must be a #{expected}"
        )
    end
  end
end
