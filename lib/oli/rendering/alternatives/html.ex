defmodule Oli.Rendering.Alternatives.Html do
  @moduledoc """
  Implements the Html writer for rendering alternatives
  """

  alias Oli.Rendering.Context
  alias Oli.Rendering.Elements
  alias Oli.Rendering.Error

  @behaviour Oli.Rendering.Alternatives

  def alternatives(%Context{} = context, model) do
    Elements.render(context, model, Elements.Html)
  end

  def preference_selector(
        %Context{
          user: user,
          section_slug: section_slug,
          extrinsic_read_section_fn: extrinsic_read_section_fn
        },
        %{
          "preference_name" => preference_name,
          "default" => default
        }
      ) do
    {:safe, preference_selector} =
      ReactPhoenix.ClientSide.react_component("Components.AlternativesPreferenceSelector", %{
        preferenceName: preference_name,
        selected:
          user_section_preference(
            user,
            section_slug,
            preference_name,
            extrinsic_read_section_fn
          ),
        default: default
      })

    preference_selector
  end

  defp user_section_preference(
         user,
         section_slug,
         preference_name,
         extrinsic_read_section_fn
       ) do
    alt_pref_key = Oli.Delivery.ExtrinsicState.Key.alternatives_preference(preference_name)

    case extrinsic_read_section_fn.(
           user.id,
           section_slug,
           MapSet.new([alt_pref_key])
         ) do
      %{^alt_pref_key => user_pref} -> user_pref
      _ -> nil
    end
  end

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Html)
  end
end
