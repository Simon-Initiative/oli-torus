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

  defmodule VerifyDirective do
    @moduledoc "Verifies the structure or resource properties of a project or section"
    defstruct [:to, :structure, :resource, :assertions]
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
