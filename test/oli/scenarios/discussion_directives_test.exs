defmodule Oli.Scenarios.DiscussionDirectivesTest do
  use Oli.DataCase

  alias Oli.Scenarios.DirectiveParser
  alias Oli.Scenarios.Engine

  describe "discussion_post" do
    test "rejects anonymous posts when anonymous posting is disabled" do
      yaml = """
      - project:
          name: "anonymous_disabled_course"
          title: "Anonymous Disabled Course"
          root:
            children:
              - page: "Welcome"

      - product:
          name: "anonymous_disabled_product"
          title: "Anonymous Disabled Product"
          from: "anonymous_disabled_course"

      - discussion_config:
          section: "anonymous_disabled_product"
          enabled: true
          anonymous_posting: false

      - section:
          name: "anonymous_disabled_section"
          title: "Anonymous Disabled Section"
          from: "anonymous_disabled_product"

      - user:
          name: "anonymous_student"
          type: "student"
          email: "anonymous_student@test.edu"

      - enroll:
          user: "anonymous_student"
          section: "anonymous_disabled_section"

      - discussion_post:
          name: "anonymous_post"
          student: "anonymous_student"
          section: "anonymous_disabled_section"
          anonymous: true
          body: "This anonymous post should be rejected."
      """

      result = yaml |> DirectiveParser.parse_yaml!() |> Engine.execute()

      assert [{_, error}] = result.errors
      assert error =~ "Anonymous posting is not enabled"
    end

    test "rejects replies to posts from another section" do
      yaml = """
      - project:
          name: "cross_section_reply_course"
          title: "Cross Section Reply Course"
          root:
            children:
              - page: "Welcome"

      - product:
          name: "cross_section_reply_product"
          title: "Cross Section Reply Product"
          from: "cross_section_reply_course"

      - discussion_config:
          section: "cross_section_reply_product"
          enabled: true
          auto_accept: true

      - section:
          name: "first_discussion_section"
          title: "First Discussion Section"
          from: "cross_section_reply_product"

      - section:
          name: "second_discussion_section"
          title: "Second Discussion Section"
          from: "cross_section_reply_product"

      - user:
          name: "cross_section_student"
          type: "student"
          email: "cross_section_student@test.edu"

      - enroll:
          user: "cross_section_student"
          section: "first_discussion_section"

      - enroll:
          user: "cross_section_student"
          section: "second_discussion_section"

      - discussion_post:
          name: "first_section_post"
          student: "cross_section_student"
          section: "first_discussion_section"
          body: "This post belongs to the first section."

      - discussion_post:
          name: "cross_section_reply"
          student: "cross_section_student"
          section: "second_discussion_section"
          reply_to: "first_section_post"
          body: "This reply should be rejected."
      """

      result = yaml |> DirectiveParser.parse_yaml!() |> Engine.execute()

      assert [{_, error}] = result.errors
      assert error =~ "Parent discussion post does not belong to section"
    end
  end

  describe "discussion_moderation" do
    test "rejects moderation by a user without an instructor role in the section" do
      yaml = """
      - project:
          name: "moderation_auth_course"
          title: "Moderation Auth Course"
          root:
            children:
              - page: "Welcome"

      - product:
          name: "moderation_auth_product"
          title: "Moderation Auth Product"
          from: "moderation_auth_course"

      - discussion_config:
          section: "moderation_auth_product"
          enabled: true
          auto_accept: false

      - section:
          name: "moderation_auth_section"
          title: "Moderation Auth Section"
          from: "moderation_auth_product"

      - user:
          name: "post_author"
          type: "student"
          email: "post_author@test.edu"

      - user:
          name: "student_moderator"
          type: "student"
          email: "student_moderator@test.edu"

      - enroll:
          user: "post_author"
          section: "moderation_auth_section"

      - enroll:
          user: "student_moderator"
          section: "moderation_auth_section"

      - discussion_post:
          name: "pending_post"
          student: "post_author"
          section: "moderation_auth_section"
          body: "This post needs a real moderator."

      - discussion_moderation:
          post: "pending_post"
          instructor: "student_moderator"
          action: "approve"
      """

      result = yaml |> DirectiveParser.parse_yaml!() |> Engine.execute()

      assert [{_, error}] = result.errors
      assert error =~ "not authorized to moderate"
    end
  end
end
