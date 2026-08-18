defmodule Oli.Rendering.Alternatives.Html do
  @moduledoc """
  Implements the Html writer for rendering alternatives
  """

  alias Oli.Rendering.Context
  alias Oli.Rendering.Elements
  alias Oli.Rendering.Error
  alias Oli.Resources.Alternatives.Selection

  @behaviour Oli.Rendering.Alternatives

  @doc "Renders preview alternatives as a keyboard-operable tab set."
  def preview_alternatives(context, element, selections) do
    placement_id =
      element
      |> Map.get("id", "preview")
      |> to_string()
      |> Base.url_encode64(padding: false)

    tabs =
      selections
      |> Enum.with_index()
      |> Enum.map(fn {_selection, index} ->
        selected? = index == 0

        classes =
          if selected? do
            "btn btn-sm mr-2 whitespace-nowrap bg-primary text-white dark:bg-blue-600 dark:text-white"
          else
            "btn btn-sm mr-2 whitespace-nowrap hover:bg-gray-200 dark:text-gray-100 dark:hover:bg-gray-700"
          end

        ~s|<button type="button" role="tab" class="#{classes}" id="preview-alternative-tab-#{placement_id}-#{index}" aria-selected="#{selected?}" aria-controls="preview-alternative-panel-#{placement_id}-#{index}" tabindex="#{if(selected?, do: 0, else: -1)}">Alternative #{index + 1}</button>|
      end)

    panels =
      selections
      |> Enum.with_index()
      |> Enum.map(fn {%Selection{alternative: %{"children" => children}}, index} ->
        hidden = if index == 0, do: "", else: " hidden"

        [
          ~s|<div role="tabpanel" id="preview-alternative-panel-#{placement_id}-#{index}" aria-labelledby="preview-alternative-tab-#{placement_id}-#{index}"#{hidden}>|,
          Elements.render(context, children, Elements.Html),
          "</div>"
        ]
      end)

    [
      ~s|<div id="preview-alternatives-#{placement_id}" phx-hook="PreviewAlternativesTabs">|,
      preview_notice(context, element, :tabs),
      ~s|<div role="tablist" aria-label="Alternative content options">|,
      tabs,
      "</div>",
      panels,
      "</div>"
    ]
  end

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
        } = context,
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
      OliWeb.Common.React.component(
        context,
        "Components.AlternativesPreferenceSelector",
        %{
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
        },
        id: "alternatives-selector-#{alternatives_id}"
      )

    [
      preview_notice(context, %{"alternatives_id" => alternatives_id}, :preference),
      preference_selector
    ]
  end

  defp preview_notice(%Context{mode: mode} = context, element, presentation)
       when mode in [:author_preview, :instructor_preview] do
    strategy =
      (context.alternative_groups_by_id || %{})
      |> Map.get(element["alternatives_id"], %{})
      |> Map.get(:strategy)

    message = preview_notice_message(strategy, presentation)

    ~s|<div data-preview-alternatives-notice class="mb-3 rounded-md border border-blue-200 bg-blue-50 px-3 py-2 text-sm text-blue-900 dark:border-blue-800 dark:bg-blue-950 dark:text-blue-100">#{message}</div>|
  end

  defp preview_notice(_context, _element, _presentation), do: ""

  defp preview_notice_message(strategy, :tabs)
       when strategy in ["experiment_controlled", "upgrade_decision_point"] do
    "Preview each alternative using the tabs below to switch between them. The experiment policy assigns one alternative to each learner, and that assignment stays with the learner for this intervention."
  end

  defp preview_notice_message("user_section_preference", :preference) do
    "Preview each alternative by selecting it from the list below. A learner's selection will be stored as their preference for the section."
  end

  defp preview_notice_message(_strategy, :tabs) do
    "Preview each alternative using the tabs below to switch between them. In delivery, this group's policy determines which content is shown."
  end

  defp preview_notice_message(_strategy, :preference) do
    "Preview mode lets you test each preference. In delivery, the learner's preference determines which alternative is shown."
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
