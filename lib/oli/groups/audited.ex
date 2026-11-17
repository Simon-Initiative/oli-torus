defmodule Oli.Groups.Audited do
  @moduledoc """
  Application boundary for audited community commands: communities and their members,
  visible projects and sections, and associated institutions.

  Every command records `community_settings_changed` for the community in the same transaction
  as the change. Members, visibilities, and institutions are recorded as `members` added or
  removed (with their type and ID), so the community's history shows who or what joined or left.
  Commands do not authorize the actor; callers keep their existing authorization.
  """

  # This configuration is what makes CI fail when a caller bypasses this facade.
  # Keep the boundary top-level and never export internal modules. Outgoing checks are off
  # because this boundary calls into Oli, which depends on it; incoming checks stay on.
  use Boundary, top_level?: true, exports: [], check: [out: false]

  alias Ecto.Multi
  alias Oli.Auditing.{Command, Context}
  alias Oli.Auditing.EventCatalog.Fields
  alias Oli.Groups.{Community, CommunityAccount, CommunityInstitution, CommunityVisibility}

  @type association :: :account | :visibility | :institution

  @doc "Creates a community and records its settings."
  @spec create_community(Context.t(), map()) :: {:ok, %Community{}} | {:error, term()}
  def create_community(context, attrs) do
    Command.run(:community, fn multi ->
      Command.insert(
        multi,
        :community,
        context,
        Community.changeset(%Community{}, attrs),
        community()
      )
    end)
  end

  @doc "Updates the community with ID `id` and records the settings that changed."
  @spec update_community(Context.t(), pos_integer(), map()) ::
          {:ok, %Community{}} | {:error, term()}
  def update_community(context, id, attrs) do
    Command.run(:community, fn multi ->
      Command.update(
        multi,
        :community,
        context,
        {Community, id},
        &Community.changeset(&1, attrs),
        community()
      )
    end)
  end

  @doc "Marks the community as deleted (the existing soft delete) and records the change."
  @spec delete_community(Context.t(), pos_integer()) :: {:ok, %Community{}} | {:error, term()}
  def delete_community(context, id), do: update_community(context, id, %{status: :deleted})

  @doc """
  Adds to `multi` a community association: a member account (`:account`, with `user_id` or
  `author_id` and `is_admin`), a visible project or section (`:visibility`), or an institution
  (`:institution`). Records the community's `members` change. The result under `name` is the
  inserted row.
  """
  @spec add_association_multi(Multi.t(), Multi.name(), Context.t(), {association(), map()}) ::
          Multi.t()
  def add_association_multi(%Multi{} = multi, name, %Context{} = context, {kind, attrs})
      when kind in [:account, :visibility, :institution] and is_map(attrs) do
    schema = schema(kind)

    Command.insert(
      multi,
      name,
      context,
      schema.changeset(struct(schema), attrs),
      association(kind)
    )
  end

  @doc "Adds to `multi` the removal of the association row of `kind` with ID `id`."
  @spec remove_association_multi(
          Multi.t(),
          Multi.name(),
          Context.t(),
          {association(), pos_integer()}
        ) ::
          Multi.t()
  def remove_association_multi(%Multi{} = multi, name, %Context{} = context, {kind, id})
      when kind in [:account, :visibility, :institution] do
    Command.delete(multi, name, context, {schema(kind), id}, association(kind))
  end

  defp community do
    %{
      event_type: :community_settings_changed,
      policy: Map.delete(Fields.organization(), :members),
      proposal: fn community, operation ->
        %{
          entity: {:community, community.id, community},
          event_key: "community:#{community.id}:#{operation}"
        }
      end
    }
  end

  defp association(kind) do
    %{
      event_type: :community_settings_changed,
      policy: %{},
      proposal: fn row, operation ->
        %{
          entity: {:community, row.community_id, %{id: row.community_id}},
          event_key: "community:#{row.community_id}:#{kind}:#{row.id}:#{operation}"
        }
      end,
      changes: fn row, operation ->
        member = member(kind, row)

        case operation do
          :created -> %{"members" => %{"operation" => "added", "after" => [member]}}
          :deleted -> %{"members" => %{"operation" => "removed", "before" => [member]}}
        end
      end
    }
  end

  defp member(:account, row) do
    %{"user_id" => row.user_id, "author_id" => row.author_id, "is_admin" => row.is_admin}
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp member(:visibility, row) do
    %{"project_id" => row.project_id, "section_id" => row.section_id}
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp member(:institution, row), do: %{"institution_id" => row.institution_id}

  defp schema(:account), do: CommunityAccount
  defp schema(:visibility), do: CommunityVisibility
  defp schema(:institution), do: CommunityInstitution
end
