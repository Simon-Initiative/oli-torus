defmodule Oli.Delivery.TemplatePreview do
  @moduledoc """
  Prepares template preview launches for template authors and admins.
  """

  alias Oli.Accounts
  alias Oli.Accounts.{Author, User}
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Delivery.Sections.Section
  alias Oli.FeatureTelemetry

  @requested_event [:oli, :template_preview, :requested]
  @enrollment_ensured_event [:oli, :template_preview, :enrollment_ensured]
  @launch_succeeded_event [:oli, :template_preview, :launch_succeeded]
  @launch_failed_event [:oli, :template_preview, :launch_failed]

  @spec prepare_launch(Section.t(), User.t() | nil, Author.t() | nil) ::
          {:ok, %{section_slug: String.t(), enrollment_outcome: :created | :reused}}
          | {:error, atom()}
  def prepare_launch(%Section{} = section, actor_user, actor_author) do
    metadata =
      telemetry_metadata(
        section,
        actor_user || linked_user_for(author: actor_author),
        actor_author
      )

    :telemetry.execute(@requested_event, %{count: 1}, metadata)

    FeatureTelemetry.span(
      :template_preview,
      "delivery",
      "prepare_launch",
      fn ->
        case do_prepare_launch(section, actor_user, actor_author) do
          {:ok, %{enrollment_outcome: outcome} = result} ->
            enriched = Map.put(metadata, :enrollment_outcome, outcome)

            :telemetry.execute(@enrollment_ensured_event, %{count: 1}, enriched)
            :telemetry.execute(@launch_succeeded_event, %{count: 1}, enriched)

            {:ok, result}

          {:error, reason} = error ->
            :telemetry.execute(
              @launch_failed_event,
              %{count: 1},
              Map.put(metadata, :error_category, to_string(reason))
            )

            error
        end
      end,
      metadata
    )
  end

  defp do_prepare_launch(
         %Section{type: :blueprint, status: :active} = section,
         actor_user,
         actor_author
       ) do
    with :ok <- authorize_author(actor_author, section),
         {:ok, linked_user} <- resolve_linked_delivery_identity(actor_user, actor_author),
         {:ok, %{outcome: outcome}} <-
           Sections.ensure_student_enrollment(linked_user.id, section.id) do
      {:ok, %{section_slug: section.slug, enrollment_outcome: outcome}}
    end
  end

  defp do_prepare_launch(_section, _actor_user, _actor_author), do: {:error, :section_unavailable}

  defp authorize_author(nil, _section), do: {:error, :unauthorized}

  defp authorize_author(%Author{} = author, %Section{} = section) do
    if Accounts.at_least_content_admin?(author) or
         Blueprint.is_author_of_blueprint?(section.slug, author.id) do
      :ok
    else
      {:error, :unauthorized}
    end
  end

  defp resolve_linked_delivery_identity(%User{author_id: author_id} = user, %Author{id: author_id}),
       do: {:ok, user}

  defp resolve_linked_delivery_identity(nil, %Author{id: author_id}) do
    case Accounts.get_user_by(author_id: author_id) do
      %User{} = user -> {:ok, user}
      _ -> {:error, :missing_delivery_identity}
    end
  end

  defp resolve_linked_delivery_identity(_user, _author), do: {:error, :missing_delivery_identity}

  defp telemetry_metadata(section, actor_user, actor_author) do
    %{
      section_id: section.id,
      section_slug: section.slug,
      product_id: section.id,
      user_id: actor_user && actor_user.id,
      author_id: actor_author && actor_author.id,
      tenant_id: section.institution_id
    }
  end

  defp linked_user_for(author: %Author{id: author_id}) do
    Accounts.get_user_by(author_id: author_id)
  end

  defp linked_user_for(author: _), do: nil
end
