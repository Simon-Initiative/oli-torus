defmodule Oli.InstructorDashboard.Email.EmailContext do
  @moduledoc """
  Normalized email-generation context assembled by `ContextBuilder` from
  dashboard entry points and consumed by the AI prompt composer + send pipeline.

  Field shape derives from existing tile projector `@type`s. See
  `docs/exec-plans/current/epics/intelligent_dashboard/email_sending/gaps.md`
  G-J03 for the source mapping.
  """

  alias Oli.InstructorDashboard.Email.Situation

  @enforce_keys [
    :section_id,
    :course_title,
    :instructor_name,
    :scope_label,
    :situation_key,
    :recipients,
    :tone,
    :recipient_count
  ]
  defstruct [
    :section_id,
    :course_title,
    :instructor_name,
    :scope_label,
    :situation_key,
    :recipients,
    :tone,
    :recipient_count,
    section_slug: nil,
    instructor_email: nil,
    assessment: nil,
    objective: nil,
    content_item: nil,
    support_bucket: nil
  ]

  @type recipient :: %{
          required(:student_id) => pos_integer(),
          required(:email) => String.t(),
          required(:given_name) => String.t() | nil,
          required(:family_name) => String.t() | nil,
          optional(:progress_pct) => number() | nil,
          optional(:proficiency_pct) => number() | nil,
          optional(:activity_status) => :active | :inactive | nil,
          optional(:last_interaction_at) => DateTime.t() | NaiveDateTime.t() | nil
        }

  @type assessment :: %{
          required(:title) => String.t(),
          optional(:available_at) => DateTime.t() | NaiveDateTime.t() | nil,
          optional(:due_at) => DateTime.t() | NaiveDateTime.t() | nil,
          optional(:completion_ratio) => float() | nil,
          optional(:completion_status) => :good | :bad | nil,
          optional(:mean_score) => number() | nil,
          optional(:median_score) => number() | nil,
          optional(:histogram) => list() | nil
        }

  @type objective :: %{
          required(:title) => String.t(),
          optional(:proficiency_label) => String.t() | nil,
          optional(:proficiency_distribution) => map() | nil
        }

  @type content_item :: %{
          required(:title) => String.t(),
          optional(:label) => String.t() | nil,
          optional(:resource_type) => atom() | nil
        }

  @type support_bucket :: %{
          required(:label) => String.t(),
          required(:count) => non_neg_integer(),
          optional(:active_count) => non_neg_integer(),
          optional(:inactive_count) => non_neg_integer()
        }

  @type tone :: :neutral | :encouraging | :firm

  @type t :: %__MODULE__{
          section_id: pos_integer(),
          course_title: String.t(),
          instructor_name: String.t(),
          section_slug: String.t() | nil,
          instructor_email: String.t() | nil,
          scope_label: String.t(),
          situation_key: Situation.t(),
          recipients: [recipient()],
          tone: tone(),
          recipient_count: non_neg_integer(),
          assessment: assessment() | nil,
          objective: objective() | nil,
          content_item: content_item() | nil,
          support_bucket: support_bucket() | nil
        }
end
