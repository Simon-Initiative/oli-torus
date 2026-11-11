defmodule Oli.Accounts.ProtectedKeys do
  @moduledoc """
  Rejects account attributes that only audited commands may write.

  The generic account updates (`Oli.Accounts.update_user/2`, `Oli.Accounts.update_author/2`) and
  the narrow audited commands accept a fixed set of fields. Any other field of the schema in the
  submitted attributes adds a `:protected` error, so a caller that passes it fails visibly instead
  of having it silently dropped. Keys that are not schema fields (such as form bookkeeping keys)
  are ignored, as `Ecto.Changeset.cast/3` ignores them.
  """

  import Ecto.Changeset, only: [add_error: 4]

  @doc """
  Adds a `:protected` error to `changeset` for every schema field in `attrs` outside `allowed`.
  """
  @spec validate(Ecto.Changeset.t(), map(), [atom()]) :: Ecto.Changeset.t()
  def validate(%Ecto.Changeset{data: %schema{}} = changeset, attrs, allowed) when is_map(attrs) do
    allowed = MapSet.new(allowed, &Atom.to_string/1)

    attrs
    |> Map.keys()
    |> Enum.map(&to_string/1)
    |> Enum.filter(&(&1 in schema_keys(schema) and not MapSet.member?(allowed, &1)))
    |> Enum.uniq()
    |> Enum.reduce(changeset, fn key, changeset ->
      add_error(changeset, String.to_existing_atom(key), "cannot be changed here",
        validation: :protected
      )
    end)
  end

  @doc "Returns true when `changeset` has an error added by `validate/3`."
  @spec protected?(Ecto.Changeset.t()) :: boolean()
  def protected?(%Ecto.Changeset{errors: errors}) do
    Enum.any?(errors, fn {_field, {_message, meta}} -> meta[:validation] == :protected end)
  end

  defp schema_keys(schema) do
    [:fields, :virtual_fields, :associations, :embeds]
    |> Enum.flat_map(&schema.__schema__/1)
    |> Enum.map(&Atom.to_string/1)
  end
end
