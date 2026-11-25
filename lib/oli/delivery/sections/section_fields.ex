defmodule Oli.Delivery.Sections.SectionFields do
  @moduledoc """
  Classifies every column of `Oli.Delivery.Sections.Section` by who may write it, using the
  field policies of `Oli.Auditing.EventCatalog.Fields`:

    * `audited/0` - settings recorded in the Audit Log; written only by the commands of
      `Oli.Delivery.Sections.Audited`.
    * `open/0` - payment, pricing, and certificate settings, still written by
      `Oli.Delivery.Sections.update_section/2` until their commands exist.
    * `lms_supplied/0` - LTI service fields that mirror the LMS; written only by
      `Oli.Delivery.Sections.sync_lti_services/2` on launch.
    * `system_derived/0` - indexes, version markers, content flags, and identity fields fixed
      at creation; written by the system through `update_section/2` or on creation.

  The sets are disjoint and cover every column; a test fails when a new column is in none.
  """

  alias Oli.Auditing.EventCatalog.Fields
  alias Oli.Delivery.Sections.Section

  @columns Section.__schema__(:fields)

  @derived_flags [:contains_explorations, :contains_deliberate_practice]

  @lms_supplied [
    :grade_passback_enabled,
    :line_items_service_url,
    :nrps_enabled,
    :nrps_context_memberships_url
  ]

  @doc "Columns written only by the audited section commands."
  @spec audited() :: [atom()]
  def audited do
    [
      Fields.section_settings(),
      Fields.dot_activation(),
      Fields.publication(),
      Fields.support_configuration()
    ]
    |> Enum.flat_map(&Map.keys/1)
    |> Enum.filter(&(&1 in @columns))
    |> Enum.reject(&(&1 in @derived_flags))
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Payment, pricing, and certificate columns, not yet written by an audited command. Policy
  fields that share a name with an audited section setting (the certificate's `title` and
  `description`) stay audited.
  """
  @spec open() :: [atom()]
  def open do
    [Fields.payment_settings(), Fields.pricing(), Fields.certificate_settings()]
    |> Enum.flat_map(&Map.keys/1)
    |> Enum.filter(&(&1 in @columns))
    |> Kernel.--(audited())
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc "LTI service columns that mirror the LMS and are written only on launch."
  @spec lms_supplied() :: [atom()]
  def lms_supplied, do: @lms_supplied

  @doc """
  Columns the system derives or fixes at creation: the fields `Fields` excludes from every
  policy for `Section`, plus the content flags that post-processing recomputes.
  """
  @spec system_derived() :: [atom()]
  def system_derived do
    Fields.schema_sources()
    |> Enum.find(&(&1.schema == Section))
    |> Map.fetch!(:excluded)
    |> Map.keys()
    |> Kernel.++(@derived_flags)
    |> Enum.sort()
  end

  @doc "The columns `Oli.Delivery.Sections.update_section/2` accepts."
  @spec generic() :: [atom()]
  def generic, do: Enum.sort(open() ++ system_derived())

  @doc """
  Returns `:ok` when every key of `attrs` (atoms or strings) is one of `allowed`, or
  `{:error, :protected}` otherwise.
  """
  @spec check(map(), [atom()]) :: :ok | {:error, :protected}
  def check(attrs, allowed) when is_map(attrs) do
    allowed = MapSet.new(allowed, &Atom.to_string/1)

    case Enum.all?(Map.keys(attrs), &MapSet.member?(allowed, to_string(&1))) do
      true -> :ok
      false -> {:error, :protected}
    end
  end

  @doc """
  Keeps the keys of `attrs` (atoms or strings) that name one of `allowed`, so a form saves only
  the fields it renders.
  """
  @spec take(map(), [atom()]) :: map()
  def take(attrs, allowed) when is_map(attrs) do
    allowed = MapSet.new(allowed, &Atom.to_string/1)
    Map.filter(attrs, fn {key, _value} -> MapSet.member?(allowed, to_string(key)) end)
  end
end
