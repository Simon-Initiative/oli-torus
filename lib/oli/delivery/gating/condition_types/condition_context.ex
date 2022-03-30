defmodule Oli.Delivery.Gating.ConditionTypes.ConditionContext do
  alias Oli.Delivery.Gating.ConditionTypes.ConditionContext
  alias Oli.Delivery.Sections.Section
  alias Oli.Accounts.User
  alias Oli.Delivery.Attempts.Core

  defstruct [
    :user,
    :section,
    :resource_accesses
  ]

  @type t() :: %__MODULE__{
          user: any(),
          section: any(),
          resource_accesses: map()
        }

  def init(%User{} = user, %Section{} = section) do
    %ConditionContext{user: user, section: section}
  end

  def resource_accesses(
        %ConditionContext{user: user, section: section, resource_accesses: nil} = context
      ) do
    resource_accesses =
      Core.get_resource_accesses(section.slug, user.id)
      |> Enum.reduce(%{}, fn r, m -> Map.put(m, r.resource_id, r) end)

    context = Map.put(context, :resource_accesses, resource_accesses)

    {resource_accesses, context}
  end

  def resource_accesses(%ConditionContext{resource_accesses: resource_accesses} = context) do
    {resource_accesses, context}
  end
end
