defmodule Oli.Scenarios.Sections.CourseSectionHooks do
  @moduledoc """
  Scenario hooks that intentionally corrupt course section related data to ensure
  section creation tolerates malformed inputs.
  """

  alias Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  import ExUnit.Assertions

  alias Oli.Publishing.{AuthoringResolver, DeliveryResolver}
  alias Oli.Delivery.Sections.{Section, SectionResource}
  alias Oli.Repo
  alias Oli.Resources.{PageContent, Resource, Revision}
  alias Oli.Scenarios.DirectiveTypes.ExecutionState
  alias Oli.Scenarios.Engine

  require Logger

  @practice_page_a "Practice Page A"
  @practice_page_b "Practice Page B"
  @unit_title "Unit 1"
  @product_nil_child "nil_child_product"

  @doc """
  Replaces the first activity reference on Practice Page A with a bogus resource id.
  """
  def inject_missing_activity_reference(%ExecutionState{} = state) do
    mutate_page_content(
      state,
      @practice_page_a,
      "replace activity with missing resource id",
      fn content ->
        replace_first_activity_reference(content, fn ref ->
          bogus_id = generate_missing_resource_id()

          ref
          |> put_activity_reference_id(bogus_id)
          |> put_activity_reference_resource_id(bogus_id)
        end)
      end
    )
  end

  @doc """
  Marks the activity referenced on Practice Page B as deleted.
  """
  def mark_activity_revision_deleted(%ExecutionState{} = state) do
    with {:ok, project_name, built_project} <- select_project(state),
         {:ok, page_revision} <- fetch_revision_by_title(built_project, @practice_page_b),
         {:ok, activity_id} <- first_activity_id(built_project, page_revision.content),
         {:ok, activity_revision} <- fresh_revision(project_slug(built_project), activity_id),
         {:ok, updated_revision} <-
           persist_revision(project_slug(built_project), activity_revision, %{deleted: true}),
         true <- ensure_same_resource(activity_id, updated_revision.resource_id),
         {:ok, updated_project} <- refresh_project_resource(built_project, updated_revision) do
      Logger.info(
        "Marked activity revision #{updated_revision.id} referenced by #{@practice_page_b} as deleted"
      )

      Engine.put_project(state, project_name, updated_project)
    else
      {:error, reason} ->
        flunk("mark_activity_revision_deleted failed: #{inspect(reason)}")
        state

      false ->
        flunk(
          "mark_activity_revision_deleted failed: #{@practice_page_b} is not linked to the expected activity revision"
        )

        state

      error ->
        Logger.warning(
          "Course section hook mark_activity_revision_deleted encountered unexpected result: #{inspect(error)}"
        )

        state
    end
  end

  @doc """
  Inserts a `nil` entry into Unit 1's children array.
  """
  def insert_nil_child(%ExecutionState{} = state) do
    mutate_unit_children(state, @unit_title, "insert nil child entry", fn children ->
      case children do
        [] -> {:error, :no_children}
        [_ | _] = current_children -> {:ok, current_children ++ [nil]}
      end
    end)
  end

  @doc """
  Inserts a nonexistent resource id into Unit 1's children array.
  """
  def insert_missing_child(%ExecutionState{} = state) do
    mutate_unit_children(state, @unit_title, "insert missing resource child", fn children ->
      case children do
        [] ->
          {:error, :no_children}

        [_ | _] = current_children ->
          bogus_id = generate_missing_resource_id()
          {:ok, current_children ++ [bogus_id]}
      end
    end)
  end

  @doc """
  Inserts a `nil` entry into the product's root section resource children array.
  """
  def insert_nil_child_in_product_root(%ExecutionState{} = state) do
    mutate_product_root_children(
      state,
      @product_nil_child,
      "insert nil child entry into product root",
      fn
        [] -> {:error, :no_children}
        [_ | _] = current_children -> {:ok, current_children ++ [nil]}
      end
    )
  end

  @doc """
  Validates that Practice Page A contains an activity reference pointing to a missing resource.
  """
  def assert_missing_activity_reference(%ExecutionState{} = state) do
    with {:ok, _project_name, built_project} <- select_project(state),
         {:ok, page_revision} <- fetch_revision_by_title(built_project, @practice_page_a),
         {:ok, activity_id} <- first_activity_id(built_project, page_revision.content) do
      assert is_nil(AuthoringResolver.from_resource_id(project_slug(built_project), activity_id)),
             "Expected missing activity reference on #{@practice_page_a}, but resource #{activity_id} exists"

      state
    else
      {:error, reason} ->
        flunk("assert_missing_activity_reference failed: #{inspect(reason)}")
    end
  end

  @doc """
  Validates that the activity referenced on Practice Page B has been marked deleted.
  """
  def assert_deleted_activity_reference(%ExecutionState{} = state) do
    with {:ok, _project_name, built_project} <- select_project(state),
         {:ok, page_revision} <- fetch_revision_by_title(built_project, @practice_page_b),
         {:ok, activity_id} <- first_activity_id(built_project, page_revision.content),
         {:ok, revision} <- fresh_revision(project_slug(built_project), activity_id) do
      assert revision.deleted == true,
             "Expected activity #{activity_id} referenced by #{@practice_page_b} to be marked deleted"

      state
    else
      {:error, reason} ->
        flunk("assert_deleted_activity_reference failed: #{inspect(reason)}")
    end
  end

  @doc """
  Ensures Unit 1 retains a nil child entry while keeping both practice pages accessible.
  """
  def assert_nil_child_structure(%ExecutionState{} = state) do
    with {:ok, _project_name, built_project} <- select_project(state),
         {:ok, unit_revision} <- fetch_revision_by_title(built_project, @unit_title) do
      statuses = child_statuses(project_slug(built_project), unit_revision.children)

      assert Enum.any?(statuses, &match?({nil, _}, &1)),
             "Expected Unit 1 to include a nil child entry"

      assert titles_from_statuses(statuses) == [@practice_page_a, @practice_page_b],
             "Unexpected Unit 1 children after nil insertion: #{inspect(statuses)}"

      state
    else
      {:error, reason} ->
        flunk("assert_nil_child_structure failed: #{inspect(reason)}")
    end
  end

  @doc """
  Ensures Unit 1 contains a child entry referencing a nonexistent resource id.
  """
  def assert_missing_child_structure(%ExecutionState{} = state) do
    with {:ok, _project_name, built_project} <- select_project(state),
         {:ok, unit_revision} <- fetch_revision_by_title(built_project, @unit_title) do
      statuses = child_statuses(project_slug(built_project), unit_revision.children)

      assert Enum.any?(statuses, &match?({:missing, _}, &1)),
             "Expected Unit 1 to include a missing resource child entry"

      assert titles_from_statuses(statuses) == [@practice_page_a, @practice_page_b],
             "Unexpected Unit 1 children after missing entry insertion: #{inspect(statuses)}"

      state
    else
      {:error, reason} ->
        flunk("assert_missing_child_structure failed: #{inspect(reason)}")
    end
  end

  @doc """
  Ensures the product root contains a nil child entry while keeping Unit 1 accessible.
  """
  def assert_product_nil_child_structure(%ExecutionState{} = state) do
    with {:ok, _product_name, product} <- select_product(state, @product_nil_child),
         {:ok, root_section_resource} <- fetch_root_section_resource(product) do
      statuses = section_child_statuses(product.slug, root_section_resource.children)

      assert Enum.any?(statuses, &match?({nil, _}, &1)),
             "Expected product root to include a nil child entry"

      state
    else
      {:error, reason} ->
        flunk("assert_product_nil_child_structure failed: #{inspect(reason)}")
    end
  end

  defp mutate_page_content(%ExecutionState{} = state, page_title, action, transform_fn) do
    with {:ok, project_name, built_project} <- select_project(state),
         {:ok, page_revision} <- fetch_revision_by_title(built_project, page_title),
         {:ok, updated_content} <- transform_fn.(page_revision.content),
         {:ok, refreshed_revision} <-
           persist_revision(project_slug(built_project), page_revision, %{
             content: updated_content
           }),
         {:ok, updated_project} <- refresh_project(built_project, page_title, refreshed_revision) do
      Logger.info("Scenario hook #{inspect(__MODULE__)}: #{action} on #{page_title}")

      Engine.put_project(state, project_name, updated_project)
    else
      {:error, reason} ->
        flunk("mutate_page_content failed for #{page_title}: #{inspect(reason)}")
        state

      error ->
        Logger.warning(
          "Scenario hook #{inspect(__MODULE__)} failed to #{action} on #{page_title}: #{inspect(error)}"
        )

        state
    end
  end

  defp mutate_unit_children(%ExecutionState{} = state, unit_title, action, transform_fn) do
    with {:ok, project_name, built_project} <- select_project(state),
         {:ok, unit_revision} <- fetch_revision_by_title(built_project, unit_title),
         {:ok, mutated_children} <- transform_fn.(unit_revision.children || []),
         {:ok, refreshed_revision} <-
           persist_revision(project_slug(built_project), unit_revision, %{
             children: mutated_children
           }),
         {:ok, updated_project} <- refresh_project(built_project, unit_title, refreshed_revision) do
      Logger.info("Scenario hook #{inspect(__MODULE__)}: #{action} in #{unit_title}")

      Engine.put_project(state, project_name, updated_project)
    else
      {:error, reason} ->
        flunk("mutate_unit_children failed for #{unit_title}: #{inspect(reason)}")
        state

      error ->
        Logger.warning(
          "Scenario hook #{inspect(__MODULE__)} failed to #{action}: #{inspect(error)}"
        )

        state
    end
  end

  defp mutate_product_root_children(%ExecutionState{} = state, product_name, action, transform_fn) do
    with {:ok, product_name, product} <- select_product(state, product_name),
         {:ok, root_section_resource} <- fetch_root_section_resource(product),
         {:ok, mutated_children} <- transform_fn.(root_section_resource.children || []),
         {:ok, _updated_root} <-
           persist_section_resource(root_section_resource, %{children: mutated_children}),
         {:ok, refreshed_product} <- refresh_product_section(product) do
      Logger.info("Scenario hook #{inspect(__MODULE__)}: #{action} for product #{product_name}")

      Engine.put_product(state, product_name, refreshed_product)
    else
      {:error, reason} ->
        flunk("mutate_product_root_children failed for #{product_name}: #{inspect(reason)}")
        state

      error ->
        Logger.warning(
          "Scenario hook #{inspect(__MODULE__)} failed to #{action} for product #{product_name}: #{inspect(error)}"
        )

        state
    end
  end

  defp replace_first_activity_reference(content, mutator) do
    {updated_content, status} =
      PageContent.map_reduce(content, :pending, fn element, status, _context ->
        cond do
          status == :done ->
            {element, status}

          match?(%{"type" => "activity-reference"}, element) ->
            {mutator.(element), :done}

          true ->
            {element, status}
        end
      end)

    case status do
      :done -> {:ok, updated_content}
      :pending -> {:error, :no_activity_reference_found}
    end
  end

  defp first_activity_id(built_project, content) do
    content
    |> PageContent.flat_filter(fn
      %{"type" => "activity-reference"} = ref ->
        not is_nil(fetch_activity_reference_id(ref, built_project))

      _ ->
        false
    end)
    |> case do
      [] ->
        {:error, :no_activity_reference_found}

      [ref | _] ->
        case fetch_activity_reference_id(ref, built_project) do
          nil -> {:error, :no_activity_reference_found}
          activity_id -> {:ok, activity_id}
        end
    end
  end

  defp persist_revision(project_slug, %Revision{} = revision, attrs) when is_map(attrs) do
    Repo.transaction(fn ->
      revision
      |> Changeset.change(attrs)
      |> Repo.update!()
    end)
    |> case do
      {:ok, _updated_revision} ->
        case AuthoringResolver.from_resource_id(project_slug, revision.resource_id) do
          nil -> {:error, {:revision_not_found_after_update, revision.resource_id}}
          refreshed_revision -> {:ok, refreshed_revision}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp persist_section_resource(%SectionResource{} = section_resource, attrs)
       when is_map(attrs) do
    Repo.transaction(fn ->
      section_resource
      |> Changeset.change(attrs)
      |> Repo.update!()
    end)
    |> case do
      {:ok, updated_section_resource} -> {:ok, updated_section_resource}
      {:error, error} -> {:error, error}
    end
  end

  defp refresh_project_resource(built_project, %Revision{} = revision) do
    title = revision.title
    refresh_project(built_project, title, revision)
  end

  defp refresh_product_section(%Section{} = product) do
    case Repo.get(Section, product.id) do
      nil -> {:error, {:section_not_found, product.id}}
      refreshed -> {:ok, refreshed}
    end
  end

  defp select_project(%ExecutionState{projects: projects}) when map_size(projects) >= 1 do
    Enum.at(projects, 0)
    |> case do
      {name, built_project} -> {:ok, name, built_project}
      _ -> {:error, :unexpected_project_structure}
    end
  end

  defp select_project(_state), do: {:error, :no_projects}

  defp select_product(%ExecutionState{products: products}, product_name)
       when is_binary(product_name) do
    case Map.get(products, product_name) do
      nil -> {:error, {:unknown_product, product_name}}
      product -> {:ok, product_name, product}
    end
  end

  defp select_product(%ExecutionState{products: products}, nil) when map_size(products) >= 1 do
    Enum.at(products, 0)
    |> case do
      {name, product} -> {:ok, name, product}
      _ -> {:error, :unexpected_product_structure}
    end
  end

  defp select_product(_state, _product_name), do: {:error, :no_products}

  defp fetch_revision_by_title(built_project, title) do
    cond do
      title == root_title(built_project) ->
        fetch_root_revision(built_project)

      true ->
        case Map.get(built_project.id_by_title, title) do
          nil -> {:error, {:unknown_title, title}}
          resource_id -> fresh_revision(project_slug(built_project), resource_id)
        end
    end
  end

  defp fetch_root_revision(built_project) do
    fresh_revision(project_slug(built_project), built_project.root.revision.resource_id)
  end

  defp fetch_root_section_resource(%Section{} = product) do
    case product.root_section_resource_id do
      nil ->
        {:error, :no_root_section_resource}

      section_resource_id ->
        case Repo.get(SectionResource, section_resource_id) do
          nil -> {:error, {:section_resource_not_found, section_resource_id}}
          section_resource -> {:ok, section_resource}
        end
    end
  end

  defp fresh_revision(project_slug, resource_id) when is_integer(resource_id) do
    case AuthoringResolver.from_resource_id(project_slug, resource_id) do
      nil -> {:error, {:revision_not_found, resource_id}}
      revision -> {:ok, revision}
    end
  end

  defp fresh_revision(_project_slug, nil), do: {:error, :nil_resource_id}

  defp refresh_project(built_project, title, %Revision{} = updated_revision) do
    updated_rev_by_title = Map.put(built_project.rev_by_title, title, updated_revision)

    {updated_rev_by_title, updated_root} =
      if root_revision?(built_project, updated_revision) || title == root_title(built_project) do
        {
          Map.put(updated_rev_by_title, "root", updated_revision),
          %{built_project.root | revision: updated_revision}
        }
      else
        {updated_rev_by_title, built_project.root}
      end

    {:ok, %{built_project | rev_by_title: updated_rev_by_title, root: updated_root}}
  end

  defp root_revision?(built_project, %Revision{} = revision) do
    built_project.root.revision.resource_id == revision.resource_id
  end

  defp root_title(built_project), do: built_project.root.revision.title

  defp project_slug(built_project), do: built_project.project.slug

  defp generate_missing_resource_id do
    current_max = Repo.one(from r in Resource, select: max(r.id)) || 0
    current_max + 1_000_000
  end

  defp put_activity_reference_id(ref, value) do
    ref
    |> Map.put("activity_id", value)
    |> Map.put("activityId", value)
  end

  defp put_activity_reference_resource_id(ref, value) do
    ref
    |> Map.put("resource_id", value)
    |> Map.put("resourceId", value)
  end

  defp fetch_activity_reference_id(ref, built_project) do
    case Enum.reduce_while(
           ["activity_id", "activityId", "resource_id", "resourceId"],
           nil,
           fn key, _acc ->
             case Map.get(ref, key) do
               nil -> {:cont, nil}
               value -> {:halt, normalize_resource_id(value)}
             end
           end
         ) do
      nil -> fetch_activity_id_from_slug(ref, built_project)
      value -> value
    end
  end

  defp fetch_activity_id_from_slug(ref, built_project) do
    slug =
      ["activity_slug", "activitySlug", "slug", "activitySlugId"]
      |> Enum.reduce_while(nil, fn key, _acc ->
        case Map.get(ref, key) do
          nil -> {:cont, nil}
          value -> {:halt, value}
        end
      end)

    case slug do
      nil ->
        nil

      slug_value ->
        case AuthoringResolver.from_revision_slug(project_slug(built_project), slug_value) do
          nil -> nil
          revision -> revision.resource_id
        end
    end
  end

  defp ensure_same_resource(id1, id2) do
    with int1 when is_integer(int1) <- normalize_resource_id(id1),
         int2 when is_integer(int2) <- normalize_resource_id(id2) do
      int1 == int2
    else
      _ -> false
    end
  end

  defp normalize_resource_id(value) when is_integer(value), do: value

  defp normalize_resource_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _rest} -> int
      :error -> nil
    end
  end

  defp normalize_resource_id(_value), do: nil

  defp child_statuses(project_slug, children) do
    Enum.map(children || [], fn
      nil ->
        {nil, nil}

      resource_id ->
        case AuthoringResolver.from_resource_id(project_slug, resource_id) do
          nil -> {:missing, resource_id}
          revision -> {:ok, revision.title}
        end
    end)
  end

  defp section_child_statuses(section_slug, children) do
    Enum.map(children || [], fn
      nil ->
        {nil, nil}

      resource_id ->
        case DeliveryResolver.from_resource_id(section_slug, resource_id) do
          nil -> {:missing, resource_id}
          revision -> {:ok, revision.title}
        end
    end)
  end

  defp titles_from_statuses(statuses) do
    statuses
    |> Enum.filter(&match?({:ok, _}, &1))
    |> Enum.map(fn {:ok, title} -> title end)
  end
end
