defmodule Oli.Delivery.Experiments.ActivityProvider do
  @moduledoc """
  Decorates a delivery activity provider with experiment-controlled Alternatives decisions.

  The decorator prunes unselected branches before activity realization and carries the
  corresponding decision and attribution metadata into the resource attempt.
  """

  alias Oli.Delivery.Experiments.PageDecisions
  alias Oli.Delivery.Sections.Section
  alias Oli.Resources.{Alternatives, PageContent, Revision}

  @type provider ::
          (map(), struct(), list(), struct(), String.t(), module() ->
             Oli.Delivery.ActivityProvider.Result.t())

  @doc """
  Wraps an activity provider using decisions that have already been prepared.
  """
  @spec from_prepared(provider(), map()) :: provider()
  def from_prepared(activity_provider, prepared) do
    fn content, source, prototypes, learner, section_slug, resolver ->
      selected_content =
        Alternatives.apply_experiment_decisions(
          content,
          prepared.alternative_groups_by_id,
          prepared.experiment_decisions
        )

      result =
        activity_provider.(
          selected_content,
          source,
          prototypes,
          learner,
          section_slug,
          resolver
        )

      %{
        result
        | alternative_groups_by_id: prepared.alternative_groups_by_id,
          experiment_decisions: prepared.experiment_decisions,
          experiment_attributions: prepared.experiment_attributions
      }
    end
  end

  @doc """
  Lazily prepares experiment decisions when the provider is invoked.

  Pages without Alternatives retain the original provider. Deferring preparation ensures
  rejected attempt starts do not perform assignment work inside the start transaction.
  """
  @spec for_page(provider(), Section.t(), Revision.t(), struct()) :: provider()
  def for_page(activity_provider, %Section{} = section, %Revision{} = page_revision, user) do
    case PageContent.alternatives_placements(page_revision.content) do
      [] ->
        activity_provider

      placements ->
        fn content, source, prototypes, learner, section_slug, resolver ->
          prepared =
            PageDecisions.prepare_placements(section, page_revision, user, placements)

          from_prepared(activity_provider, prepared).(
            content,
            source,
            prototypes,
            learner,
            section_slug,
            resolver
          )
        end
    end
  end
end
