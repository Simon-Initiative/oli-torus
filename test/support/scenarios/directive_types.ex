defmodule Oli.Scenarios.DirectiveTypes do
  @moduledoc """
  Type definitions for the flexible course specification DSL.
  """

  # Directive types
  defmodule ProjectDirective do
    @moduledoc "Creates a new project with specified structure"
    defstruct [:name, :title, :root]
  end

  defmodule SectionDirective do
    @moduledoc "Creates a section from a project or standalone"
    defstruct [:name, :title, :from, :type, :registration_open]
  end

  defmodule RemixDirective do
    @moduledoc "Remixes content from source to target"
    defstruct [:source, :target, :resource, :into, :position]
  end

  defmodule PublishChangesDirective do
    @moduledoc "Publishes changes to a project"
    defstruct [:target, :ops, :description]
  end

  defmodule VerifyDirective do
    @moduledoc "Verifies the structure of a project or section"
    defstruct [:target, :structure, :assertions]
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

  # Execution state
  defmodule ExecutionState do
    @moduledoc """
    Maintains state throughout directive execution.
    """
    defstruct projects: %{},           # name -> BuiltProject
              sections: %{},           # name -> Section  
              users: %{},             # name -> User/Author
              institutions: %{},      # name -> Institution
              current_author: nil,     # Default author for operations
              current_institution: nil # Default institution
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
    defstruct [:target, :passed, :message, :expected, :actual]
  end

  # Enhanced BuiltProject with section tracking
  defmodule ExtendedBuiltProject do
    @moduledoc """
    Extended version of BuiltProject that tracks associated sections.
    """
    defstruct [:project, :working_pub, :root, :id_by_title, :rev_by_title, :sections]
  end
end