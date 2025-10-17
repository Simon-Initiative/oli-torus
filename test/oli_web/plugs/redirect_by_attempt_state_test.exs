defmodule OliWeb.Plugs.RedirectByAttemptStateTest do
  use OliWeb.ConnCase, async: true

  import Oli.Factory
  import Oli.TestHelpers

  alias Ecto.Changeset
  alias Oli.Repo
  alias OliWeb.Plugs.RedirectByAttemptState

  # Helper function to assert redirect to path
  defp assert_redirected_to_path(conn, expected_path) do
    assert redirected_to(conn) == expected_path
  end

  # Helper function to prepare conn for testing
  defp prepare_conn(conn, section, revision, opts \\ %{}) do
    conn
    |> assign(:section, section)
    |> assign(:page_revision, revision)
    |> assign(:already_been_redirected?, Map.get(opts, :already_redirected, false))
    |> Map.put(:params, %{
      "section_slug" => section.slug,
      "revision_slug" => revision.slug
    } |> Map.merge(Map.get(opts, :extra_params, %{})))
  end

  setup do
    {:ok, section_data} = section_with_assessment(%{})
    section_map = Enum.into(section_data, %{})
    user = insert(:user)

    conn = build_conn()
    |> Phoenix.ConnTest.init_test_session(%{})
    |> fetch_session()
    |> assign(:current_user, user)

    {:ok, Map.merge(section_map, %{conn: conn, user: user})}
  end

  describe "call/2 for graded pages" do
    # Test: {:graded, :adaptive_chromeless, _, true} -> ensure_path(conn, :review, :adaptive)
    test "redirects graded adaptive chromeless to adaptive review when review path", %{conn: conn, section: section, page_revision: page_revision} do
      # Update the existing page_revision to be graded adaptive chromeless
      page_revision
      |> Changeset.change(%{
        graded: true,
        content: %{
          "advancedDelivery" => true,
          "displayApplicationChrome" => false
        }
      })
      |> Repo.update!()

      conn = prepare_conn(conn, section, page_revision, %{
        extra_params: %{
          "attempt_guid" => "test-attempt"
        }
      })

      result_conn = RedirectByAttemptState.call(conn, [])

      assert_redirected_to_path(result_conn, ~p"/sections/#{section.slug}/adaptive_lesson/#{page_revision.slug}/attempt/test-attempt/review")
    end

    # Test: {:graded, :not_adaptive, _, true} -> ensure_path(conn, :review, :not_adaptive)
    test "redirects graded not adaptive to review when review path", %{conn: conn, section: section, page_2_revision: page_2_revision} do
      # Update the existing page_2_revision to be graded (not adaptive)
      page_2_revision
      |> Changeset.change(%{
        graded: true,
        content: %{
          "advancedDelivery" => false
        }
      })
      |> Repo.update!()

      conn = prepare_conn(conn, section, page_2_revision, %{
        extra_params: %{
          "attempt_guid" => "test-attempt"
        }
      })

      result_conn = RedirectByAttemptState.call(conn, [])

      assert_redirected_to_path(result_conn, ~p"/sections/#{section.slug}/lesson/#{page_2_revision.slug}/attempt/test-attempt/review")
    end

    # Test: {:graded, _, nil, false} -> ensure_path(conn, :prologue)
    test "redirects graded adaptive chromeless to prologue when no attempt", %{conn: conn, section: section, page_revision: page_revision} do
      # Update the existing page_revision to have displayApplicationChrome: false
      page_revision
      |> Changeset.change(%{
        content: %{
          "advancedDelivery" => true,
          "displayApplicationChrome" => false
        }
      })
      |> Repo.update!()

      conn = prepare_conn(conn, section, page_revision)

      result_conn = RedirectByAttemptState.call(conn, [])

      assert_redirected_to_path(result_conn, "/sections/#{section.slug}/prologue/#{page_revision.slug}?")
    end

    # Test: {:graded, _, %ResourceAttempt{lifecycle_state: state}, false} when state in [:submitted, :evaluated] -> ensure_path(conn, :prologue)
    test "redirects graded to prologue when submitted attempt", %{conn: conn, section: section, page_revision: page_revision, user: user} do
      # Update the existing page_revision to be graded
      page_revision
      |> Changeset.change(%{
        graded: true,
        content: %{
          "advancedDelivery" => true
        }
      })
      |> Repo.update!()

      # Create a resource access for the user and section
      resource_access = insert(:resource_access, %{
        user: user,
        section: section,
        resource: page_revision.resource
      })

      # Create a resource attempt with submitted state
      _resource_attempt = insert(:resource_attempt, %{
        lifecycle_state: :submitted,
        revision: page_revision,
        resource_access: resource_access
      })

      conn = prepare_conn(conn, section, page_revision)

      result_conn = RedirectByAttemptState.call(conn, [])

      assert_redirected_to_path(result_conn, "/sections/#{section.slug}/prologue/#{page_revision.slug}?")
    end

    # Test: {:graded, :not_adaptive, %ResourceAttempt{lifecycle_state: :active}, false} -> ensure_path(conn, :lesson)
    test "redirects graded not adaptive to lesson when active attempt", %{conn: conn, section: section, page_2_revision: page_2_revision, user: user} do
      # Update the existing page_2_revision to be graded not adaptive
      page_2_revision
      |> Changeset.change(%{
        graded: true,
        content: %{
          "advancedDelivery" => false
        }
      })
      |> Repo.update!()

      # Create a resource access for the user and section
      resource_access = insert(:resource_access, %{
        user: user,
        section: section,
        resource: page_2_revision.resource
      })

      # Create a resource attempt with active state
      resource_attempt = insert(:resource_attempt, %{
        lifecycle_state: :active,
        revision: page_2_revision,
        resource_access: resource_access
      })

      # Debug: verify the lifecycle_state was set correctly
      assert resource_attempt.lifecycle_state == :active

      conn = prepare_conn(conn, section, page_2_revision)

      result_conn = RedirectByAttemptState.call(conn, [])

      assert_redirected_to_path(result_conn, "/sections/#{section.slug}/lesson/#{page_2_revision.slug}?")
    end

    # Test: {:graded, :adaptive_chromeless, %ResourceAttempt{lifecycle_state: :active}, false} -> ensure_path(conn, :adaptive_lesson)
    test "redirects graded adaptive chromeless to adaptive lesson when active attempt", %{conn: conn, section: section, page_revision: page_revision, user: user} do
      # Update the existing page_revision to be graded adaptive chromeless
      page_revision
      |> Changeset.change(%{
        graded: true,
        content: %{
          "advancedDelivery" => true,
          "displayApplicationChrome" => false
        }
      })
      |> Repo.update!()

      # Create a resource access for the user and section
      resource_access = insert(:resource_access, %{
        user: user,
        section: section,
        resource: page_revision.resource
      })

      # Create a resource attempt with active state
      resource_attempt = insert(:resource_attempt, %{
        lifecycle_state: :active,
        revision: page_revision,
        resource_access: resource_access
      })

      # Debug: verify the lifecycle_state was set correctly
      assert resource_attempt.lifecycle_state == :active

      conn = prepare_conn(conn, section, page_revision)

      result_conn = RedirectByAttemptState.call(conn, [])

      assert_redirected_to_path(result_conn, ~p"/sections/#{section.slug}/adaptive_lesson/#{page_revision.slug}")
    end
  end

  describe "call/2 for practice pages" do
    # Test: {:practice, :not_adaptive, _, false} -> ensure_path(conn, :lesson)
    test "redirects practice not adaptive to lesson when not review path", %{conn: conn, section: section, page_2_revision: page_2_revision} do
      # Update the existing page_2_revision to be practice not adaptive
      page_2_revision
      |> Changeset.change(%{
        graded: false,
        content: %{
          "advancedDelivery" => false
        }
      })
      |> Repo.update!()

      conn = prepare_conn(conn, section, page_2_revision)

      result_conn = RedirectByAttemptState.call(conn, [])

      assert_redirected_to_path(result_conn, "/sections/#{section.slug}/lesson/#{page_2_revision.slug}?")
    end

    # Test: {:practice, :not_adaptive, _, true} -> ensure_path(conn, :review, :not_adaptive)
    test "redirects practice not adaptive to review when review path", %{conn: conn, section: section, page_2_revision: page_2_revision} do
      # Update the existing page_2_revision to be practice not adaptive
      page_2_revision
      |> Changeset.change(%{
        graded: false,
        content: %{
          "advancedDelivery" => false
        }
      })
      |> Repo.update!()

      conn = prepare_conn(conn, section, page_2_revision, %{
        extra_params: %{
          "attempt_guid" => "test-attempt"
        }
      })

      result_conn = RedirectByAttemptState.call(conn, [])

      assert_redirected_to_path(result_conn, ~p"/sections/#{section.slug}/lesson/#{page_2_revision.slug}/attempt/test-attempt/review")
    end

    # Test: {:practice, :adaptive_chromeless, _, false} -> ensure_path(conn, :adaptive_lesson)
    test "redirects practice adaptive chromeless to adaptive lesson when not review path", %{conn: conn, section: section, page_revision: page_revision} do
      # Update the existing page_revision to be practice (not graded) with adaptive delivery
      page_revision
      |> Changeset.change(%{
        graded: false,
        content: %{
          "advancedDelivery" => true,
          "displayApplicationChrome" => false
        }
      })
      |> Repo.update!()

      conn = prepare_conn(conn, section, page_revision)

      result_conn = RedirectByAttemptState.call(conn, [])

      assert_redirected_to_path(result_conn, ~p"/sections/#{section.slug}/adaptive_lesson/#{page_revision.slug}")
    end

    # Test: {:practice, :adaptive_chromeless, _, true} -> ensure_path(conn, :review, :adaptive)
    test "redirects practice adaptive chromeless to adaptive review when review path", %{conn: conn, section: section, page_2_revision: page_2_revision} do
      # Update the existing page_2_revision to be practice (not graded) with adaptive delivery
      page_2_revision
      |> Changeset.change(%{
        graded: false,
        content: %{
          "advancedDelivery" => true,
          "displayApplicationChrome" => false
        }
      })
      |> Repo.update!()

      conn = prepare_conn(conn, section, page_2_revision, %{
        extra_params: %{
          "attempt_guid" => "test-attempt"
        }
      })

      result_conn = RedirectByAttemptState.call(conn, [])

      assert_redirected_to_path(result_conn, ~p"/sections/#{section.slug}/adaptive_lesson/#{page_2_revision.slug}/attempt/test-attempt/review")
    end

    # Test: already_been_redirected?(conn) == true -> conn (no redirect)
    test "does not redirect when already been redirected", %{conn: conn, section: section, page_2_revision: page_2_revision} do
      # Update the existing page_2_revision to be practice (not graded) with adaptive delivery
      page_2_revision
      |> Changeset.change(%{
        graded: false,
        content: %{
          "advancedDelivery" => true,
          "displayApplicationChrome" => false
        }
      })
      |> Repo.update!()

      conn = prepare_conn(conn, section, page_2_revision, %{
        already_redirected: true
      })

      result_conn = RedirectByAttemptState.call(conn, [])

      refute result_conn.halted
      refute result_conn.status == 302
    end
  end
end
