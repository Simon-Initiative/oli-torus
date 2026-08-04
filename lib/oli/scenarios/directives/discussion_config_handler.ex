defmodule Oli.Scenarios.Directives.DiscussionConfigHandler do
  @moduledoc """
  Configures course discussions on a scenario section.
  """

  alias Oli.Delivery.Sections
  alias Oli.Repo
  alias Oli.Scenarios.DirectiveTypes.{DiscussionConfigDirective, ExecutionState}
  alias Oli.Scenarios.Engine

  def handle(
        %DiscussionConfigDirective{
          section: section_name,
          enabled: enabled,
          auto_accept: auto_accept,
          anonymous_posting: anonymous_posting
        },
        %ExecutionState{} = state
      ) do
    with {:ok, section} <- fetch_section(state, section_name),
         {:ok, root_section_resource} <- fetch_root_section_resource(section),
         attrs <-
           config_attrs(
             root_section_resource.collab_space_config,
             enabled,
             auto_accept,
             anonymous_posting
           ),
         {:ok, _updated_root_section_resource} <-
           Sections.update_section_resource(root_section_resource, %{collab_space_config: attrs}),
         {:ok, updated_section} <-
           maybe_update_contains_discussions(section, enabled) do
      {:ok, put_section_or_product(state, section_name, updated_section)}
    else
      {:error, reason} ->
        {:error, "Failed to configure discussions: #{inspect(reason)}"}
    end
  end

  defp fetch_section(state, name) do
    case Engine.get_section(state, name) || Engine.get_product(state, name) do
      nil -> {:error, "Section '#{name}' not found"}
      section -> {:ok, section}
    end
  end

  defp fetch_root_section_resource(section) do
    section = Repo.preload(section, :root_section_resource)

    case section.root_section_resource do
      nil -> {:error, "Root section resource not found for section '#{section.slug}'"}
      root_section_resource -> {:ok, root_section_resource}
    end
  end

  defp config_attrs(config, enabled, auto_accept, anonymous_posting) do
    config
    |> config_to_map()
    |> maybe_put(:status, status(enabled))
    |> maybe_put(:auto_accept, auto_accept)
    |> maybe_put(:anonymous_posting, anonymous_posting)
  end

  defp status(nil), do: nil
  defp status(true), do: :enabled
  defp status(false), do: :disabled

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp config_to_map(nil), do: %{}
  defp config_to_map(%{__struct__: _} = config), do: Map.from_struct(config)
  defp config_to_map(config) when is_map(config), do: config

  defp maybe_update_contains_discussions(section, nil), do: {:ok, section}

  defp maybe_update_contains_discussions(section, enabled) do
    Sections.update_section(section, %{contains_discussions: enabled})
  end

  defp put_section_or_product(state, name, updated_section) do
    if Engine.get_product(state, name) do
      Engine.put_product(state, name, updated_section)
    else
      Engine.put_section(state, name, updated_section)
    end
  end
end
