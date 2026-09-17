defmodule Oli.Delivery.Sections.CopyOptions do
  @moduledoc """
  Explicit, allowlisted description of what a section copy carries from its source.

  A copy is described by a set of named `groups` rather than by positional
  booleans. The UI may present those groups individually or combine them into
  broader choices without changing this domain contract.

  ## Groups

    * `:content` - the structural snapshot: publication pins, section resources,
      the remixed hierarchy, required survey, activity exclusions and non-schedule gates. Mandatory:
      a copy with no content source has no defined meaning, so `new/2` rejects a
      group set that omits it.
    * `:schedule` - section-resource scheduling state and schedule-shaped gates.
      Absolute dates are preserved exactly; term shifting is a separate feature.
    * `:section_settings` - instructor-owned section configuration (labels,
      numbering, welcome copy, agenda, branding, certificate) and page-level
      collaboration space configuration.
    * `:assessment_settings` - section-resource assessment configuration.
      Student-specific exceptions are never included.
    * `:ai_settings` - section-level assistant configuration and page-level
      `ai_enabled` overrides.

  ## Section field policy

  `section_field_policy` selects how the destination section row is built:

    * `:allowlist` - the destination row is constructed from system defaults plus
      the explicitly selected groups plus destination attributes. Fields added to
      the `sections` schema in future are *not* copied unless a group claims them.
      This is the policy for course copy.
    * `:inherit_all` - the destination row starts from the full source struct.
      This reproduces historical `Blueprint.duplicate/3` behaviour and exists only
      so product duplication is unchanged by the extraction of the copy engine.
      Do not select it for new callers.
  """

  @groups [:content, :schedule, :section_settings, :assessment_settings, :ai_settings]

  @type group ::
          :content
          | :schedule
          | :section_settings
          | :assessment_settings
          | :ai_settings

  @type section_field_policy :: :allowlist | :inherit_all
  @type source_kind :: :blueprint | :previous_section

  @type t :: %__MODULE__{
          groups: MapSet.t(group()),
          project_remap: nil | {integer(), integer()},
          section_field_policy: section_field_policy(),
          source_kind: source_kind()
        }

  defstruct groups: MapSet.new([:content]),
            project_remap: nil,
            section_field_policy: :allowlist,
            source_kind: :previous_section

  @doc "Returns every group name the copy engine understands."
  @spec groups() :: [group()]
  def groups, do: @groups

  @doc """
  Builds copy options from a list of group names.

  Unknown groups are an error rather than being silently ignored, and `:content`
  is required. Both checks live here, in the domain layer, so that a UI change
  can never widen what a copy is allowed to carry.

  ## Examples

      iex> {:ok, options} = Oli.Delivery.Sections.CopyOptions.new([:content, :schedule])
      iex> Oli.Delivery.Sections.CopyOptions.selected?(options, :schedule)
      true

      iex> Oli.Delivery.Sections.CopyOptions.new([:content, :grades])
      {:error, {:unknown_copy_groups, [:grades]}}

      iex> Oli.Delivery.Sections.CopyOptions.new([:schedule])
      {:error, :content_group_required}
  """
  @spec new([atom()] | MapSet.t(atom()), keyword()) :: {:ok, t()} | {:error, term()}
  def new(groups, opts \\ [])

  def new(%MapSet{} = groups, opts), do: groups |> MapSet.to_list() |> new(opts)

  def new(groups, opts) when is_list(groups) do
    with {:ok, groups} <- validate_known(groups),
         :ok <- validate_content_present(groups) do
      {:ok,
       %__MODULE__{
         groups: groups,
         project_remap: Keyword.get(opts, :project_remap),
         section_field_policy: :allowlist,
         source_kind: Keyword.get(opts, :source_kind, :previous_section)
       }}
    end
  end

  @doc """
  Builds copy options for copying a previous course section.

  This is the course-copy policy: allowlisted section fields, no project remap.
  """
  @spec for_previous_section([atom()] | MapSet.t(atom())) :: {:ok, t()} | {:error, term()}
  def for_previous_section(groups), do: new(groups, source_kind: :previous_section)

  @doc """
  Builds copy options reproducing historical `Blueprint.duplicate/3` behaviour.

  Every group is selected and the destination section row inherits all source
  fields. This exists to keep product duplication, product-to-section creation
  and project cloning behaviourally unchanged; new callers should use
  `for_previous_section/1` instead.

  `project_remap` is the `{source_project_id, publication_id}` pair used when a
  product is duplicated as part of cloning its project.
  """
  @spec for_blueprint_duplication(nil | {integer(), integer()}) :: t()
  def for_blueprint_duplication(project_remap \\ nil) do
    %__MODULE__{
      groups: MapSet.new(@groups),
      project_remap: project_remap,
      section_field_policy: :inherit_all,
      source_kind: :blueprint
    }
  end

  @doc "Returns true when `group` is selected."
  @spec selected?(t(), group()) :: boolean()
  def selected?(%__MODULE__{groups: groups}, group), do: MapSet.member?(groups, group)

  @doc "Returns the selected groups as a sorted list of strings, for audit and telemetry."
  @spec to_audit_list(t()) :: [String.t()]
  def to_audit_list(%__MODULE__{groups: groups}) do
    groups |> Enum.map(&Atom.to_string/1) |> Enum.sort()
  end

  defp validate_known(groups) do
    case Enum.reject(groups, &(&1 in @groups)) do
      [] -> {:ok, MapSet.new(groups)}
      unknown -> {:error, {:unknown_copy_groups, Enum.uniq(unknown)}}
    end
  end

  defp validate_content_present(groups) do
    case MapSet.member?(groups, :content) do
      true -> :ok
      false -> {:error, :content_group_required}
    end
  end
end
