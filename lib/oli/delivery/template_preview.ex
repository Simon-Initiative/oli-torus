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
          {:ok,
           %{
             section_slug: String.t(),
             launch_identity: :current_user | :hidden_instructor,
             enrollment_outcome: :created | :reused | nil,
             hidden_instructor_outcome: :created | :reused | nil
           }}
          | {:error, atom()}
  def prepare_launch(%Section{} = section, actor_user, actor_author) do
    metadata = telemetry_metadata(section, actor_user, actor_author)

    :telemetry.execute(@requested_event, %{count: 1}, metadata)

    FeatureTelemetry.span(
      :template_preview,
      "delivery",
      "prepare_launch",
      fn ->
        case do_prepare_launch(section, actor_user, actor_author) do
          {:ok, result} ->
            enriched =
              metadata
              |> Map.put(:user_id, result.user_id)
              |> Map.put(:launch_identity, to_string(result.launch_identity))
              |> Map.put(:enrollment_outcome, result.enrollment_outcome)
              |> Map.put(:hidden_instructor_outcome, result.hidden_instructor_outcome)

            :telemetry.execute(@enrollment_ensured_event, %{count: 1}, enriched)
            :telemetry.execute(@launch_succeeded_event, %{count: 1}, enriched)

            {:ok, Map.drop(result, [:user_id])}

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
    with :ok <- authorize_author(actor_author, section) do
      case resolve_launch_identity(actor_user, actor_author) do
        {:ok, {:current_user, %User{} = user}} ->
          with {:ok, %{outcome: outcome}} <-
                 Sections.ensure_student_enrollment(user.id, section.id) do
            {:ok,
             %{
               section_slug: section.slug,
               launch_identity: :current_user,
               enrollment_outcome: outcome,
               hidden_instructor_outcome: nil,
               user_id: user.id
             }}
          end

        {:ok, :hidden_instructor} ->
          with {:ok, %{user: user, outcome: outcome}} <-
                 Sections.ensure_hidden_instructor(section.id) do
            {:ok,
             %{
               section_slug: section.slug,
               launch_identity: :hidden_instructor,
               enrollment_outcome: nil,
               hidden_instructor_outcome: outcome,
               user_id: user.id
             }}
          end

        error ->
          error
      end
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

  defp resolve_launch_identity(%User{hidden: true}, %Author{}), do: {:ok, :hidden_instructor}

  defp resolve_launch_identity(%User{} = user, %Author{}), do: {:ok, {:current_user, user}}

  defp resolve_launch_identity(nil, %Author{}), do: {:ok, :hidden_instructor}

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
end
