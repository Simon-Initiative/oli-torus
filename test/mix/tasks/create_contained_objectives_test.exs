defmodule Mix.Tasks.CreateContainedObjectivesTest do
  use Oban.Testing, repo: Oli.Repo
  use Oli.DataCase

  alias Mix.Tasks.CreateContainedObjectives
  alias Oli.Delivery.Sections.ContainedObjectivesBuilder
  alias Oli.Delivery.Sections
  alias Oli.Factory

  describe "run/1" do
    test "enqueues not started sections and set them as pending" do
      [section_1, section_2] = Factory.insert_list(2, :section, v25_migration: :not_started)

      assert :ok == CreateContainedObjectives.run([])

      assert_enqueued(
        worker: ContainedObjectivesBuilder,
        args: %{
          "section_slug" => section_1.slug
        }
      )

      assert_enqueued(
        worker: ContainedObjectivesBuilder,
        args: %{
          "section_slug" => section_2.slug
        }
      )

      assert Sections.get_section_by(slug: section_1.slug).v25_migration == :pending
      assert Sections.get_section_by(slug: section_2.slug).v25_migration == :pending
    end

    test "does not enqueue pending or done sections" do
      section_1 = Factory.insert(:section, v25_migration: :pending)
      section_2 = Factory.insert(:section, v25_migration: :done)

      assert :ok == CreateContainedObjectives.run([])

      refute_enqueued(
        worker: ContainedObjectivesBuilder,
        args: %{
          "section_slug" => section_1.slug
        }
      )

      refute_enqueued(
        worker: ContainedObjectivesBuilder,
        args: %{
          "section_slug" => section_2.slug
        }
      )

      assert Sections.get_section_by(slug: section_1.slug).v25_migration ==
               section_1.v25_migration

      assert Sections.get_section_by(slug: section_2.slug).v25_migration ==
               section_2.v25_migration
    end

    test "enqueues all sections and set them as pending when --all flag is passed" do
      [section_1, section_2] = Factory.insert_list(2, :section, v25_migration: :not_started)
      section_3 = Factory.insert(:section, v25_migration: :pending)
      section_4 = Factory.insert(:section, v25_migration: :done)

      assert :ok == CreateContainedObjectives.run(["--all"])

      assert_enqueued(
        worker: ContainedObjectivesBuilder,
        args: %{
          "section_slug" => section_1.slug
        }
      )

      assert_enqueued(
        worker: ContainedObjectivesBuilder,
        args: %{
          "section_slug" => section_2.slug
        }
      )

      assert_enqueued(
        worker: ContainedObjectivesBuilder,
        args: %{
          "section_slug" => section_3.slug
        }
      )

      assert_enqueued(
        worker: ContainedObjectivesBuilder,
        args: %{
          "section_slug" => section_4.slug
        }
      )

      assert Sections.get_section_by(slug: section_1.slug).v25_migration == :pending
      assert Sections.get_section_by(slug: section_2.slug).v25_migration == :pending
      assert Sections.get_section_by(slug: section_3.slug).v25_migration == :pending
      assert Sections.get_section_by(slug: section_4.slug).v25_migration == :pending
    end
  end
end
