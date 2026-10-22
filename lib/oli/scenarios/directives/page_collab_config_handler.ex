defmodule Oli.Scenarios.Directives.PageCollabConfigHandler do
  @moduledoc """
  Configures Notes collaboration spaces for every page in a scenario section.
  """

  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.CollabSpaceConfig
  alias Oli.Scenarios.DirectiveTypes.{ExecutionState, PageCollabConfigDirective}
  alias Oli.Scenarios.Engine

  def handle(
        %PageCollabConfigDirective{} = directive,
        %ExecutionState{} = state
      ) do
    with {:ok, section} <- fetch_section(state, directive.section),
         {:ok, config} <- build_config(directive) do
      if directive.enabled == false do
        Collaboration.disable_all_page_collab_spaces_for_section(section.slug)
      else
        Collaboration.enable_all_page_collab_spaces_for_section(section.slug, config)
      end

      {:ok, state}
    else
      {:error, reason} -> {:error, "Failed to configure page collaboration: #{reason}"}
    end
  end

  defp fetch_section(state, name) do
    case Engine.get_section(state, name) do
      nil -> {:error, "Section '#{name}' not found"}
      section -> {:ok, section}
    end
  end

  defp build_config(directive) do
    with {:ok, participation_min_replies} <-
           integer_or_default(directive.participation_min_replies, "participation_min_replies"),
         {:ok, participation_min_posts} <-
           integer_or_default(directive.participation_min_posts, "participation_min_posts") do
      {:ok,
       %CollabSpaceConfig{
         status: if(directive.enabled == false, do: :disabled, else: :enabled),
         threaded: directive.threaded != false,
         auto_accept: directive.auto_accept != false,
         show_full_history: directive.show_full_history != false,
         anonymous_posting: directive.anonymous_posting == true,
         participation_min_replies: participation_min_replies,
         participation_min_posts: participation_min_posts
       }}
    end
  end

  defp integer_or_default(nil, _field), do: {:ok, 0}
  defp integer_or_default(value, _field) when is_integer(value), do: {:ok, value}

  defp integer_or_default(value, field) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> {:ok, integer}
      _ -> {:error, "#{field} must be an integer, got: #{inspect(value)}"}
    end
  end

  defp integer_or_default(value, field),
    do: {:error, "#{field} must be an integer, got: #{inspect(value)}"}
end
