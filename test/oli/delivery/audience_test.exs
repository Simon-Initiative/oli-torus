defmodule Oli.Delivery.AudienceTest do
  use Oli.DataCase

  import Oli.Utils.Seeder.Utils

  alias Oli.Utils.Seeder
  alias Oli.Delivery.Audience

  describe "audience" do
    setup do
      %{}
      |> Seeder.Project.create_admin(admin_tag: :admin)
      |> Seeder.Project.create_author(author_tag: :author)
      |> Seeder.Project.create_sample_project(
        ref(:author),
        project_tag: :proj,
        publication_tag: :pub,
        curriculum_revision_tag: :curriculum,
        unscored_page1_tag: :unscored_page1,
        unscored_page1_activity_tag: :unscored_page1_activity,
        scored_page2_tag: :scored_page2,
        scored_page2_activity_tag: :scored_page2_activity
      )
      |> Seeder.Project.ensure_published(ref(:pub), publication_tag: :pub)
      |> Seeder.Section.create_section(
        ref(:proj),
        ref(:pub),
        nil,
        %{},
        section_tag: :section
      )
      |> Seeder.Section.create_and_enroll_learner(
        ref(:section),
        %{},
        user_tag: :student1
      )
      |> Seeder.Section.create_and_enroll_instructor(
        ref(:section),
        %{},
        user_tag: :instructor1
      )
    end

    test "is_intended_audience?/4", %{
      section: section,
      student1: student1,
      instructor1: instructor1,
      admin: admin
    } do
      review_mode = false

      assert Audience.is_intended_audience?(nil, student1, section.slug, review_mode) == true
      assert Audience.is_intended_audience?(nil, instructor1, section.slug, review_mode) == true
      assert Audience.is_intended_audience?(nil, admin, section.slug, review_mode) == true

      assert Audience.is_intended_audience?("always", student1, section.slug, review_mode) == true

      assert Audience.is_intended_audience?("always", instructor1, section.slug, review_mode) ==
               true

      assert Audience.is_intended_audience?("always", admin, section.slug, review_mode) == true

      assert Audience.is_intended_audience?("instructor", student1, section.slug, review_mode) ==
               false

      assert Audience.is_intended_audience?("instructor", instructor1, section.slug, review_mode) ==
               true

      assert Audience.is_intended_audience?("instructor", admin, section.slug, review_mode) ==
               true

      assert Audience.is_intended_audience?("feedback", student1, section.slug, review_mode) ==
               false

      assert Audience.is_intended_audience?("feedback", instructor1, section.slug, review_mode) ==
               false

      assert Audience.is_intended_audience?("feedback", admin, section.slug, review_mode) == false

      review_mode = true

      assert Audience.is_intended_audience?("feedback", student1, section.slug, review_mode) ==
               true

      assert Audience.is_intended_audience?("feedback", instructor1, section.slug, review_mode) ==
               true

      assert Audience.is_intended_audience?("feedback", admin, section.slug, review_mode) == true
    end
  end
end
