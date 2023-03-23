defmodule Oli.Rendering.Alternatives.Html do
  @moduledoc """
  Implements the Html writer for rendering alternatives
  """

  alias Oli.Rendering.Context
  alias Oli.Rendering.Elements
  alias Oli.Rendering.Error
  alias Oli.Resources.Alternatives.Selection

  @behaviour Oli.Rendering.Alternatives

  @impl Oli.Rendering.Alternatives
  def alternative(
        %Context{} = context,
        %Selection{
          alternative: %{
            "type" => "alternative",
            "value" => value,
            "children" => children
          },
          hidden: hidden
        }
      ) do
    [
      ~s|<div class="alternative alternative-#{value}#{maybe_hidden(hidden)}">|,
      Elements.render(context, children, Elements.Html),
      "</div>"
    ]
  end

  defp maybe_hidden(true), do: " hidden"
  defp maybe_hidden(false), do: ""

  @impl Oli.Rendering.Alternatives
  def preference_selector(
        %Context{
          user: user,
          section_slug: section_slug,
          alternatives_groups_fn: alternatives_groups_fn,
          extrinsic_read_section_fn: extrinsic_read_section_fn,
          mode: mode
        },
        %{
          "alternatives_id" => alternatives_id
        }
      ) do
    {:ok, groups} = alternatives_groups_fn.()

    options =
      case Enum.find(groups, &(&1.id == alternatives_id)) do
        nil ->
          []

        %{options: options} ->
          options
      end

    {:safe, preference_selector} =
      ReactPhoenix.ClientSide.react_component("Components.AlternativesPreferenceSelector", %{
        sectionSlug: section_slug,
        alternativesId: alternatives_id,
        options: options,
        selected:
          user_section_preference(
            mode,
            user,
            section_slug,
            alternatives_id,
            extrinsic_read_section_fn
          )
      })

    preference_selector
  end

  defp user_section_preference(
         :delivery,
         user,
         section_slug,
         alternatives_id,
         extrinsic_read_section_fn
       ) do
    alt_pref_key = Oli.Delivery.ExtrinsicState.Key.alternatives_preference(alternatives_id)

    case extrinsic_read_section_fn.(
           user.id,
           section_slug,
           MapSet.new([alt_pref_key])
         ) do
      {:ok, %{^alt_pref_key => user_pref}} -> user_pref
      _ -> nil
    end
  end

  defp user_section_preference(_, _, _, _, _), do: nil

  @impl Oli.Rendering.Alternatives
  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Html)
  end
end
