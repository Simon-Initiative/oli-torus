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

    test "rejects posts when discussions are disabled" do
      yaml = """
      - project:
          name: "disabled_discussion_course"
          title: "Disabled Discussion Course"
          root:
            children:
              - page: "Welcome"

      - product:
          name: "disabled_discussion_product"
          title: "Disabled Discussion Product"
          from: "disabled_discussion_course"

      - discussion_config:
          section: "disabled_discussion_product"
          enabled: false

      - section:
          name: "disabled_discussion_section"
          title: "Disabled Discussion Section"
          from: "disabled_discussion_product"

      - user:
          name: "disabled_discussion_student"
          type: "student"
          email: "disabled_discussion_student@test.edu"

      - enroll:
          user: "disabled_discussion_student"
          section: "disabled_discussion_section"

      - discussion_post:
          name: "disabled_discussion_post"
          student: "disabled_discussion_student"
          section: "disabled_discussion_section"
          body: "This post should be rejected."
      """

      result = yaml |> DirectiveParser.parse_yaml!() |> Engine.execute()

      assert [{_, error}] = result.errors
      assert error =~ "Discussions are not enabled"
    end

    test "defaults posts to approved when auto accept is not configured" do
      yaml = """
      - project:
          name: "auto_accept_default_course"
          title: "Auto Accept Default Course"
          root:
            children:
              - page: "Welcome"

      - product:
          name: "auto_accept_default_product"
          title: "Auto Accept Default Product"
          from: "auto_accept_default_course"

      - discussion_config:
          section: "auto_accept_default_product"
          enabled: true

      - section:
          name: "auto_accept_default_section"
          title: "Auto Accept Default Section"
          from: "auto_accept_default_product"

      - user:
          name: "auto_accept_default_student"
          type: "student"
          email: "auto_accept_default_student@test.edu"

      - enroll:
          user: "auto_accept_default_student"
          section: "auto_accept_default_section"

      - discussion_post:
          name: "auto_accept_default_post"
          student: "auto_accept_default_student"
          section: "auto_accept_default_section"
          body: "This post should be auto-approved."

      - assert:
          discussion:
            section: "auto_accept_default_section"
            post: "auto_accept_default_post"
            student: "auto_accept_default_student"
            status: "approved"
            visible: true
      """

      result = yaml |> DirectiveParser.parse_yaml!() |> Engine.execute()

      assert result.errors == []
      assert Enum.all?(result.verifications, & &1.passed)
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

  describe "discussion_delete" do
    test "rejects deletion by a user who is neither the post owner nor section instructor" do
      yaml = """
      - project:
          name: "delete_auth_course"
          title: "Delete Auth Course"
          root:
            children:
              - page: "Welcome"

      - product:
          name: "delete_auth_product"
          title: "Delete Auth Product"
          from: "delete_auth_course"

      - discussion_config:
          section: "delete_auth_product"
          enabled: true

      - section:
          name: "delete_auth_section"
          title: "Delete Auth Section"
          from: "delete_auth_product"

      - user:
          name: "delete_post_owner"
          type: "student"
          email: "delete_post_owner@test.edu"

      - user:
          name: "delete_other_student"
          type: "student"
          email: "delete_other_student@test.edu"

      - enroll:
          user: "delete_post_owner"
          section: "delete_auth_section"

      - enroll:
          user: "delete_other_student"
          section: "delete_auth_section"

      - discussion_post:
          name: "owned_post"
          student: "delete_post_owner"
          section: "delete_auth_section"
          body: "Only the owner or instructor can delete this."

      - discussion_delete:
          post: "owned_post"
          actor: "delete_other_student"
      """

      result = yaml |> DirectiveParser.parse_yaml!() |> Engine.execute()

      assert [{_, error}] = result.errors
      assert error =~ "not authorized to delete"
    end
  end
end
