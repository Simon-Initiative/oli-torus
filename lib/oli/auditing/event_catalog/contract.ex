defmodule Oli.Auditing.EventCatalog.Contract do
  @moduledoc """
  The contract of one audit event type.

    * `name`, `family`, `label`, `description` - identity and documentation. `description` is
      one sentence stating what happened and, where the name could mislead, what it does not
      imply.
    * `actor_kinds` - allowed actor types (`:user`, `:author`, `:system`).
    * `entity_types` - allowed `entity_type` values.
    * `required` - scope columns that must be present.
    * `required_one_of` - scope columns of which at least one must be present.
    * `affected_kinds` / `affected_required` - which `affected_*_id` columns the event may set,
      and whether one of them is mandatory.
    * `subject_is_affected` - `entity_id` must equal the affected account ID (account and
      authentication events).
    * `outcomes` - allowed outcomes.
    * `no_op` - `:skip` rejects an empty `changes` map; `:lifecycle` accepts it.
    * `change_fields` - allowed `changes` keys, each `:value` or `:secret`.
    * `detail_keys` - allowed `details` keys.
    * `ref_roles` - allowed `refs` roles.
    * `v1_only` - name kept only for migrated history; never written by the application.
    * `deprecated` - released name that no longer accepts new writes.
  """

  @enforce_keys [:name, :family, :label, :description, :actor_kinds, :entity_types, :outcomes]
  defstruct [
    :name,
    :family,
    :label,
    :description,
    actor_kinds: [],
    entity_types: [],
    required: [],
    required_one_of: [],
    affected_kinds: [],
    affected_required: false,
    subject_is_affected: false,
    outcomes: [],
    no_op: :lifecycle,
    change_fields: %{},
    detail_keys: [],
    ref_roles: [],
    v1_only: false,
    deprecated: false
  ]

  @type actor_kind :: :user | :author | :system
  @type scope_column :: :project_id | :section_id | :resource_id | :institution_id
  @type outcome :: :succeeded | :initiated | :failed | :canceled | :partial | :unknown

  @type t :: %__MODULE__{
          name: atom(),
          family: atom(),
          label: String.t(),
          description: String.t(),
          actor_kinds: [actor_kind()],
          entity_types: [atom()],
          required: [scope_column()],
          required_one_of: [scope_column()],
          affected_kinds: [:user | :author],
          affected_required: boolean(),
          subject_is_affected: boolean(),
          outcomes: [outcome()],
          no_op: :skip | :lifecycle,
          change_fields: %{optional(atom()) => :value | :secret},
          detail_keys: [String.t()],
          ref_roles: [atom()],
          v1_only: boolean(),
          deprecated: boolean()
        }
end
