defmodule Oli.InstructorDashboard.StudentSupportParameters do
  @moduledoc """
  Service boundary for section-scoped Student Support parameter settings.
  """

  require Logger

  alias Oli.InstructorDashboard.StudentSupportParameterSettings
  alias Oli.Repo
  alias Appsignal

  @save_failure_metric "oli.instructor_dashboard.student_support_parameters.save_failure"

  @default_settings %{
    inactivity_days: 7,
    struggling_progress_low_lt: 40,
    struggling_progress_high_gt: 80,
    struggling_proficiency_lte: 40,
    excelling_progress_gte: 80,
    excelling_proficiency_gte: 80
  }

  @type settings :: %{
          inactivity_days: integer(),
          struggling_progress_low_lt: integer(),
          struggling_progress_high_gt: integer(),
          struggling_proficiency_lte: integer(),
          excelling_progress_gte: integer(),
          excelling_proficiency_gte: integer()
        }

  @doc """
  Returns the built-in Student Support parameter defaults.
  """
  @spec default_settings() :: settings()
  def default_settings, do: @default_settings

  @doc """
  Resolves active settings for a section without creating a row for defaults.
  """
  @spec get_active_settings(integer() | term()) :: settings()
  def get_active_settings(section_id) when is_integer(section_id) do
    case Repo.get_by(StudentSupportParameterSettings, section_id: section_id) do
      nil -> default_settings()
      settings -> to_settings(settings)
    end
  end

  def get_active_settings(_section_id), do: default_settings()

  @doc """
  Validates and upserts Student Support settings for a section.
  """
  @spec save_for_section(integer(), map(), term()) ::
          {:ok, settings()} | {:error, Ecto.Changeset.t()}
  def save_for_section(section_id, attrs, actor \\ nil)
      when is_integer(section_id) and is_map(attrs) do
    timestamp = DateTime.utc_now() |> DateTime.truncate(:second)

    changeset =
      StudentSupportParameterSettings.changeset_for_section(
        %StudentSupportParameterSettings{},
        section_id,
        attrs
      )

    result =
      Repo.insert(
        changeset,
        conflict_target: [:section_id],
        on_conflict: [set: upsert_updates(changeset, timestamp)],
        returning: true
      )

    case result do
      {:ok, settings} ->
        {:ok, to_settings(settings)}

      {:error, changeset} ->
        track_save_failure(section_id, actor, changeset)
        {:error, changeset}
    end
  end

  @doc """
  Converts settings into `StudentSupport.Projector.build/3` options.
  """
  @spec to_projector_opts(settings() | StudentSupportParameterSettings.t()) :: keyword()
  def to_projector_opts(%StudentSupportParameterSettings{} = settings) do
    settings
    |> to_settings()
    |> to_projector_opts()
  end

  def to_projector_opts(settings) when is_map(settings) do
    settings =
      default_settings()
      |> Map.merge(atomize_settings(settings))
      |> sync_shared_progress_threshold()

    [
      inactivity_days: settings.inactivity_days,
      rules: %{
        struggling: %{
          any: [
            {:progress, :lt, settings.struggling_progress_low_lt},
            {:progress, :gt, settings.struggling_progress_high_gt}
          ],
          all: [{:proficiency, :lte, settings.struggling_proficiency_lte}]
        },
        excelling: %{
          any: [],
          all: [
            {:progress, :gte, settings.excelling_progress_gte},
            {:proficiency, :gte, settings.excelling_proficiency_gte}
          ]
        },
        on_track: %{
          any: [],
          all: [
            {:progress, :gte, settings.struggling_progress_low_lt},
            {:proficiency, :gte, settings.struggling_proficiency_lte}
          ]
        }
      }
    ]
  end

  defp to_settings(%StudentSupportParameterSettings{} = settings) do
    settings
    |> Map.from_struct()
    |> Map.take(Map.keys(@default_settings))
  end

  defp atomize_settings(settings) do
    Enum.reduce(@default_settings, %{}, fn {field, default}, acc ->
      Map.put(
        acc,
        field,
        Map.get(settings, field, Map.get(settings, Atom.to_string(field), default))
      )
    end)
  end

  defp sync_shared_progress_threshold(settings) do
    shared_value = settings.excelling_progress_gte

    settings
    |> Map.put(:excelling_progress_gte, shared_value)
    |> Map.put(:struggling_progress_high_gt, shared_value)
  end

  defp upsert_updates(changeset, timestamp) do
    settings =
      Enum.map(@default_settings, fn {field, _default} ->
        {field, Ecto.Changeset.get_field(changeset, field)}
      end)

    [updated_at: timestamp] ++ settings
  end

  defp track_save_failure(section_id, actor, changeset) do
    Logger.debug(
      "Failed to persist student support parameter settings",
      section_id: section_id,
      actor_id: actor_id(actor),
      errors: inspect(changeset.errors)
    )

    Appsignal.increment_counter(@save_failure_metric, 1, %{source: "instructor_dashboard"})
  end

  defp actor_id(%{id: id}), do: id
  defp actor_id(_actor), do: nil
end
