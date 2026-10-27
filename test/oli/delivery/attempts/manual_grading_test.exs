defmodule Oli.Delivery.Attempts.ManualGradingTest do
  use Oli.DataCase
  use Oban.Testing, repo: Oli.Repo

  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Accounts.User
  alias Oli.Delivery.Attempts.ManualGrading
  alias Oli.Delivery.Attempts.ManualGrading.BrowseOptions
  alias Oli.Activities.Model.{Part}
  alias Oli.Delivery.Attempts.Core
  alias Oli.Experiments.Schemas.{AcceptedReward, PolicyState}
  alias Oli.Test.ExperimentRewardSetup

  def add_submitted_activity(
        map,
        resource_attempt_tag,
        activity_tag,
        activity_attempt_tag,
        activity_attempt_attrs \\ %{}
      ) do
    map
    |> Seeder.create_activity_attempt(
      Map.merge(
        %{attempt_number: 1, transformed_model: %{some: :thing}, lifecycle_state: :submitted},
        activity_attempt_attrs
      ),
      activity_tag,
      resource_attempt_tag,
      activity_attempt_tag
    )
    |> Seeder.create_part_attempt(
      %{
        attempt_number: 1,
        grading_approach: :manual,
        date_submitted: DateTime.utc_now(),
        lifecycle_state: :submitted
      },
      %Part{id: "1", responses: [], hints: [], grading_approach: :manual},
      activity_attempt_tag
    )
  end

  def add_evaluated_activity(map, resource_attempt_tag, activity_tag, activity_attempt_tag) do
    map
    |> Seeder.create_activity_attempt(
      %{attempt_number: 1, transformed_model: %{some: :thing}, lifecycle_state: :evaluated},
      activity_tag,
      resource_attempt_tag,
      activity_attempt_tag
    )
    |> Seeder.create_part_attempt(
      %{
        attempt_number: 1,
        grading_approach: :automatic,
        date_submitted: DateTime.utc_now(),
        lifecycle_state: :evaluated
      },
      %Part{id: "1", responses: [], hints: [], grading_approach: :automatic},
      activity_attempt_tag
    )
  end

  def add_stale_submitted_activity(map, resource_attempt_tag, activity_tag, activity_attempt_tag) do
    map
    |> Seeder.create_activity_attempt(
      %{attempt_number: 1, transformed_model: %{some: :thing}, lifecycle_state: :submitted},
      activity_tag,
      resource_attempt_tag,
      activity_attempt_tag
    )
    |> Seeder.create_part_attempt(
      %{
        attempt_number: 1,
        grading_approach: :manual,
        date_submitted: DateTime.utc_now(),
        date_evaluated: DateTime.utc_now(),
        lifecycle_state: :evaluated,
        score: 1.0,
        out_of: 1.0
      },
      %Part{id: "1", responses: [], hints: [], grading_approach: :manual, out_of: 1.0},
      activity_attempt_tag
    )
  end

  describe "applying scores and feedback" do
    setup do
      map = Seeder.base_project_with_resource2()
      Oli.Resources.update_revision(map.revision2, %{graded: true})

      map
      |> Seeder.create_section()
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_user(%{}, :user2)
      |> Seeder.add_activity(%{title: "title 1"}, :publication, :project, :author, :activity_a)
      |> Seeder.add_activity(%{title: "title 2"}, :publication, :project, :author, :activity_b)
      |> Seeder.add_activity(%{title: "title 3"}, :publication, :project, :author, :activity_c)
      |> Seeder.create_section_resources()
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1, lifecycle_state: :active},
        :user1,
        :page1,
        :revision1,
        :attempt1
      )
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1, lifecycle_state: :submitted},
        :user1,
        :page2,
        :revision2,
        :attempt2
      )
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1, lifecycle_state: :submitted},
        :user2,
        :page2,
        :revision2,
        :attempt3
      )
      |> add_submitted_activity(:attempt1, :activity_a, :attempt_1a)
      |> add_submitted_activity(:attempt2, :activity_b, :attempt_2b)
      |> add_submitted_activity(:attempt3, :activity_b, :attempt_3b)
      |> add_submitted_activity(:attempt3, :activity_c, :attempt_3c)
    end

    test "basic application of scores", %{
      section: section,
      attempt_1a: attempt_1a,
      attempt_2b: attempt_2b,
      attempt_3b: attempt_3b,
      attempt_3c: attempt_3c,
      publication: publication
    } do
      Seeder.ensure_published(publication.id)

      results =
        ManualGrading.browse_submitted_attempts(
          section,
          %Paging{limit: 4, offset: 0},
          %Sorting{field: :date_submitted, direction: :desc},
          %BrowseOptions{
            user_ids: [],
            activity_ids: [],
            page_ids: [],
            graded: nil,
            text_search: nil
          }
        )

      attempt = Enum.find(results, fn a -> a.id == attempt_1a.id end)
      ManualGrading.apply_manual_scoring(section, attempt, create_score_feedbacks(attempt))

      ra = Core.get_resource_attempt_by(attempt_guid: attempt.resource_attempt_guid)
      assert ra.lifecycle_state == :active
      aa = Core.get_activity_attempt_by(attempt_guid: attempt.attempt_guid)
      assert aa.lifecycle_state == :evaluated

      attempt = Enum.find(results, fn a -> a.id == attempt_2b.id end)
      ManualGrading.apply_manual_scoring(section, attempt, create_score_feedbacks(attempt))

      ra = Core.get_resource_attempt_by(attempt_guid: attempt.resource_attempt_guid)
      assert ra.lifecycle_state == :evaluated
      aa = Core.get_activity_attempt_by(attempt_guid: attempt.attempt_guid)
      assert aa.lifecycle_state == :evaluated

      attempt = Enum.find(results, fn a -> a.id == attempt_3b.id end)
      ManualGrading.apply_manual_scoring(section, attempt, create_score_feedbacks(attempt))

      ra = Core.get_resource_attempt_by(attempt_guid: attempt.resource_attempt_guid)
      assert ra.lifecycle_state == :submitted

      attempt = Enum.find(results, fn a -> a.id == attempt_3c.id end)
      ManualGrading.apply_manual_scoring(section, attempt, create_score_feedbacks(attempt))

      ra = Core.get_resource_attempt_by(attempt_guid: attempt.resource_attempt_guid)
      assert ra.lifecycle_state == :evaluated

      # Verify that manual scoring of the last activity triggers grade roll up to the resource access
      resource_access =
        Oli.Repo.get!(Oli.Delivery.Attempts.Core.ResourceAccess, ra.resource_access_id)

      assert resource_access.out_of == 2.0
      assert resource_access.score == 2.0
    end
  end

  def create_score_feedbacks(activity_attempt) do
    Oli.Delivery.Attempts.Core.get_latest_part_attempts(activity_attempt.attempt_guid)
    |> Enum.reduce(%{}, fn pa, m ->
      Map.put(m, pa.attempt_guid, %{score: 1, out_of: 1, feedback: "test"})
    end)
  end

  describe "browsing manual graded attempts" do
    setup do
      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_user(%{}, :user2)
      |> Seeder.add_activity(%{title: "title 1"}, :publication, :project, :author, :activity_a)
      |> Seeder.add_activity(%{title: "title 2"}, :publication, :project, :author, :activity_b)
      |> Seeder.add_activity(%{title: "title 3"}, :publication, :project, :author, :activity_c)
      |> Seeder.add_activity(%{title: "title 4"}, :publication, :project, :author, :activity_d)
      |> Seeder.add_activity(%{title: "title 5"}, :publication, :project, :author, :activity_e)
      |> Seeder.add_page(%{graded: true}, :graded_page)
      |> Seeder.create_section_resources()
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1},
        :user1,
        :page1,
        :revision1,
        :attempt1
      )
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1},
        :user2,
        :page1,
        :revision1,
        :attempt2
      )
      |> add_submitted_activity(:attempt1, :activity_a, :attempt_1a)
      |> add_submitted_activity(:attempt1, :activity_b, :attempt_1b)
      |> add_submitted_activity(:attempt1, :activity_c, :attempt_1c)
      |> add_submitted_activity(:attempt1, :activity_d, :attempt_1d)
      |> add_submitted_activity(:attempt2, :activity_a, :attempt_2a)
      |> add_submitted_activity(:attempt2, :activity_b, :attempt_2b)
      |> add_submitted_activity(:attempt2, :activity_c, :attempt_2c)
      |> add_submitted_activity(:attempt2, :activity_d, :attempt_2d)
      |> add_evaluated_activity(:attempt1, :activity_e, :attempt_1e)
      |> add_evaluated_activity(:attempt2, :activity_e, :attempt_2e)
    end

    test "basic browsing", %{
      section: section,
      user1: user1,
      activity_a: activity_a
    } do
      result =
        ManualGrading.browse_submitted_attempts(
          section,
          %Paging{limit: 3, offset: 0},
          %Sorting{field: :date_submitted, direction: :desc},
          %BrowseOptions{
            user_ids: [],
            activity_ids: [],
            page_ids: [],
            graded: nil,
            text_search: nil
          }
        )

      assert Enum.count(result) == 3
      assert Enum.at(result, 0).total_count == 8

      # Filter by user
      result =
        ManualGrading.browse_submitted_attempts(
          section,
          %Paging{limit: 3, offset: 0},
          %Sorting{field: :date_submitted, direction: :desc},
          %BrowseOptions{
            user_ids: [user1.id],
            activity_ids: [],
            page_ids: [],
            graded: nil,
            text_search: nil
          }
        )

      assert Enum.count(result) == 3
      assert Enum.at(result, 0).total_count == 4

      # Filter by activity
      result =
        ManualGrading.browse_submitted_attempts(
          section,
          %Paging{limit: 3, offset: 0},
          %Sorting{field: :date_submitted, direction: :desc},
          %BrowseOptions{
            user_ids: [],
            activity_ids: [activity_a.resource.id],
            page_ids: [],
            graded: nil,
            text_search: nil
          }
        )

      assert Enum.count(result) == 2
      assert Enum.at(result, 0).total_count == 2

      # Filter by graded = true
      result =
        ManualGrading.browse_submitted_attempts(
          section,
          %Paging{limit: 3, offset: 0},
          %Sorting{field: :date_submitted, direction: :desc},
          %BrowseOptions{
            user_ids: [],
            activity_ids: [],
            page_ids: [],
            graded: true,
            text_search: nil
          }
        )

      assert Enum.count(result) == 0

      # Filter by graded = false
      result =
        ManualGrading.browse_submitted_attempts(
          section,
          %Paging{limit: 3, offset: 0},
          %Sorting{field: :date_submitted, direction: :desc},
          %BrowseOptions{
            user_ids: [],
            activity_ids: [],
            page_ids: [],
            graded: false,
            text_search: nil
          }
        )

      assert Enum.count(result) == 3
      assert Enum.at(result, 0).total_count == 8

      # Filter by text search
      result =
        ManualGrading.browse_submitted_attempts(
          section,
          %Paging{limit: 3, offset: 0},
          %Sorting{field: :date_submitted, direction: :desc},
          %BrowseOptions{
            user_ids: [],
            activity_ids: [],
            page_ids: [],
            graded: nil,
            text_search: "title 2"
          }
        )

      assert Enum.count(result) == 2
      assert Enum.at(result, 0).total_count == 2
    end

    test "browsing stays pinned to the attempted page and activity revisions when newer revisions exist",
         %{
           section: section,
           attempt_1a: attempt_1a,
           activity_a: activity_a,
           revision1: page_revision
         } do
      original_activity_title = activity_a.revision.title
      original_page_title = page_revision.title

      {:ok, _new_activity_revision} =
        Oli.Resources.create_revision_from_previous(activity_a.revision, %{
          title: "Newer Activity Title"
        })

      {:ok, _new_page_revision} =
        Oli.Resources.create_revision_from_previous(page_revision, %{
          title: "Newer Page Title"
        })

      result =
        ManualGrading.browse_submitted_attempts(
          section,
          %Paging{limit: 10, offset: 0},
          %Sorting{field: :date_submitted, direction: :desc},
          %BrowseOptions{
            user_ids: [],
            activity_ids: [],
            page_ids: [],
            graded: nil,
            text_search: nil
          }
        )

      selected_attempt = Enum.find(result, &(&1.id == attempt_1a.id))

      assert selected_attempt.activity_title == original_activity_title
      assert selected_attempt.page_title == original_page_title
      assert selected_attempt.revision_id == activity_a.revision.id
      assert selected_attempt.revision.id == activity_a.revision.id
    end
  end

  describe "deterministic order" do
    @sort_fields [
      :user,
      :activity_title,
      :attempt_number,
      :page_title,
      :resource_attempt_number,
      :activity_type_id,
      :graded,
      :date_submitted
    ]

    setup do
      submitted_at = ~U[2026-10-01 12:00:00Z]

      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_user(%{family_name: "Tied", given_name: "Amy"}, :user1)
        |> Seeder.add_user(%{family_name: "Tied", given_name: "Beth"}, :user2)
        |> Seeder.add_activity(%{title: "Same activity"}, :publication, :project, :author, :act_a)
        |> Seeder.add_activity(%{title: "Same activity"}, :publication, :project, :author, :act_b)
        |> Seeder.create_section_resources()
        |> Seeder.create_resource_attempt(%{attempt_number: 1}, :user1, :page1, :revision1, :ra1)
        |> Seeder.create_resource_attempt(%{attempt_number: 1}, :user2, :page1, :revision1, :ra2)
        |> add_submitted_activity(:ra1, :act_a, :tied_1, %{date_submitted: submitted_at})
        |> add_submitted_activity(:ra1, :act_b, :tied_2, %{date_submitted: submitted_at})
        |> add_submitted_activity(:ra2, :act_a, :tied_3, %{date_submitted: submitted_at})
        |> add_submitted_activity(:ra2, :act_b, :tied_4, %{date_submitted: submitted_at})

      tied_ids = Enum.map([:tied_1, :tied_2, :tied_3, :tied_4], &map[&1].id)

      {:ok, section: map.section, tied_ids: tied_ids}
    end

    test "rows tied on the sort key come out by attempt id, and the ORDER BY clause carries the tie-breaker",
         %{section: section, tied_ids: tied_ids} do
      handler = attach_query_telemetry()
      on_exit(fn -> :telemetry.detach(handler) end)

      for field <- @sort_fields, direction <- [:asc, :desc] do
        ids =
          section
          |> browse_all(%Sorting{field: field, direction: direction})
          |> Enum.map(& &1.id)

        assert ids == Enum.sort(tied_ids, direction),
               "sort by #{field} #{direction}: result order"

        assert_receive {:query, sql}

        case direction do
          :asc ->
            assert sql =~ ~r/ORDER BY [^,]+, a0\."id" LIMIT/,
                   "sort by #{field} asc: #{sql}"

            refute sql =~ " DESC", "sort by #{field} asc: #{sql}"

          :desc ->
            assert sql =~ ~r/ORDER BY [^,]+ DESC, a0\."id" DESC LIMIT/,
                   "sort by #{field} desc: #{sql}"
        end
      end
    end

    defp browse_all(section, sorting) do
      ManualGrading.browse_submitted_attempts(
        section,
        %Paging{limit: 50, offset: 0},
        sorting,
        %BrowseOptions{
          user_ids: [],
          activity_ids: [],
          page_ids: [],
          graded: nil,
          text_search: nil
        }
      )
    end

    defp attach_query_telemetry do
      handler_id = "manual-grading-query-#{System.unique_integer([:positive])}"
      parent = self()

      :ok =
        :telemetry.attach(
          handler_id,
          [:oli, :repo, :query],
          fn _event, _measurements, %{query: query}, _config ->
            if self() == parent, do: send(parent, {:query, query})
          end,
          nil
        )

      handler_id
    end
  end

  describe "multi-value filters" do
    setup do
      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_user(%{family_name: "Alpha"}, :user_a)
        |> Seeder.add_user(%{family_name: "Beta"}, :user_b)
        |> Seeder.add_user(%{family_name: "Gamma"}, :user_c)
        |> Seeder.add_activity(%{title: "Activity one"}, :publication, :project, :author, :act_1)
        |> Seeder.add_activity(%{title: "Activity two"}, :publication, :project, :author, :act_2)
        |> Seeder.add_activity(
          %{title: "Activity three"},
          :publication,
          :project,
          :author,
          :act_3
        )
        |> Seeder.create_section_resources()
        |> Seeder.create_resource_attempt(
          %{attempt_number: 1},
          :user_a,
          :page1,
          :revision1,
          :ra_a1
        )
        |> Seeder.create_resource_attempt(
          %{attempt_number: 1},
          :user_a,
          :page2,
          :revision2,
          :ra_a2
        )
        |> Seeder.create_resource_attempt(
          %{attempt_number: 1},
          :user_b,
          :page1,
          :revision1,
          :ra_b1
        )
        |> Seeder.create_resource_attempt(
          %{attempt_number: 1},
          :user_c,
          :page2,
          :revision2,
          :ra_c2
        )
        |> add_submitted_activity(:ra_a1, :act_1, :a_1_p1)
        |> add_submitted_activity(:ra_a1, :act_2, :a_2_p1)
        |> add_submitted_activity(:ra_a2, :act_3, :a_3_p2)
        |> add_submitted_activity(:ra_b1, :act_1, :b_1_p1)
        |> add_submitted_activity(:ra_c2, :act_2, :c_2_p2)

      {:ok, map}
    end

    test "each list filter selects its rows; [] means no filter", ctx do
      activity_ids =
        browse_ids(ctx.section, activity_ids: [ctx.act_1.resource.id, ctx.act_2.resource.id])

      assert activity_ids == ids_of(ctx, [:a_1_p1, :a_2_p1, :b_1_p1, :c_2_p2]),
             "activity filter: two chosen"

      refute ctx.a_3_p2.id in activity_ids

      assert browse_ids(ctx.section, activity_ids: []) ==
               ids_of(ctx, ~w(a_1_p1 a_2_p1 a_3_p2 b_1_p1 c_2_p2)a),
             "activity filter: empty list returns all"

      student_ids = browse_ids(ctx.section, user_ids: [ctx.user_a.id, ctx.user_b.id])

      assert student_ids == ids_of(ctx, [:a_1_p1, :a_2_p1, :a_3_p2, :b_1_p1]),
             "student filter: two chosen"

      refute ctx.c_2_p2.id in student_ids

      page1 = ctx.page1.id
      page2 = ctx.page2.id

      assert browse_ids(ctx.section, page_ids: [page2]) == ids_of(ctx, [:a_3_p2, :c_2_p2]),
             "page filter: one page"

      assert browse_ids(ctx.section, page_ids: [page1, page2]) ==
               ids_of(ctx, ~w(a_1_p1 a_2_p1 a_3_p2 b_1_p1 c_2_p2)a),
             "page filter: both pages"
    end

    test "list filters combine with each other (AND)", ctx do
      ids =
        browse_ids(ctx.section,
          user_ids: [ctx.user_a.id, ctx.user_c.id],
          activity_ids: [ctx.act_2.resource.id]
        )

      assert ids == ids_of(ctx, [:a_2_p1, :c_2_p2])
    end

    defp browse_ids(section, overrides) do
      options =
        struct!(
          %BrowseOptions{
            user_ids: [],
            activity_ids: [],
            page_ids: [],
            graded: nil,
            text_search: nil
          },
          overrides
        )

      section
      |> ManualGrading.browse_submitted_attempts(
        %Paging{limit: 50, offset: 0},
        %Sorting{field: :date_submitted, direction: :desc},
        options
      )
      |> Enum.map(& &1.id)
      |> Enum.sort()
    end

    defp ids_of(ctx, tags), do: tags |> Enum.map(&ctx[&1].id) |> Enum.sort()
  end

  describe "filter options and counts" do
    setup do
      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_user(%{family_name: "Pending one"}, :u1)
        |> Seeder.add_user(%{family_name: "Pending two"}, :u2)
        |> Seeder.add_user(%{family_name: "Scored only"}, :u3)
        |> Seeder.add_activity(%{title: "Old title"}, :publication, :project, :author, :act_a)
        |> Seeder.add_activity(%{title: "Activity B"}, :publication, :project, :author, :act_b)
        |> Seeder.add_activity(
          %{title: "Scored activity"},
          :publication,
          :project,
          :author,
          :act_c
        )
        |> Seeder.create_section_resources()
        |> Seeder.create_resource_attempt(
          %{attempt_number: 1},
          :u1,
          :page1,
          :revision1,
          :ra_u1_p1
        )
        |> Seeder.create_resource_attempt(
          %{attempt_number: 1},
          :u2,
          :page1,
          :revision1,
          :ra_u2_p1
        )
        |> Seeder.create_resource_attempt(
          %{attempt_number: 1},
          :u3,
          :page2,
          :revision2,
          :ra_u3_p2
        )

      {:ok, new_revision} =
        Oli.Resources.create_revision_from_previous(map.act_a.revision, %{title: "New title"})

      map =
        map
        |> Map.put(:act_a_new, %{resource: map.act_a.resource, revision: new_revision})
        |> add_submitted_activity(:ra_u1_p1, :act_a, :a_old_first, %{
          date_submitted: ~U[2026-10-01 10:00:00Z]
        })
        |> add_submitted_activity(:ra_u2_p1, :act_a_new, :a_new, %{
          date_submitted: ~U[2026-10-03 10:00:00Z]
        })
        |> add_submitted_activity(:ra_u1_p1, :act_a, :a_old_last, %{
          date_submitted: ~U[2026-10-02 10:00:00Z]
        })
        |> add_submitted_activity(:ra_u2_p1, :act_b, :b)
        |> add_evaluated_activity(:ra_u3_p2, :act_c, :c_scored)

      {:ok, map}
    end

    test "one option per student, activity and page with pending submissions in this section",
         ctx do
      options = ManualGrading.filter_options(ctx.section)

      assert Enum.map(options.users, & &1.id) == Enum.sort([ctx.u1.id, ctx.u2.id])
      refute ctx.u3.id in Enum.map(options.users, & &1.id)

      first_user = hd(options.users)
      assert %User{} = first_user
      assert first_user.guest == ctx.u1.guest
      assert first_user.name == ctx.u1.name
      assert first_user.given_name == ctx.u1.given_name
      assert first_user.family_name == ctx.u1.family_name

      assert options.activities == [
               %{id: ctx.act_a.resource.id, title: "New title"},
               %{id: ctx.act_b.resource.id, title: "Activity B"}
             ]

      assert options.pages == [%{id: ctx.page1.id, title: ctx.revision1.title}]
    end

    test "labels come from the latest pending submission: a later date beats a higher id, and equal dates go to the higher id",
         ctx do
      new_revision = fn revision, title ->
        {:ok, revision} = Oli.Resources.create_revision_from_previous(revision, %{title: title})
        revision
      end

      act_b_new = new_revision.(ctx.act_b.revision, "Activity B, higher id")

      ctx
      |> Map.merge(%{
        page1_new: new_revision.(ctx.revision1, "Page one, latest"),
        page2_new: new_revision.(ctx.revision2, "Page two, higher id"),
        act_b_new: %{resource: ctx.act_b.resource, revision: act_b_new}
      })
      # Page one: the latest submission is created first, so date and id disagree.
      |> Seeder.create_resource_attempt(%{attempt_number: 2}, :u1, :page1, :page1_new, :ra_p1_new)
      |> add_submitted_activity(:ra_p1_new, :act_a_new, :p1_latest, %{
        date_submitted: ~U[2026-10-09 10:00:00Z]
      })
      |> add_submitted_activity(:ra_u1_p1, :act_a_new, :p1_older, %{
        date_submitted: ~U[2026-10-08 10:00:00Z]
      })
      |> Seeder.create_resource_attempt(%{attempt_number: 1}, :u1, :page2, :revision2, :ra_p2_old)
      |> Seeder.create_resource_attempt(%{attempt_number: 1}, :u2, :page2, :page2_new, :ra_p2_new)
      |> add_submitted_activity(:ra_p2_old, :act_b, :tie_lower_id, %{
        date_submitted: ~U[2026-10-11 10:00:00Z]
      })
      |> add_submitted_activity(:ra_p2_new, :act_b_new, :tie_higher_id, %{
        date_submitted: ~U[2026-10-11 10:00:00Z]
      })

      options = ManualGrading.filter_options(ctx.section)

      assert options.pages == [
               %{id: ctx.page1.id, title: "Page one, latest"},
               %{id: ctx.page2.id, title: "Page two, higher id"}
             ]

      assert options.activities == [
               %{id: ctx.act_a.resource.id, title: "New title"},
               %{id: ctx.act_b.resource.id, title: "Activity B, higher id"}
             ]
    end

    test "options load one database row per student, activity and page, not one per pending submission",
         ctx do
      ctx =
        Enum.reduce(1..5, ctx, fn n, acc ->
          add_submitted_activity(acc, :ra_u1_p1, :act_a, :"a_extra_#{n}")
        end)

      handler = {__MODULE__, make_ref()}
      parent = self()

      :ok =
        :telemetry.attach(
          handler,
          [:oli, :repo, :query],
          fn _, _, metadata, _ ->
            case {self() == parent, metadata.result} do
              {true, {:ok, %{num_rows: rows}}} -> send(parent, {handler, rows})
              _ -> :ok
            end
          end,
          nil
        )

      on_exit(fn -> :telemetry.detach(handler) end)

      options = ManualGrading.filter_options(ctx.section)

      rows_loaded =
        Stream.repeatedly(fn ->
          receive do
            {^handler, rows} -> rows
          after
            0 -> nil
          end
        end)
        |> Enum.take_while(& &1)
        |> Enum.sum()

      assert {length(options.users), length(options.activities), length(options.pages)} ==
               {2, 2, 1}

      assert rows_loaded == 5
    end

    test "filter_value_labels/2 labels only ids that belong to the section", ctx do
      Oli.Delivery.Sections.enroll(ctx.u1.id, ctx.section.id, [
        Lti_1p3.Roles.ContextRoles.get_role(:context_learner)
      ])

      stranger = Oli.Utils.Seeder.AccountsFixtures.user_fixture()

      Oli.Delivery.Sections.enroll(stranger.id, Oli.Factory.insert(:section).id, [
        Lti_1p3.Roles.ContextRoles.get_role(:context_learner)
      ])

      foreign_activity =
        Oli.Factory.insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_activity(),
          title: "Foreign activity"
        )

      foreign_page =
        Oli.Factory.insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_page(),
          title: "Foreign page"
        )

      labels =
        ManualGrading.filter_value_labels(ctx.section, %{
          user_ids: [ctx.u1.id, stranger.id, 999_999],
          activity_ids: [ctx.act_a.resource.id, foreign_activity.resource_id, 999_998],
          page_ids: [ctx.page1.id, foreign_page.resource_id, 999_997]
        })

      assert Map.keys(labels.users) == [ctx.u1.id]
      assert labels.users[ctx.u1.id].id == ctx.u1.id
      assert labels.activities == %{ctx.act_a.resource.id => ctx.act_a.revision.title}
      assert labels.pages == %{ctx.page1.id => ctx.revision1.title}
    end

    test "count_submitted_attempts/1 counts the pending submissions of the section", ctx do
      assert ManualGrading.count_submitted_attempts(ctx.section) == 4

      Repo.update!(Ecto.Changeset.change(ctx.b, lifecycle_state: :evaluated))

      assert ManualGrading.count_submitted_attempts(ctx.section) == 3
    end
  end

  describe "submission_position/4" do
    @no_filter %BrowseOptions{
      user_ids: [],
      activity_ids: [],
      page_ids: [],
      graded: nil,
      text_search: nil
    }

    setup do
      mc = Oli.Activities.get_registration_by_slug("oli_multiple_choice")
      sa = Oli.Activities.get_registration_by_slug("oli_short_answer")

      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_user(%{family_name: "Beta"}, :u1)
        |> Seeder.add_user(%{family_name: "Alpha"}, :u2)
        |> Seeder.add_user(%{family_name: "To be nulled"}, :u3)
        |> then(fn map ->
          # the changeset requires a last name; the column allows NULL and the order must handle it
          Map.put(map, :u3, Repo.update!(Ecto.Changeset.change(map.u3, family_name: nil)))
        end)
        |> Seeder.add_activity(%{title: "Essay"}, :publication, :project, :author, :a1, mc.id)
        |> Seeder.add_activity(%{title: "Essay"}, :publication, :project, :author, :a2, sa.id)
        |> Seeder.add_activity(%{title: "Diagram"}, :publication, :project, :author, :a3, mc.id)
        |> Seeder.add_page(%{title: "Page one", graded: true}, :p1)
        |> Seeder.add_page(%{title: "Page two", graded: false}, :p2)
        |> then(
          &Map.merge(&1, %{
            p1_res: &1.p1.resource,
            p1_rev: &1.p1.revision,
            p2_res: &1.p2.resource,
            p2_rev: &1.p2.revision
          })
        )
        |> Seeder.create_section_resources()
        |> Seeder.create_resource_attempt(%{attempt_number: 1}, :u1, :p1_res, :p1_rev, :ra_u1_p1)
        |> Seeder.create_resource_attempt(%{attempt_number: 1}, :u1, :p2_res, :p2_rev, :ra_u1_p2)
        |> Seeder.create_resource_attempt(%{attempt_number: 2}, :u2, :p2_res, :p2_rev, :ra_u2_p2)
        |> Seeder.create_resource_attempt(%{attempt_number: 2}, :u2, :p1_res, :p1_rev, :ra_u2_p1)
        |> Seeder.create_resource_attempt(%{attempt_number: 1}, :u3, :p1_res, :p1_rev, :ra_u3_p1)
        |> add_submitted_activity(:ra_u1_p1, :a1, :t1, %{
          attempt_number: 1,
          date_submitted: ~U[2026-10-01 00:00:00Z]
        })
        |> add_submitted_activity(:ra_u2_p2, :a2, :t2, %{
          attempt_number: 1,
          date_submitted: ~U[2026-10-03 00:00:00Z]
        })
        |> add_submitted_activity(:ra_u3_p1, :a3, :t3, %{attempt_number: 2, date_submitted: nil})
        |> add_submitted_activity(:ra_u1_p2, :a1, :t4, %{
          attempt_number: 1,
          date_submitted: ~U[2026-10-02 00:00:00Z]
        })
        |> add_submitted_activity(:ra_u2_p1, :a3, :t5, %{
          attempt_number: 2,
          date_submitted: ~U[2026-10-03 00:00:00Z]
        })

      {type_asc, type_desc} =
        if mc.id < sa.id,
          do: {~w(t1 t3 t4 t5 t2)a, ~w(t2 t5 t4 t3 t1)a},
          else: {~w(t2 t1 t3 t4 t5)a, ~w(t5 t4 t3 t1 t2)a}

      # Hand-written orderings: NULLS LAST for asc, NULLS FIRST for desc, ties by id in the direction
      expected = %{
        {:user, :asc} => ~w(t2 t5 t1 t4 t3)a,
        {:user, :desc} => ~w(t3 t4 t1 t5 t2)a,
        {:activity_title, :asc} => ~w(t3 t5 t1 t2 t4)a,
        {:activity_title, :desc} => ~w(t4 t2 t1 t5 t3)a,
        {:attempt_number, :asc} => ~w(t1 t2 t4 t3 t5)a,
        {:attempt_number, :desc} => ~w(t5 t3 t4 t2 t1)a,
        {:page_title, :asc} => ~w(t1 t3 t5 t2 t4)a,
        {:page_title, :desc} => ~w(t4 t2 t5 t3 t1)a,
        {:resource_attempt_number, :asc} => ~w(t1 t3 t4 t2 t5)a,
        {:resource_attempt_number, :desc} => ~w(t5 t2 t4 t3 t1)a,
        {:activity_type_id, :asc} => type_asc,
        {:activity_type_id, :desc} => type_desc,
        {:graded, :asc} => ~w(t2 t4 t1 t3 t5)a,
        {:graded, :desc} => ~w(t5 t3 t1 t4 t2)a,
        {:date_submitted, :asc} => ~w(t1 t4 t2 t5 t3)a,
        {:date_submitted, :desc} => ~w(t3 t5 t2 t4 t1)a
      }

      {:ok, Map.merge(map, %{expected: expected, no_filter: @no_filter})}
    end

    test "position, total and neighbours follow the hand-written order for every key, direction and anchor",
         ctx do
      for {{field, direction}, order} <- ctx.expected do
        sorting = %Sorting{field: field, direction: direction}
        rows = browse_rows(ctx.section, sorting, @no_filter)

        assert Enum.map(rows, & &1.id) == Enum.map(order, &ctx[&1].id),
               "table order #{field} #{direction}"

        for {tag, index} <- Enum.with_index(order) do
          row = Enum.find(rows, &(&1.id == ctx[tag].id))
          anchor = %{id: row.id, key: ManualGrading.sort_key_value(row, field)}

          assert ManualGrading.submission_position(ctx.section, sorting, @no_filter, anchor) == %{
                   position: index + 1,
                   total: 5,
                   previous_id: order |> Enum.at(index - 1) |> id_or_nil(ctx, index - 1),
                   next_id: order |> Enum.at(index + 1) |> id_or_nil(ctx, index + 1),
                   anchor_eligible?: true
                 },
                 "#{field} #{direction} anchor #{tag}"
        end
      end
    end

    test "sort_key_value/2 captures the value the table sorts by, for every key", ctx do
      row =
        ctx.section
        |> browse_rows(%Sorting{field: :date_submitted, direction: :asc}, @no_filter)
        |> Enum.find(&(&1.id == ctx.t1.id))

      mc = Oli.Activities.get_registration_by_slug("oli_multiple_choice")

      assert ManualGrading.sort_key_value(row, :user) == "Beta"
      assert ManualGrading.sort_key_value(row, :activity_title) == "Essay"
      assert ManualGrading.sort_key_value(row, :attempt_number) == 1
      assert ManualGrading.sort_key_value(row, :page_title) == "Page one"
      assert ManualGrading.sort_key_value(row, :resource_attempt_number) == 1
      assert ManualGrading.sort_key_value(row, :activity_type_id) == mc.id
      assert ManualGrading.sort_key_value(row, :graded) == true
      assert ManualGrading.sort_key_value(row, :date_submitted) == ~U[2026-10-01 00:00:00Z]
    end

    test "an anchor that left the queue keeps its captured place: no position, neighbours from the captured key",
         ctx do
      sorting = %Sorting{field: :date_submitted, direction: :desc}
      row = ctx.section |> browse_rows(sorting, @no_filter) |> Enum.find(&(&1.id == ctx.t4.id))
      anchor = %{id: row.id, key: ManualGrading.sort_key_value(row, :date_submitted)}

      Repo.update!(
        Ecto.Changeset.change(ctx.t4,
          lifecycle_state: :evaluated,
          date_submitted: DateTime.utc_now() |> DateTime.truncate(:second)
        )
      )

      assert ManualGrading.submission_position(ctx.section, sorting, @no_filter, anchor) == %{
               position: nil,
               total: 4,
               previous_id: ctx.t2.id,
               next_id: ctx.t1.id,
               anchor_eligible?: false
             }

      assert ManualGrading.submission_position(
               ctx.section,
               %{sorting | direction: :asc},
               @no_filter,
               anchor
             ) == %{
               position: nil,
               total: 4,
               previous_id: ctx.t1.id,
               next_id: ctx.t2.id,
               anchor_eligible?: false
             }
    end

    test "an anchor with a NULL key that left the queue is placed with the NULLs", ctx do
      sorting = %Sorting{field: :date_submitted, direction: :desc}
      anchor = %{id: ctx.t3.id, key: nil}

      Repo.update!(
        Ecto.Changeset.change(ctx.t3,
          lifecycle_state: :evaluated,
          date_submitted: DateTime.utc_now() |> DateTime.truncate(:second)
        )
      )

      assert ManualGrading.submission_position(ctx.section, sorting, @no_filter, anchor) == %{
               position: nil,
               total: 4,
               previous_id: nil,
               next_id: ctx.t5.id,
               anchor_eligible?: false
             }
    end

    test "an anchor excluded by the filters is not eligible, not counted, and keeps its neighbours",
         ctx do
      sorting = %Sorting{field: :date_submitted, direction: :desc}
      options = %{@no_filter | user_ids: [ctx.u2.id]}
      anchor = %{id: ctx.t1.id, key: ctx.t1.date_submitted}

      assert ManualGrading.submission_position(ctx.section, sorting, options, anchor) == %{
               position: nil,
               total: 2,
               previous_id: ctx.t2.id,
               next_id: nil,
               anchor_eligible?: false
             }
    end

    test "rows excluded by the filters between two neighbours are skipped", ctx do
      sorting = %Sorting{field: :date_submitted, direction: :desc}
      options = %{@no_filter | activity_ids: [ctx.a1.resource.id, ctx.a3.resource.id]}
      anchor = %{id: ctx.t5.id, key: ctx.t5.date_submitted}

      assert ManualGrading.submission_position(ctx.section, sorting, options, anchor) == %{
               position: 2,
               total: 4,
               previous_id: ctx.t3.id,
               next_id: ctx.t4.id,
               anchor_eligible?: true
             }
    end

    test "an empty eligible set gives total 0 and no neighbours", ctx do
      sorting = %Sorting{field: :date_submitted, direction: :desc}
      options = %{@no_filter | text_search: "nothing matches this"}
      anchor = %{id: ctx.t1.id, key: ctx.t1.date_submitted}

      assert ManualGrading.submission_position(ctx.section, sorting, options, anchor) == %{
               position: nil,
               total: 0,
               previous_id: nil,
               next_id: nil,
               anchor_eligible?: false
             }
    end

    defp browse_rows(section, sorting, options) do
      ManualGrading.browse_submitted_attempts(
        section,
        %Paging{limit: 50, offset: 0},
        sorting,
        options
      )
    end

    defp id_or_nil(_tag, _ctx, index) when index < 0, do: nil
    defp id_or_nil(nil, _ctx, _index), do: nil
    defp id_or_nil(tag, ctx, _index), do: ctx[tag].id
  end

  describe "fetch_submitted_attempt/2" do
    setup do
      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_user(%{family_name: "Pending"}, :u1)
        |> Seeder.add_activity(%{title: "Essay"}, :publication, :project, :author, :act)
        |> Seeder.create_section_resources()
        |> Seeder.create_resource_attempt(%{attempt_number: 1}, :u1, :page1, :revision1, :ra)
        |> add_submitted_activity(:ra, :act, :pending)
        |> add_evaluated_activity(:ra, :act, :scored)

      foreign =
        Oli.Factory.insert(:activity_attempt,
          lifecycle_state: :submitted,
          resource_attempt:
            Oli.Factory.build(:resource_attempt,
              resource_access:
                Oli.Factory.build(:resource_access, section: Oli.Factory.insert(:section))
            )
        )

      {:ok, Map.put(map, :foreign, foreign)}
    end

    test "returns the pending attempt of the section with the same fields as the table rows",
         ctx do
      row = ManualGrading.fetch_submitted_attempt(ctx.section, ctx.pending.id)

      assert row.id == ctx.pending.id
      assert row.user.id == ctx.u1.id
      assert row.activity_title == "Essay"
      assert row.page_title == ctx.revision1.title
      assert row.resource_attempt_number == 1
      assert row.resource_attempt_guid == ctx.ra.attempt_guid
      assert row.revision.id == ctx.act.revision.id
    end

    test "returns nil for a scored attempt, for another section's pending attempt, and for an unknown id",
         ctx do
      assert ManualGrading.fetch_submitted_attempt(ctx.section, ctx.scored.id) == nil
      assert ManualGrading.fetch_submitted_attempt(ctx.section, ctx.foreign.id) == nil
      assert ManualGrading.fetch_submitted_attempt(ctx.section, 999_999) == nil
    end
  end

  describe "apply_manual_scoring/3" do
    setup do
      map = Seeder.base_project_with_resource2()
      Oli.Resources.update_revision(map.revision2, %{graded: true})

      context =
        map
        |> Seeder.create_section()
        |> Seeder.add_user(%{}, :user1)
        |> Seeder.add_activity(
          %{title: "activity manual"},
          :publication,
          :project,
          :author,
          :activity_a
        )
        |> Seeder.create_section_resources()
        |> Seeder.create_resource_attempt(
          %{attempt_number: 1, lifecycle_state: :submitted},
          :user1,
          :page2,
          :revision2,
          :attempt1
        )
        |> add_submitted_activity(:attempt1, :activity_a, :attempt_1a)

      reward_context =
        ExperimentRewardSetup.create(context.project, context.section, context.attempt1)

      Map.put(context, :reward_context, reward_context)
    end

    test "applies manual scoring and updates states", %{
      section: section,
      attempt_1a: attempt_1a,
      reward_context: reward_context
    } do
      results =
        ManualGrading.browse_submitted_attempts(
          section,
          %Paging{limit: 1, offset: 0},
          %Sorting{field: :date_submitted, direction: :desc},
          %BrowseOptions{
            user_ids: [],
            activity_ids: [],
            page_ids: [],
            graded: nil,
            text_search: nil
          }
        )

      attempt = Enum.find(results, fn a -> a.id == attempt_1a.id end)
      assert attempt.lifecycle_state == :submitted
      assert attempt.graded

      # Applies manual scoring
      result =
        Oli.Delivery.Attempts.ManualGrading.apply_manual_scoring(
          section,
          attempt,
          create_score_feedbacks(attempt)
        )

      # Returns {:ok, [guid, ...]}
      assert {:ok, part_guids} = result
      assert is_list(part_guids)
      assert length(part_guids) == 1

      # Verifies that the returned GUIDs are the ones associated with the part attempts
      part_attempts = Oli.Delivery.Attempts.Core.get_latest_part_attempts(attempt_1a.attempt_guid)
      expected_guids = Enum.map(part_attempts, & &1.attempt_guid)
      assert Enum.sort(part_guids) == Enum.sort(expected_guids)

      # The activity attempt must be evaluated
      aa = Oli.Delivery.Attempts.Core.get_activity_attempt_by(id: attempt_1a.id)
      assert aa.lifecycle_state == :evaluated

      # The resource attempt must be evaluated
      ra = Oli.Delivery.Attempts.Core.get_resource_attempt_by(id: aa.resource_attempt_id)
      assert ra.lifecycle_state == :evaluated

      assert Oli.Repo.aggregate(AcceptedReward, :count) == 1

      policy_state = Oli.Repo.get!(PolicyState, reward_context.policy_state.id)
      assert policy_state.state["condition-a"]["posterior_alpha"] == 2.0
      assert policy_state.state["condition-a"]["posterior_beta"] == 1.0
    end

    @tag capture_log: true
    test "rolls back manual scoring when synchronous reward processing fails", %{
      section: section,
      attempt_1a: attempt_1a,
      reward_context: reward_context
    } do
      attempt =
        ManualGrading.browse_submitted_attempts(
          section,
          %Paging{limit: 1, offset: 0},
          %Sorting{field: :date_submitted, direction: :desc},
          %BrowseOptions{
            user_ids: [],
            activity_ids: [],
            page_ids: [],
            graded: nil,
            text_search: nil
          }
        )
        |> Enum.find(fn attempt -> attempt.id == attempt_1a.id end)

      invalid_state =
        put_in(reward_context.policy_state.state, ["condition-a", "successes"], -1)

      reward_context.policy_state
      |> PolicyState.changeset(%{state: invalid_state})
      |> Repo.update!()

      assert_raise MatchError, fn ->
        ManualGrading.apply_manual_scoring(
          section,
          attempt,
          create_score_feedbacks(attempt)
        )
      end

      assert Core.get_activity_attempt_by(id: attempt_1a.id).lifecycle_state == :submitted
      assert Repo.aggregate(AcceptedReward, :count) == 0
    end

    test "preserves file upload responses during manual scoring", %{
      section: section,
      attempt_1a: attempt_1a
    } do
      # Create a part attempt
      part_attempt =
        Oli.Delivery.Attempts.Core.get_latest_part_attempts(attempt_1a.attempt_guid)
        |> List.first()

      # Update the part attempt
      file_upload_response = %{
        "files" => [
          %{
            "name" => "test_file.pdf",
            "url" => "https://example.com/test_file.pdf",
            "size" => 1024
          }
        ],
        "input" => "some text input"
      }

      {:ok, _} =
        part_attempt
        |> Ecto.Changeset.change(response: file_upload_response)
        |> Oli.Repo.update()

      results =
        ManualGrading.browse_submitted_attempts(
          section,
          %Paging{limit: 1, offset: 0},
          %Sorting{field: :date_submitted, direction: :desc},
          %BrowseOptions{
            user_ids: [],
            activity_ids: [],
            page_ids: [],
            graded: nil,
            text_search: nil
          }
        )

      attempt = Enum.find(results, fn a -> a.id == attempt_1a.id end)

      # Apply manual scoring
      {:ok, _} =
        Oli.Delivery.Attempts.ManualGrading.apply_manual_scoring(
          section,
          attempt,
          create_score_feedbacks(attempt)
        )

      # Verify that the response is preserved
      updated_part_attempts =
        Oli.Delivery.Attempts.Core.get_latest_part_attempts(attempt_1a.attempt_guid)

      updated_part_attempt = List.first(updated_part_attempts)

      # The response should match the original response
      assert updated_part_attempt.response["files"] == file_upload_response["files"]
      assert updated_part_attempt.response["input"] == file_upload_response["input"]
    end

    test "returns only manual part attempt guids when activity has mixed grading approaches", %{
      section: section,
      attempt_1a: attempt_1a
    } do
      automatic_part =
        %Part{id: "2", responses: [], hints: [], grading_approach: :automatic, out_of: 5.0}

      {:ok, _automatic_part_attempt} =
        Core.create_part_attempt(%{
          attempt_guid: UUID.uuid4(),
          activity_attempt_id: attempt_1a.id,
          attempt_number: 1,
          part_id: automatic_part.id,
          grading_approach: :automatic,
          date_submitted: DateTime.utc_now(),
          lifecycle_state: :submitted,
          datashop_session_id: "mixed-part-test-session",
          score: 4.0,
          out_of: 5.0
        })

      results =
        ManualGrading.browse_submitted_attempts(
          section,
          %Paging{limit: 1, offset: 0},
          %Sorting{field: :date_submitted, direction: :desc},
          %BrowseOptions{
            user_ids: [],
            activity_ids: [],
            page_ids: [],
            graded: nil,
            text_search: nil
          }
        )

      attempt = Enum.find(results, fn a -> a.id == attempt_1a.id end)

      manual_part_attempt_guids =
        Core.get_latest_part_attempts(attempt.attempt_guid)
        |> Enum.filter(&(&1.grading_approach == :manual))
        |> Enum.map(& &1.attempt_guid)

      assert {:ok, returned_guids} =
               ManualGrading.apply_manual_scoring(
                 section,
                 attempt,
                 create_score_feedbacks(attempt)
               )

      assert Enum.sort(returned_guids) == Enum.sort(manual_part_attempt_guids)
    end

    test "applies manual scoring and evaluates activity even with untouched automatic parts", %{
      section: section,
      attempt_1a: attempt_1a
    } do
      automatic_part =
        %Part{id: "2", responses: [], hints: [], grading_approach: :automatic, out_of: 1.0}

      {:ok, _automatic_part_attempt} =
        Core.create_part_attempt(%{
          attempt_guid: UUID.uuid4(),
          activity_attempt_id: attempt_1a.id,
          attempt_number: 1,
          part_id: automatic_part.id,
          grading_approach: :automatic,
          lifecycle_state: :active,
          datashop_session_id: "stale-after-apply-test-session",
          out_of: 1.0
        })

      results =
        ManualGrading.browse_submitted_attempts(
          section,
          %Paging{limit: 1, offset: 0},
          %Sorting{field: :date_submitted, direction: :desc},
          %BrowseOptions{
            user_ids: [],
            activity_ids: [],
            page_ids: [],
            graded: nil,
            text_search: nil
          }
        )

      attempt = Enum.find(results, fn a -> a.id == attempt_1a.id end)

      assert {:ok, _} =
               ManualGrading.apply_manual_scoring(
                 section,
                 attempt,
                 create_score_feedbacks(attempt)
               )

      aa = Core.get_activity_attempt_by(id: attempt_1a.id)
      assert aa.lifecycle_state == :evaluated

      ra = Core.get_resource_attempt_by(id: aa.resource_attempt_id)
      assert ra.lifecycle_state == :evaluated

      assert [] ==
               ManualGrading.browse_submitted_attempts(
                 section,
                 %Paging{limit: 10, offset: 0},
                 %Sorting{field: :date_submitted, direction: :desc},
                 %BrowseOptions{
                   user_ids: [],
                   activity_ids: [],
                   page_ids: [],
                   graded: nil,
                   text_search: nil
                 }
               )
    end
  end

  describe "apply_manual_scoring/3 for adaptive manually graded CAPI parts" do
    setup do
      adaptive_registration = Oli.Activities.get_registration_by_slug("oli_adaptive")

      adaptive_content = %{
        "partsLayout" => [
          %{
            "id" => "janus_capi_iframe-1",
            "type" => "janus-capi-iframe",
            "custom" => %{"title" => "Simulation", "maxScore" => 1}
          },
          %{
            "id" => "janus_navigation_button-1",
            "type" => "janus-navigation-button",
            "custom" => %{"title" => "Continue"}
          }
        ],
        "authoring" => %{
          "parts" => [
            %{
              "id" => "janus_capi_iframe-1",
              "type" => "janus-capi-iframe",
              "gradingApproach" => "manual",
              "outOf" => 1
            },
            %{
              "id" => "janus_navigation_button-1",
              "type" => "janus-navigation-button",
              "gradingApproach" => "automatic"
            }
          ]
        }
      }

      map = Seeder.base_project_with_resource2()
      Oli.Resources.update_revision(map.revision2, %{graded: true})

      map
      |> Seeder.create_section()
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_activity(
        %{
          title: "adaptive CAPI manual",
          activity_type_id: adaptive_registration.id,
          content: adaptive_content
        },
        :activity_a
      )
      |> Seeder.create_section_resources()
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1, lifecycle_state: :submitted},
        :user1,
        :page2,
        :revision2,
        :attempt1
      )
      |> Seeder.create_activity_attempt(
        %{attempt_number: 1, transformed_model: %{some: :thing}, lifecycle_state: :submitted},
        :activity_a,
        :attempt1,
        :attempt_1a
      )
      |> Seeder.create_part_attempt(
        %{
          attempt_number: 1,
          grading_approach: :manual,
          date_submitted: DateTime.utc_now(),
          lifecycle_state: :submitted,
          response: %{
            "input" => [
              %{"path" => "janus_capi_iframe-1.simScore", "value" => "85"}
            ]
          },
          out_of: 1.0
        },
        %Part{id: "janus_capi_iframe-1", responses: [], hints: [], grading_approach: :manual},
        :attempt_1a,
        :capi_part_attempt
      )
      |> Seeder.create_part_attempt(
        %{
          attempt_number: 1,
          grading_approach: :automatic,
          lifecycle_state: :active,
          response: %{}
        },
        %Part{
          id: "janus_navigation_button-1",
          responses: [],
          hints: [],
          grading_approach: :automatic
        },
        :attempt_1a,
        :navigation_part_attempt
      )
    end

    test "applies manual scoring to manually graded CAPI without requiring native inputs", %{
      section: section,
      attempt_1a: attempt_1a,
      capi_part_attempt: capi_part_attempt
    } do
      results =
        ManualGrading.browse_submitted_attempts(
          section,
          %Paging{limit: 1, offset: 0},
          %Sorting{field: :date_submitted, direction: :desc},
          %BrowseOptions{
            user_ids: [],
            activity_ids: [],
            page_ids: [],
            graded: nil,
            text_search: nil
          }
        )

      attempt = Enum.find(results, fn a -> a.id == attempt_1a.id end)

      assert {:ok, [returned_guid]} =
               ManualGrading.apply_manual_scoring(
                 section,
                 attempt,
                 %{
                   capi_part_attempt.attempt_guid => %{
                     score: 1.0,
                     out_of: 1.0,
                     feedback: "CAPI work reviewed"
                   }
                 }
               )

      assert returned_guid == capi_part_attempt.attempt_guid

      aa = Core.get_activity_attempt_by(id: attempt_1a.id)
      assert aa.lifecycle_state == :evaluated

      capi_part = Core.get_part_attempt_by(attempt_guid: capi_part_attempt.attempt_guid)
      assert capi_part.lifecycle_state == :evaluated
      assert capi_part.score == 1.0
      assert capi_part.out_of == 1.0
    end
  end

  describe "apply_manual_scoring/3 for submitted ungraded attempts" do
    setup do
      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_activity(
        %{title: "activity manual ungraded"},
        :publication,
        :project,
        :author,
        :activity_a
      )
      |> Seeder.create_section_resources()
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1, lifecycle_state: :submitted},
        :user1,
        :page1,
        :revision1,
        :attempt1
      )
      |> add_submitted_activity(:attempt1, :activity_a, :attempt_1a)
    end

    test "evaluates the resource attempt once all manual grading is complete", %{
      section: section,
      attempt_1a: attempt_1a
    } do
      [attempt] =
        ManualGrading.browse_submitted_attempts(
          section,
          %Paging{limit: 10, offset: 0},
          %Sorting{field: :date_submitted, direction: :desc},
          %BrowseOptions{
            user_ids: [],
            activity_ids: [],
            page_ids: [],
            graded: nil,
            text_search: nil
          }
        )

      assert {:ok, _} =
               ManualGrading.apply_manual_scoring(
                 section,
                 attempt,
                 create_score_feedbacks(attempt)
               )

      activity_attempt = Core.get_activity_attempt_by(id: attempt_1a.id)
      assert activity_attempt.lifecycle_state == :evaluated

      resource_attempt = Core.get_resource_attempt_by(attempt_guid: attempt.resource_attempt_guid)
      assert resource_attempt.lifecycle_state == :evaluated
    end
  end

  describe "resolving stale submitted attempts" do
    setup do
      map = Seeder.base_project_with_resource2()
      Oli.Resources.update_revision(map.revision2, %{graded: true})

      map
      |> Seeder.create_section()
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_activity(
        %{title: "title stale"},
        :publication,
        :project,
        :author,
        :activity_stale
      )
      |> Seeder.create_section_resources()
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1, lifecycle_state: :submitted},
        :user1,
        :page2,
        :revision2,
        :attempt_stale
      )
      |> add_stale_submitted_activity(:attempt_stale, :activity_stale, :attempt_stale_activity)
    end

    test "repairing a stale attempt removes it from the manual grading queue", %{
      section: section,
      attempt_stale_activity: stale_attempt
    } do
      [attempt] =
        ManualGrading.browse_submitted_attempts(
          section,
          %Paging{limit: 10, offset: 0},
          %Sorting{field: :date_submitted, direction: :desc},
          %BrowseOptions{
            user_ids: [],
            activity_ids: [],
            page_ids: [],
            graded: nil,
            text_search: nil
          }
        )

      assert attempt.id == stale_attempt.id

      assert {:ok, :ok} = ManualGrading.resolve_stale_attempt(section, attempt)

      activity_attempt = Core.get_activity_attempt_by(attempt_guid: attempt.attempt_guid)
      assert activity_attempt.lifecycle_state == :evaluated

      resource_attempt = Core.get_resource_attempt_by(attempt_guid: attempt.resource_attempt_guid)
      assert resource_attempt.lifecycle_state == :evaluated

      assert [] ==
               ManualGrading.browse_submitted_attempts(
                 section,
                 %Paging{limit: 10, offset: 0},
                 %Sorting{field: :date_submitted, direction: :desc},
                 %BrowseOptions{
                   user_ids: [],
                   activity_ids: [],
                   page_ids: [],
                   graded: nil,
                   text_search: nil
                 }
               )
    end
  end
end
