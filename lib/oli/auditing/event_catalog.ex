defmodule Oli.Auditing.EventCatalog do
  @moduledoc """
  Compile-time registry of every audit event type and its contract.

  The catalog is the single source for the event names accepted by `Oli.Auditing.LogEvent`,
  their families, display labels, and descriptions. None of this is stored in the database:
  rows store only `event_type`, and everything else is resolved from this module.

  Definitions live in `Oli.Auditing.EventCatalog.Definitions`; see its moduledoc for the
  evolution rules.
  """

  alias Oli.Auditing.EventCatalog.{Contract, Definitions, Validation}

  @external_resource Path.join(__DIR__, "event_catalog/definitions.ex")

  @families Definitions.families()

  @contracts (for {family, _label, defaults, events} <- @families,
                  {name, label, description, overrides} <- events do
                attrs =
                  Definitions.base_defaults()
                  |> Keyword.merge(defaults)
                  |> Keyword.merge(overrides)
                  |> Keyword.merge(
                    name: name,
                    family: family,
                    label: label,
                    description: description
                  )

                struct!(Contract, attrs)
              end)

  @names Enum.map(@contracts, & &1.name)
  @by_name Map.new(@contracts, &{&1.name, &1})
  @by_string Map.new(@names, &{Atom.to_string(&1), &1})
  @family_labels Map.new(@families, fn {family, label, _defaults, _events} -> {family, label} end)
  @family_order Enum.map(@families, &elem(&1, 0))

  if length(@names) != length(Enum.uniq(@names)) do
    raise CompileError, description: "duplicate audit event names in the catalog"
  end

  @doc "Returns every event name, in catalog order."
  @spec names() :: [atom()]
  def names, do: @names

  @doc "Returns every contract, in catalog order."
  @spec contracts() :: [Contract.t()]
  def contracts, do: @contracts

  @doc "Returns the contract of an event name."
  @spec fetch(atom()) :: {:ok, Contract.t()} | :error
  def fetch(name), do: Map.fetch(@by_name, name)

  @doc "Returns the contract of an event name, raising for unknown names."
  @spec contract!(atom()) :: Contract.t()
  def contract!(name), do: Map.fetch!(@by_name, name)

  @doc "Returns the families, in catalog order."
  @spec families() :: [atom()]
  def families, do: @family_order

  @doc "Returns the display label of a family."
  @spec family_label(atom()) :: String.t()
  def family_label(family), do: Map.fetch!(@family_labels, family)

  @doc "Returns the event names of a family."
  @spec family_events(atom()) :: [atom()]
  def family_events(family),
    do: for(%Contract{family: ^family, name: name} <- @contracts, do: name)

  @doc """
  Returns the display label of an event name, falling back to a humanized name for values the
  catalog does not know (for example, rows read by an older binary).
  """
  @spec label(atom() | String.t()) :: String.t()
  def label(name) when is_atom(name) do
    case fetch(name) do
      {:ok, contract} -> contract.label
      :error -> humanize(name)
    end
  end

  def label(name) when is_binary(name) do
    case cast_name(name) do
      {:ok, atom} -> label(atom)
      :error -> humanize(name)
    end
  end

  @doc "Casts a stored event name to its catalog atom without creating atoms."
  @spec cast_name(atom() | String.t()) :: {:ok, atom()} | :error
  def cast_name(name) when is_atom(name) and is_map_key(@by_name, name), do: {:ok, name}
  def cast_name(name) when is_binary(name), do: Map.fetch(@by_string, name)
  def cast_name(_name), do: :error

  @doc "Validates a version 2 row against its contract. See `Validation.validate/1`."
  @spec validate(map()) :: :ok | {:error, :no_changes | [Validation.error()]}
  def validate(attrs), do: Validation.validate(attrs)

  defp humanize(name), do: name |> to_string() |> String.replace("_", " ") |> String.capitalize()
end
