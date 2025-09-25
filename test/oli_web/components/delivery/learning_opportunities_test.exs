defmodule OliWeb.Components.Delivery.LearningOpportunitiesTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.LearningOpportunities
  alias OliWeb.Common.SessionContext

  describe "opportunities/1" do
    test "renders opportunities with title and description" do
      ctx = %SessionContext{
        user: %{id: 1},
        browser_timezone: "America/New_York",
        is_liveview: true,
        author: nil,
        local_tz: "America/New_York"
      }

      assigns = %{ctx: ctx}

      html = render_component(&LearningOpportunities.opportunities/1, assigns)

      assert html =~ "Opportunities"
      assert html =~ "for further learning"
      assert html =~ "These are areas you could revisit."
    end

    test "renders with correct styling classes" do
      ctx = %SessionContext{
        user: %{id: 1},
        browser_timezone: "America/New_York",
        is_liveview: true,
        author: nil,
        local_tz: "America/New_York"
      }

      assigns = %{ctx: ctx}

      html = render_component(&LearningOpportunities.opportunities/1, assigns)

      # Check for expected CSS classes
      assert html =~ "bg-white"
      assert html =~ "dark:bg-gray-800"
      assert html =~ "shadow"
      assert html =~ "p-4"
      assert html =~ "hidden lg:inline"
      assert html =~ "text-gray-500"
    end

    test "renders with dark mode support" do
      ctx = %SessionContext{
        user: %{id: 1},
        browser_timezone: "America/New_York",
        is_liveview: true,
        author: nil,
        local_tz: "America/New_York"
      }

      assigns = %{ctx: ctx}

      html = render_component(&LearningOpportunities.opportunities/1, assigns)

      # Check dark mode classes
      assert html =~ "dark:bg-gray-800"
    end
  end

  describe "learning_opportunity/1" do
    test "renders course content opportunity" do
      opportunity = %LearningOpportunities.LearningOpportunity{
        type: :course_content,
        title: "1.0 Intro to Chemistry 101: Foundational Content",
        progress: {:percent_complete, 20},
        complete_by_date: "Oct 3, 2023",
        open_href: "#"
      }

      assigns = %{learning_opportunity: opportunity}

      html = render_component(&LearningOpportunities.learning_opportunity/1, assigns)

      assert html =~ "Course Content"
      assert html =~ "1.0 Intro to Chemistry 101: Foundational Content"
      assert html =~ "20"
      assert html =~ "Read by Oct 3, 2023"
      assert html =~ "Open"
      assert html =~ "bg-green-700"
    end

    test "renders graded assignment opportunity" do
      opportunity = %LearningOpportunities.LearningOpportunity{
        type: :graded_assignment,
        title: "1.0 Intro to Chemistry 101: Chemistry Assignment",
        progress: {:score, 3, 10},
        complete_by_date: "Oct 3, 2023",
        open_href: "#"
      }

      assigns = %{learning_opportunity: opportunity}

      html = render_component(&LearningOpportunities.learning_opportunity/1, assigns)

      assert html =~ "Graded Assignment"
      assert html =~ "1.0 Intro to Chemistry 101: Chemistry Assignment"
      assert html =~ "Score:"
      assert html =~ "3/10"
      assert html =~ "text-red-500"
      assert html =~ "bg-fuchsia-800"
    end

    test "renders mission activities opportunity" do
      opportunity = %LearningOpportunities.LearningOpportunity{
        type: :mission_activities,
        title: "Mission Activity: Water Pollution on Planet Earth",
        progress: {:activities_completed, 5, 10},
        complete_by_date: "Oct 3, 2023",
        open_href: "#"
      }

      assigns = %{learning_opportunity: opportunity}

      html = render_component(&LearningOpportunities.learning_opportunity/1, assigns)

      assert html =~ "Mission Activities"
      assert html =~ "Mission Activity: Water Pollution on Planet Earth"
      assert html =~ "Activities completed:"
      assert html =~ "5/10"
      assert html =~ "text-yellow-500"
      assert html =~ "bg-blue-500"
    end

    test "renders with correct styling classes" do
      opportunity = %LearningOpportunities.LearningOpportunity{
        type: :course_content,
        title: "Test Opportunity",
        progress: {:percent_complete, 50},
        complete_by_date: "Oct 3, 2023",
        open_href: "#"
      }

      assigns = %{learning_opportunity: opportunity}

      html = render_component(&LearningOpportunities.learning_opportunity/1, assigns)

      # Check for expected CSS classes
      assert html =~ "my-2"
      assert html =~ "border-t"
      assert html =~ "border-gray-200"
      assert html =~ "dark:border-gray-700"
      assert html =~ "flex-1"
      assert html =~ "rounded"
      assert html =~ "p-8"
      assert html =~ "py-4"
      assert html =~ "mb-2"
      assert html =~ "font-bold"
    end

    test "renders with dark mode support" do
      opportunity = %LearningOpportunities.LearningOpportunity{
        type: :course_content,
        title: "Test Opportunity",
        progress: {:percent_complete, 50},
        complete_by_date: "Oct 3, 2023",
        open_href: "#"
      }

      assigns = %{learning_opportunity: opportunity}

      html = render_component(&LearningOpportunities.learning_opportunity/1, assigns)

      # Check dark mode classes
      assert html =~ "dark:border-gray-700"
      assert html =~ "dark:bg-gray-700"
    end

    test "renders button with correct styling" do
      opportunity = %LearningOpportunities.LearningOpportunity{
        type: :course_content,
        title: "Test Opportunity",
        progress: {:percent_complete, 50},
        complete_by_date: "Oct 3, 2023",
        open_href: "#"
      }

      assigns = %{learning_opportunity: opportunity}

      html = render_component(&LearningOpportunities.learning_opportunity/1, assigns)

      # Check button styling
      assert html =~ "btn"
      assert html =~ "text-white"
      assert html =~ "hover:text-white"
      assert html =~ "inline-flex"
      assert html =~ "ml-2"
      assert html =~ "bg-delivery-primary"
      assert html =~ "hover:bg-delivery-primary-600"
      assert html =~ "active:bg-delivery-primary-700"
    end
  end

  describe "helper function behavior through public interface" do
    test "badge_name behavior returns correct names for different types" do
      # Test through the public interface instead
      course_content = %LearningOpportunities.LearningOpportunity{
        type: :course_content,
        title: "Test",
        progress: {:percent_complete, 50},
        complete_by_date: "2024-01-01",
        open_href: "#"
      }

      assigns = %{learning_opportunity: course_content}
      html = render_component(&LearningOpportunities.learning_opportunity/1, assigns)
      assert html =~ "Course Content"
    end

    test "badge_bg_color behavior returns correct colors for different types" do
      # Test through the public interface instead
      course_content = %LearningOpportunities.LearningOpportunity{
        type: :course_content,
        title: "Test",
        progress: {:percent_complete, 50},
        complete_by_date: "2024-01-01",
        open_href: "#"
      }

      assigns = %{learning_opportunity: course_content}
      html = render_component(&LearningOpportunities.learning_opportunity/1, assigns)
      assert html =~ "bg-green-700"
    end
  end
end
