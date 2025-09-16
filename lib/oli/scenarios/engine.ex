defmodule Oli.Scenarios.Engine do
  @moduledoc """
  Execution engine for processing course specification directives.
  Maintains state across directive execution and coordinates handlers.
  """

  alias Oli.Scenarios.DirectiveTypes.{
    ExecutionState,
    ExecutionResult,
    ProjectDirective,
    CloneDirective,
    SectionDirective,
    ProductDirective,
    RemixDirective,
    ManipulateDirective,
    PublishDirective,
    AssertDirective,
    UserDirective,
    EnrollDirective,
    InstitutionDirective,
    UpdateDirective,
    CustomizeDirective,
    ActivityDirective,
    EditPageDirective,
    ViewPracticePageDirective,
    AnswerQuestionDirective,
    UseDirective,
    HookDirective
  }

  alias Oli.Scenarios.Directives.{
    ProjectHandler,
    CloneHandler,
    SectionHandler,
    ProductHandler,
    RemixHandler,
    ManipulateHandler,
    PublishHandler,
    AssertHandler,
    UserHandler,
    EnrollmentHandler,
    InstitutionHandler,
    UpdateHandler,
    CustomizeHandler,
    ActivityHandler,
    EditPageHandler,
    ViewPracticePageHandler,
    AnswerQuestionHandler,
    UseHandler,
    HookHandler
  }

  @doc """
  Executes a list of directives sequentially, maintaining state throughout.
  Returns an ExecutionResult with final state and any verification results.
  """
  def execute(directives, opts \\ []) when is_list(directives) do
    initial_state = initialize_state(opts)

    {final_state, verifications, errors} =
      Enum.reduce(directives, {initial_state, [], []}, fn directive, {state, verifs, errs} ->
        case execute_directive(directive, state) do
          {:ok, new_state} ->
            {new_state, verifs, errs}

          {:ok, new_state, verification} ->
            {new_state, [verification | verifs], errs}

          {:error, reason} ->
            {state, verifs, [{directive, reason} | errs]}
        end
      end)

    %ExecutionResult{
      state: final_state,
      verifications: Enum.reverse(verifications),
      errors: Enum.reverse(errors)
    }
  end

  @doc """
  Executes a single YAML file containing directives.
  """
  def execute_file(yaml_path, opts \\ []) do
    # Add the file's directory to opts so 'use' directives can resolve relative paths
    dir = Path.dirname(Path.expand(yaml_path))
    opts_with_dir = Keyword.put(opts, :current_dir, dir)

    yaml_path
    |> Oli.Scenarios.DirectiveParser.load_file!()
    |> execute(opts_with_dir)
  end

  # Initialize execution state with defaults
  defp initialize_state(opts) do
    # If a complete state is provided, use it
    case opts[:state] do
      %ExecutionState{} = state ->
        # Add current_dir if provided
        if opts[:current_dir] do
          Map.put(state, :current_dir, opts[:current_dir])
        else
          state
        end

      nil ->
        # Use provided author or create a default one
        author = opts[:author] || create_default_author()

        # Use provided institution or create a default one
        institution = opts[:institution] || create_default_institution()

        base_state = %ExecutionState{
          projects: %{},
          sections: %{},
          products: %{},
          users: %{"default_author" => author},
          institutions: %{"default" => institution},
          activities: %{},
          activity_virtual_ids: %{},
          page_attempts: %{},
          activity_evaluations: %{},
          current_author: author,
          current_institution: institution
        }

        # Add current_dir if provided
        if opts[:current_dir] do
          Map.put(base_state, :current_dir, opts[:current_dir])
        else
          base_state
        end
    end
  end

  defp create_default_author do
    # Use production API to create an author
    alias Oli.Accounts.Author
    alias Oli.Repo

    {:ok, author} =
      %Author{}
      |> Author.registration_changeset(%{
        email: "author_#{System.unique_integer([:positive])}@example.com",
        given_name: "Default",
        family_name: "Author",
        password: "temporarypassword123",
        password_confirmation: "temporarypassword123"
      })
      |> Author.noauth_changeset(%{
        email: "author_#{System.unique_integer([:positive])}@example.com",
        given_name: "Default",
        family_name: "Author"
      })
      |> Repo.insert()

    author
  end

  defp create_default_institution do
    {:ok, institution} =
      Oli.Institutions.create_institution(%{
        name: "Default Institution #{System.unique_integer([:positive])}",
        institution_email: "admin@institution.edu",
        country_code: "US",
        institution_url: "http://institution.edu"
      })

    institution
  end

  # Execute individual directives
  @doc false
  def execute_directive(%UseDirective{} = directive, state) do
    UseHandler.handle(directive, state)
  end

  def execute_directive(%ProjectDirective{} = directive, state) do
    ProjectHandler.handle(directive, state)
  end

  def execute_directive(%CloneDirective{} = directive, state) do
    CloneHandler.handle(directive, state)
  end

  def execute_directive(%SectionDirective{} = directive, state) do
    SectionHandler.handle(directive, state)
  end

  def execute_directive(%ProductDirective{} = directive, state) do
    ProductHandler.handle(directive, state)
  end

  def execute_directive(%RemixDirective{} = directive, state) do
    RemixHandler.handle(directive, state)
  end

  def execute_directive(%ManipulateDirective{} = directive, state) do
    ManipulateHandler.handle(directive, state)
  end

  def execute_directive(%PublishDirective{} = directive, state) do
    PublishHandler.handle(directive, state)
  end

  def execute_directive(%AssertDirective{} = directive, state) do
    AssertHandler.handle(directive, state)
  end

  def execute_directive(%UserDirective{} = directive, state) do
    UserHandler.handle(directive, state)
  end

  def execute_directive(%EnrollDirective{} = directive, state) do
    EnrollmentHandler.handle(directive, state)
  end

  def execute_directive(%InstitutionDirective{} = directive, state) do
    InstitutionHandler.handle(directive, state)
  end

  def execute_directive(%UpdateDirective{} = directive, state) do
    UpdateHandler.handle(directive, state)
  end

  def execute_directive(%CustomizeDirective{} = directive, state) do
    CustomizeHandler.handle(directive, state)
  end

  def execute_directive(%ActivityDirective{} = directive, state) do
    ActivityHandler.handle(directive, state)
  end

  def execute_directive(%EditPageDirective{} = directive, state) do
    EditPageHandler.handle(directive, state)
  end

  def execute_directive(%ViewPracticePageDirective{} = directive, state) do
    ViewPracticePageHandler.handle(directive, state)
  end

  def execute_directive(%AnswerQuestionDirective{} = directive, state) do
    AnswerQuestionHandler.handle(directive, state)
  end

  def execute_directive(%HookDirective{} = directive, state) do
    HookHandler.handle(directive, state)
  end

  # Handle lists of directives (from complex parsing)
  def execute_directive(directives, state) when is_list(directives) do
    Enum.reduce_while(directives, {:ok, state}, fn directive, {:ok, acc_state} ->
      case execute_directive(directive, acc_state) do
        {:ok, new_state} -> {:cont, {:ok, new_state}}
        {:ok, new_state, _verification} -> {:cont, {:ok, new_state}}
        error -> {:halt, error}
      end
    end)
  end

  # Helper functions for accessing state

  @doc """
  Gets a project from the state by name.
  """
  def get_project(state, name) do
    Map.get(state.projects, name)
  end

  @doc """
  Gets a section from the state by name.
  """
  def get_section(state, name) do
    Map.get(state.sections, name)
  end

  @doc """
  Gets a product from the state by name.
  """
  def get_product(state, name) do
    Map.get(state.products, name)
  end

  @doc """
  Gets a user from the state by name.
  """
  def get_user(state, name) do
    Map.get(state.users, name)
  end

  @doc """
  Gets an institution from the state by name.
  """
  def get_institution(state, name) do
    Map.get(state.institutions, name)
  end

  @doc """
  Upserts a project by name into the state.
  """
  def put_project(state, name, project) do
    %{state | projects: Map.put(state.projects, name, project)}
  end

  @doc """
  Upserts a section by name into the state.
  """
  def put_section(state, name, section) do
    %{state | sections: Map.put(state.sections, name, section)}
  end

  @doc """
  Upserts a product by name into the state.
  """
  def put_product(state, name, product) do
    %{state | products: Map.put(state.products, name, product)}
  end

  @doc """
  Upserts a user by name into the state.
  """
  def put_user(state, name, user) do
    %{state | users: Map.put(state.users, name, user)}
  end

  @doc """
  Upserts an institution by name in the state.
  """
  def put_institution(state, name, institution) do
    %{state | institutions: Map.put(state.institutions, name, institution)}
  end
end
