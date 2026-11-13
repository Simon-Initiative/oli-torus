defmodule Oli.Lti.Audited do
  @moduledoc """
  Application boundary for audited external LTI tool commands: registering, editing, enabling
  or disabling, and deleting a tool, and the deep-link choice an instructor saves for a section
  activity.

  Each command records `external_tool_settings_changed` in the same transaction as the change.
  Tool custom parameters and deep-link custom values can carry tool credentials, so they are
  recorded only as redaction markers. Commands do not authorize the actor; callers keep their
  existing authorization.
  """

  # This configuration is what makes CI fail when a caller bypasses this facade.
  # Keep the boundary top-level and never export internal modules. Outgoing checks are off
  # because this boundary calls into Oli, which depends on it; incoming checks stay on.
  use Boundary, top_level?: true, exports: [], check: [out: false]

  import Ecto.Query, only: [from: 2]

  alias Ecto.Multi
  alias Lti_1p3.DataProviders.EctoProvider.PlatformInstance
  alias Oli.Activities
  alias Oli.Activities.ActivityRegistration
  alias Oli.Auditing.{Command, Context}
  alias Oli.Auditing.EventCatalog.Fields
  alias Oli.Lti.PlatformExternalTools

  alias Oli.Lti.PlatformExternalTools.{
    LtiExternalToolActivityDeployment,
    LtiSectionResourceDeepLink
  }

  @doc """
  Registers an external tool: creates its platform instance, its activity registration, and
  its deployment, and records the tool's creation. Returns
  `{:ok, {platform_instance, activity_registration, deployment}}`.
  """
  @spec register_external_tool(Context.t(), map()) :: {:ok, tuple()} | {:error, term()}
  def register_external_tool(context, params) do
    Command.run(:tool, fn multi ->
      multi
      |> Command.insert(
        {:tool, :instance},
        context,
        PlatformExternalTools.change_platform_instance(%PlatformInstance{}, params),
        tool()
      )
      |> Multi.run({:tool, :activity}, fn _repo, _changes ->
        Activities.register_lti_external_tool_activity(
          params["name"],
          params["name"],
          params["description"]
        )
      end)
      |> Multi.run({:tool, :deployment}, fn repo, changes ->
        %LtiExternalToolActivityDeployment{}
        |> LtiExternalToolActivityDeployment.changeset(%{
          platform_instance_id: Map.fetch!(changes, {:tool, :instance}).id,
          activity_registration_id: Map.fetch!(changes, {:tool, :activity}).id
        })
        |> repo.insert()
      end)
      |> Multi.run(:tool, fn _repo, changes ->
        {:ok,
         {Map.fetch!(changes, {:tool, :instance}), Map.fetch!(changes, {:tool, :activity}),
          Map.fetch!(changes, {:tool, :deployment})}}
      end)
    end)
  end

  @doc """
  Updates the platform instance with ID `id` from the tool form, keeps its activity title,
  label, and description in step, and records the settings that changed. Returns the updated
  platform instance; a missing tool returns `{:error, :not_found}`.
  """
  @spec update_external_tool(Context.t(), pos_integer(), map()) ::
          {:ok, %PlatformInstance{}} | {:error, term()}
  def update_external_tool(context, id, attrs) do
    Command.run(:tool, fn multi ->
      multi
      |> Command.update(
        :tool,
        context,
        {PlatformInstance, id},
        &PlatformExternalTools.change_platform_instance(&1, attrs),
        tool()
      )
      |> Multi.run({:tool, :activity}, fn repo, _changes ->
        from(a in ActivityRegistration,
          join: d in LtiExternalToolActivityDeployment,
          on: d.activity_registration_id == a.id,
          where: d.platform_instance_id == ^id
        )
        |> repo.one()
        |> case do
          nil ->
            {:error, :not_found}

          activity ->
            activity
            |> ActivityRegistration.changeset(%{
              title: attrs["name"],
              petite_label: attrs["name"],
              description: attrs["description"]
            })
            |> repo.update()
        end
      end)
    end)
  end

  @doc """
  Updates the tool deployment whose `deployment_id` is `id` (its status or whether deep linking
  is enabled) and records the change for its tool.
  """
  @spec update_external_tool_deployment(Context.t(), Ecto.UUID.t(), map()) ::
          {:ok, %LtiExternalToolActivityDeployment{}} | {:error, term()}
  def update_external_tool_deployment(context, id, attrs) do
    Command.run(:deployment, fn multi ->
      Command.update(
        multi,
        :deployment,
        context,
        {LtiExternalToolActivityDeployment, id},
        &LtiExternalToolActivityDeployment.changeset(&1, attrs),
        tool_deployment()
      )
    end)
  end

  @doc """
  Soft-deletes the tool deployment whose `deployment_id` is `id` and its platform instance,
  recording the status change of each.
  """
  @spec delete_external_tool(Context.t(), Ecto.UUID.t()) :: {:ok, map()} | {:error, term()}
  def delete_external_tool(context, id) do
    Command.run(:tool, fn multi ->
      multi
      |> Command.update(
        {:tool, :deployment},
        context,
        {LtiExternalToolActivityDeployment, id},
        &LtiExternalToolActivityDeployment.changeset(&1, %{status: :deleted}),
        tool_deployment()
      )
      |> Multi.merge(fn changes ->
        deployment = Map.fetch!(changes, {:tool, :deployment})

        Command.update(
          Multi.new(),
          {:tool, :instance},
          context,
          {PlatformInstance, deployment.platform_instance_id},
          &PlatformExternalTools.change_platform_instance(&1, %{status: :deleted}),
          tool()
        )
      end)
      |> Multi.run(:tool, fn _repo, changes ->
        {:ok,
         %{
           deployment: Map.fetch!(changes, {:tool, :deployment}),
           platform_instance: Map.fetch!(changes, {:tool, :instance})
         }}
      end)
    end)
  end

  @doc """
  Adds to `multi` the save of the deep-link choice for one section activity (insert, or
  replace the existing one for the same section and resource, resetting the fields the new
  choice does not include), with the instructor who chose it
  as `context`. Records the change with the section as scope; an identical choice writes no
  event.
  """
  @spec persist_deep_link_multi(Multi.t(), Multi.name(), Context.t(), map()) :: Multi.t()
  def persist_deep_link_multi(%Multi{} = multi, name, %Context{} = context, attrs) do
    section_id = attrs["section_id"] || attrs[:section_id]
    resource_id = attrs["resource_id"] || attrs[:resource_id]

    query =
      from(d in LtiSectionResourceDeepLink,
        where: d.section_id == ^section_id and d.resource_id == ^resource_id
      )

    Multi.merge(multi, fn _changes ->
      case Oli.Repo.one(query) do
        nil ->
          Command.insert(
            Multi.new(),
            name,
            context,
            LtiSectionResourceDeepLink.changeset(%LtiSectionResourceDeepLink{}, attrs),
            deep_link()
          )

        %LtiSectionResourceDeepLink{id: id} ->
          Command.update(
            Multi.new(),
            name,
            context,
            {LtiSectionResourceDeepLink, id},
            &LtiSectionResourceDeepLink.changeset(&1, replacement(attrs)),
            deep_link()
          )
      end
    end)
  end

  # A new choice replaces the previous one entirely: fields the tool did not return go back to
  # their defaults instead of keeping the old item's values (for example its custom parameters).
  defp replacement(attrs) do
    defaults = %{type: :ltiResourceLink, url: nil, title: nil, text: nil, custom: %{}}

    case Enum.all?(Map.keys(attrs), &is_binary/1) do
      true ->
        Map.merge(Map.new(defaults, fn {key, value} -> {Atom.to_string(key), value} end), attrs)

      false ->
        Map.merge(defaults, attrs)
    end
  end

  defp tool do
    %{
      event_type: :external_tool_settings_changed,
      policy: Fields.integration(),
      proposal: fn instance, operation ->
        %{
          entity: {:external_tool, instance.id, %{id: instance.id, name: instance.name}},
          event_key: "external_tool:#{instance.id}:#{operation}"
        }
      end
    }
  end

  defp tool_deployment do
    %{
      event_type: :external_tool_settings_changed,
      policy: Fields.integration(),
      proposal: fn deployment, operation ->
        %{
          entity:
            {:external_tool, deployment.platform_instance_id,
             %{id: deployment.platform_instance_id}},
          event_key:
            "external_tool:#{deployment.platform_instance_id}:deployment:#{deployment.deployment_id}:#{operation}"
        }
      end
    }
  end

  defp deep_link do
    %{
      event_type: :external_tool_settings_changed,
      policy: Fields.integration(),
      proposal: fn link, operation ->
        %{
          entity: {:section, link.section_id, %{id: link.section_id}},
          scope: %{section_id: link.section_id, resource_id: link.resource_id},
          event_key: "deep_link:#{link.section_id}:#{link.resource_id}:#{operation}"
        }
      end
    }
  end
end
