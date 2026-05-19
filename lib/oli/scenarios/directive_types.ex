defmodule Oli.Scenarios.DirectiveTypes do
  @moduledoc """
  Type definitions for the flexible course specification DSL.
  """

  # Directive types
  defmodule ProjectDirective do
    @moduledoc "Creates a new project with specified structure"
    defstruct [:name, :title, :root, :objectives, :tags, :slug, :visibility]
  end

  defmodule SectionDirective do
    @moduledoc "Creates a section from a project or standalone"
    defstruct [
      :name,
      :title,
      :from,
      :type,
      :registration_open,
      :slug,
      :open_and_free,
      :requires_enrollment
    ]
  end

  defmodule ProductDirective do
    @moduledoc """
    Creates a product (blueprint) from a project.
    Products are templates that can be used to create sections.
    """
    defstruct [:name, :title, :from]
  end

  defmodule RemixDirective do
    @moduledoc """
    Remix content from a source project into a section's container.
    from: source project name
    resource: page or container title to remix
    section: target section name to remix into
    to: target container title in the section where content will be added
    """
    defstruct [:from, :resource, :section, :to]
  end

  defmodule ManipulateDirective do
    @moduledoc "Applies operations to a project"
    defstruct [:to, :ops]
  end

  defmodule PublishDirective do
    @moduledoc "Publishes outstanding changes to a project"
    defstruct [:to, :description]
  end

  defmodule AssertDirective do
    @moduledoc "Asserts the structure, resource properties, progress, proficiency, or general assertions"
    defstruct [
      :structure,
      :resource,
      :progress,
      :proficiency,
      :certificate,
      :gating,
      :prologue,
      :gradebook,
      :review_attempt,
      :activity_attempt,
      :assertions
    ]
  end

  defmodule UserDirective do
    @moduledoc "Creates users (authors, instructors, students)"
    defstruct [
      :name,
      :type,
      :email,
      :given_name,
      :family_name,
      :password,
      :system_role,
      :can_create_sections,
      :email_verified
    ]
  end

  defmodule EnrollDirective do
    @moduledoc "Enrolls users in sections"
    defstruct [:user, :section, :role, :email]
  end

  defmodule InstitutionDirective do
    @moduledoc "Creates an institution"
    defstruct [:name, :country_code, :institution_email, :institution_url]
  end

  defmodule UpdateDirective do
    @moduledoc "Applies publication updates from a project to a section"
    defstruct [:from, :to]
  end

  defmodule CustomizeDirective do
    @moduledoc "Applies customization operations to a section's curriculum"
    defstruct [:to, :ops]
  end

  defmodule ActivityDirective do
    @moduledoc """
    Creates an activity from TorusDoc YAML content.
    project: target project name
    title: activity title for referencing
    virtual_id: optional scenario-local identifier for the activity
    scope: "embedded" or "banked"
    type: activity type slug (e.g. "oli_multiple_choice")
    content_format: "torusdoc" (default) or "json"
    content: TorusDoc activity YAML content
    objectives: optional list of objective titles to attach
    tags: optional list of tag titles to attach
    """
    defstruct [
      :project,
      :title,
      :virtual_id,
      :scope,
      :type,
      :content_format,
      :content,
      :objectives,
      :tags
    ]
  end

  defmodule EditPageDirective do
    @moduledoc """
    Edits an existing page's content from TorusDoc YAML.
    project: target project name
    page: title of the page to edit
    content: TorusDoc page YAML content
    """
    defstruct [:project, :page, :content]
  end

  defmodule ViewPracticePageDirective do
    @moduledoc """
    Simulates a student viewing a practice page in a section.
    student: name of the student user (as defined in user directive)
    section: name of the section
    page: title of the page to view
    """
    defstruct [:student, :section, :page]
  end

  defmodule VisitPageDirective do
    @moduledoc """
    Simulates a student visiting a page in a section.
    student: name of the student user (as defined in user directive)
    section: name of the section
    page: title of the page to visit
    """
    defstruct [:student, :section, :page]
  end

  defmodule StartAttemptDirective do
    @moduledoc """
    Starts a graded page attempt through shared delivery start-attempt policy.
    student: name of the student user
    section: name of the section
    page: title of the graded page
    password: optional assessment password
    expect: expected result, defaults to :started
    """
    defstruct [:student, :section, :page, :password, :expect]
  end

  defmodule GateDirective do
    @moduledoc """
    Creates a top-level gating condition or a student-specific exception.
    name: scenario-local gate identifier
    section: target section name
    target: title of the gated resource
    type: gating condition type
    source: optional source resource title for started/finished/progress gates
    start: optional start datetime for schedule gate
    end: optional end datetime for schedule gate
    minimum_percentage: optional threshold for finished/progress gates
    student: optional learner name for student-specific exceptions
    parent: optional parent gate name for student-specific exceptions
    graded_resource_policy: optional policy for graded resources
    """
    defstruct [
      :name,
      :section,
      :target,
      :type,
      :source,
      :start,
      :end,
      :minimum_percentage,
      :student,
      :parent,
      :graded_resource_policy
    ]
  end

  defmodule TimeDirective do
    @moduledoc """
    Sets the scenario-local current time for deterministic workflows.
    at: ISO8601 datetime string or parsed DateTime value
    """
    defstruct [:at]
  end

  defmodule WaitDirective do
    @moduledoc """
    Pauses scenario execution for real elapsed time.
    seconds: wait duration in seconds
    milliseconds: wait duration in milliseconds
    """
    defstruct [:seconds, :milliseconds]
  end

  defmodule AnswerQuestionDirective do
    @moduledoc """
    Simulates a student answering a question on a page.
    student: name of the student user (as defined in user directive)
    section: name of the section
    page: title of the page
    activity_virtual_id: virtual_id of the activity to answer
    response: the student's response (e.g., "b" for multiple choice)
    """
    defstruct [:student, :section, :page, :activity_virtual_id, :response]
  end

  defmodule CertificateDirective do
    @moduledoc """
    Configures certificate settings on a section or product.
    target: scenario name of the section/product
    enabled: whether certificate support is enabled on the target
    thresholds: nested threshold configuration
    design: nested certificate design fields
    """
    defstruct [:target, :enabled, :thresholds, :design]
  end

  defmodule DiscussionPostDirective do
    @moduledoc """
    Creates a discussion post for a student in a section.
    student: scenario user name
    section: scenario section name
    body: discussion post body
    """
    defstruct [:student, :section, :body]
  end

  defmodule ClassNoteDirective do
    @moduledoc """
    Creates a public class note for a student on a page in a section.
    student: scenario user name
    section: scenario section name
    page: title of the page being annotated
    body: note body
    """
    defstruct [:student, :section, :page, :body]
  end

  defmodule CompleteScoredPageDirective do
    @moduledoc """
    Records a scored page completion for a student in a section.
    student: scenario user name
    section: scenario section name
    page: title of the page being completed
    score: earned score
    out_of: total available score
    """
    defstruct [:student, :section, :page, :score, :out_of]
  end

  defmodule FinalizeAttemptDirective do
    @moduledoc """
    Finalizes a learner's active page attempt through the real page lifecycle.
    student: scenario user name
    section: scenario section name
    page: title of the page being finalized
    """
    defstruct [:student, :section, :page]
  end

  defmodule StudentExceptionDirective do
    @moduledoc """
    Creates, updates, or removes an assessment settings student exception.
    action: set or remove
    student: scenario user name
    section: scenario section name
    page: title of the assessment page
    set: optional settings overrides to apply
    """
    defstruct [:action, :student, :section, :page, :set]
  end

  defmodule CertificateActionDirective do
    @moduledoc """
    Applies an instructor certificate action for a student.
    instructor: scenario user name
    section: scenario section name
    student: scenario user name
    action: approve or deny
    """
    defstruct [:instructor, :section, :student, :action]
  end

  # Execution state
  defmodule ExecutionState do
    @moduledoc """
    Maintains state throughout directive execution.
    """
    # name -> BuiltProject
    defstruct projects: %{},
              # name -> Section  
              sections: %{},
              # name -> Product (Blueprint)
              products: %{},
              # name -> User/Author
              users: %{},
              # name -> Institution
              institutions: %{},
              # {project_name, activity_title} -> activity revision
              activities: %{},
              # {project_name, virtual_id} -> activity revision
              activity_virtual_ids: %{},
              # {user_name, section_name, page_title} -> AttemptState
              page_attempts: %{},
              # {user_name, section_name, page_title} -> FinalizationSummary
              finalized_attempts: %{},
              # {user_name, section_name, page_title, activity_virtual_id} -> evaluation result
              activity_evaluations: %{},
              # gate name -> GatingCondition
              gates: %{},
              # scenario-local current time
              scenario_time: nil,
              # Default author for operations
              current_author: nil,
              # Default institution
              current_institution: nil
  end

  # Result types
  defmodule ExecutionResult do
    @moduledoc """
    Result of executing a full specification file.
    """
    defstruct [:state, :verifications, :errors]
  end

  defmodule CloneDirective do
    @moduledoc """
    Clones an existing project to create a new project with the same structure.
    from: source project name to clone from
    name: name for the new cloned project
    title: optional title for the cloned project (defaults to source title with "Copy of" prefix)
    """
    defstruct [:from, :name, :title]
  end

  defmodule UseDirective do
    @moduledoc """
    Includes and executes another YAML scenario file within the current execution context.
    file: relative path to the YAML file to include (relative to the current file's directory)
    """
    defstruct [:file]
  end

  defmodule CollaboratorDirective do
    @moduledoc """
    Adds an existing author as a collaborator to an existing project.
    user: scenario name of the author
    project: scenario name of the project
    email: optional explicit email to resolve the author
    """
    defstruct [:user, :project, :email]
  end

  defmodule MediaDirective do
    @moduledoc """
    Uploads a media file into a project's media library.
    project: scenario name of the project
    path: file path (relative to scenario file if relative)
    mime: optional mime type override
    """
    defstruct [:project, :path, :mime]
  end

  defmodule BibliographyDirective do
    @moduledoc """
    Adds a bibliography entry to a project.
    project: scenario name of the project
    entry: bibtex or raw entry text
    """
    defstruct [:project, :entry]
  end

  defmodule HookDirective do
    @moduledoc """
    Executes a custom Elixir function with the current execution state.
    function: fully qualified module and function with arity (e.g., "Oli.Scenarios.Hooks.inject_bad_data/1")
    The function will receive the ExecutionState and must return an updated ExecutionState.
    """
    defstruct [:function]
  end

  defmodule VerificationResult do
    @moduledoc """
    Result of a verification directive.
    """
    defstruct [:to, :passed, :message, :expected, :actual]
  end

  # Enhanced BuiltProject with section tracking
  defmodule ExtendedBuiltProject do
    @moduledoc """
    Extended version of BuiltProject that tracks associated sections.
    """
    defstruct [:project, :working_pub, :root, :id_by_title, :rev_by_title, :sections]
  end
end
