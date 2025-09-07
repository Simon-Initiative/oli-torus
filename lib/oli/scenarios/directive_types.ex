defmodule Oli.Scenarios.DirectiveTypes do
  @moduledoc """
  Type definitions for the flexible course specification DSL.
  """

  # Directive types
  defmodule ProjectDirective do
    @moduledoc "Creates a new project with specified structure"
    defstruct [:name, :title, :root, :objectives, :tags]
  end

  defmodule SectionDirective do
    @moduledoc "Creates a section from a project or standalone"
    defstruct [:name, :title, :from, :type, :registration_open]
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
    defstruct [:structure, :resource, :progress, :proficiency, :assertions]
  end

  defmodule UserDirective do
    @moduledoc "Creates users (authors, instructors, students)"
    defstruct [:name, :type, :email, :given_name, :family_name]
  end

  defmodule EnrollDirective do
    @moduledoc "Enrolls users in sections"
    defstruct [:user, :section, :role]
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
    content: TorusDoc activity YAML content
    objectives: optional list of objective titles to attach
    tags: optional list of tag titles to attach
    """
    defstruct [:project, :title, :virtual_id, :scope, :type, :content, :objectives, :tags]
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
              # {user_name, section_name, page_title, activity_virtual_id} -> evaluation result
              activity_evaluations: %{},
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
