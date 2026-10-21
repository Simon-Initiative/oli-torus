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
    {:ok,
     %CollabSpaceConfig{
       status: if(directive.enabled == false, do: :disabled, else: :enabled),
       threaded: directive.threaded != false,
       auto_accept: directive.auto_accept != false,
       show_full_history: directive.show_full_history != false,
       anonymous_posting: directive.anonymous_posting == true,
       participation_min_replies: integer_or_default(directive.participation_min_replies),
       participation_min_posts: integer_or_default(directive.participation_min_posts)
     }}
  end

  defp integer_or_default(nil), do: 0
  defp integer_or_default(value) when is_integer(value), do: value
  defp integer_or_default(value) when is_binary(value), do: String.to_integer(value)
end
