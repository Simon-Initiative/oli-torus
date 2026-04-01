defmodule OliWeb.Api.TriggerPointControllerTest do
  use OliWeb.ConnCase

  alias Oli.Resources.Revision
  alias Oli.Seeder
  alias Phoenix.PubSub
  alias OliWeb.Router.Helpers, as: Routes

  describe "standard cases" do
    setup [:setup_session]

    test "handle when user not enrolled", %{
      conn: conn,
      map: map
    } do
      trigger = %{
        "trigger_type" => "content_block",
        "resource_id" => "resource_id",
        "data" => %{},
        "prompt" => "prompt"
      }

      conn =
        post(
          conn,
          Routes.trigger_point_path(conn, :invoke, map.section.slug),
          %{"trigger" => trigger}
        )

      assert %{
               "type" => "failure",
               "reason" => "User does not have permission to invoke trigger point"
             } = json_response(conn, 200)
    end

    test "handle when user enrolled, but triggers disabled", %{
      conn: conn,
      map: map
    } do
      Oli.Delivery.Sections.enroll(
        map.user1.id,
        map.section.id,
        [Lti_1p3.Roles.ContextRoles.get_role(:context_learner)],
        :enrolled
      )

      trigger = %{
        "trigger_type" => "content_block",
        "resource_id" => "resource_id",
        "data" => %{},
        "prompt" => "prompt"
      }

      conn =
        post(
          conn,
          Routes.trigger_point_path(conn, :invoke, map.section.slug),
          %{"trigger" => trigger}
        )

      assert %{
               "type" => "failure",
               "reason" => "User does not have permission to invoke trigger point"
             } = json_response(conn, 200)
    end

    test "handle when user enrolled, and triggers and agent enabled", %{
      conn: conn,
      map: map
    } do
      Oli.Delivery.Sections.enroll(
        map.user1.id,
        map.section.id,
        [Lti_1p3.Roles.ContextRoles.get_role(:context_learner)],
        :enrolled
      )

      Oli.Delivery.Sections.update_section!(map.section, %{
        triggers_enabled: true,
        assistant_enabled: true
      })

      trigger = %{
        "trigger_type" => "content_block",
        "resource_id" => "resource_id",
        "data" => %{},
        "prompt" => "prompt"
      }

      conn =
        post(
          conn,
          Routes.trigger_point_path(conn, :invoke, map.section.slug),
          %{"trigger" => trigger}
        )

      assert %{"type" => "submitted"} = json_response(conn, 200)
    end

    test "returns invalid trigger when trigger_type is missing", %{
      conn: conn,
      map: map
    } do
      Oli.Delivery.Sections.enroll(
        map.user1.id,
        map.section.id,
        [Lti_1p3.Roles.ContextRoles.get_role(:context_learner)],
        :enrolled
      )

      Oli.Delivery.Sections.update_section!(map.section, %{
        triggers_enabled: true,
        assistant_enabled: true
      })

      trigger = %{
        "resource_id" => "resource_id",
        "data" => %{}
      }

      conn =
        post(
          conn,
          Routes.trigger_point_path(conn, :invoke, map.section.slug),
          %{"trigger" => trigger}
        )

      assert %{"type" => "failure", "reason" => "Invalid trigger point"} =
               json_response(conn, 200)
    end

    test "returns invalid trigger when trigger_type is not a string", %{
      conn: conn,
      map: map
    } do
      Oli.Delivery.Sections.enroll(
        map.user1.id,
        map.section.id,
        [Lti_1p3.Roles.ContextRoles.get_role(:context_learner)],
        :enrolled
      )

      Oli.Delivery.Sections.update_section!(map.section, %{
        triggers_enabled: true,
        assistant_enabled: true
      })

      trigger = %{
        "trigger_type" => 123,
        "resource_id" => "resource_id",
        "data" => %{}
      }

      conn =
        post(
          conn,
          Routes.trigger_point_path(conn, :invoke, map.section.slug),
          %{"trigger" => trigger}
        )

      assert %{"type" => "failure", "reason" => "Invalid trigger point"} =
               json_response(conn, 200)
    end

    test "resolves adaptive prompts from authored content instead of the client payload", %{
      conn: conn,
      map: map
    } do
      Oli.Delivery.Sections.enroll(
        map.user1.id,
        map.section.id,
        [Lti_1p3.Roles.ContextRoles.get_role(:context_learner)],
        :enrolled
      )

      Oli.Delivery.Sections.update_section!(map.section, %{
        triggers_enabled: true,
        assistant_enabled: true
      })

      adaptive_revision =
        map.adaptive_revision
        |> Revision.changeset(%{
          content: %{
            "partsLayout" => [
              %{
                "id" => "trigger-1",
                "type" => "janus-ai-trigger",
                "custom" => %{
                  "launchMode" => "click",
                  "prompt" => "Authored prompt"
                }
              }
            ]
          }
        })
        |> Oli.Repo.update!()

      # The broadcast topic uses the containing page's resource_id, not the activity's
      topic = "trigger:#{map.user1.id}:#{map.section.id}:#{map.adaptive_page_resource.id}"
      :ok = PubSub.subscribe(Oli.PubSub, topic)

      trigger = %{
        "trigger_type" => "adaptive_component",
        "resource_id" => adaptive_revision.resource_id,
        "data" => %{
          "component_id" => "trigger-1",
          "component_type" => "janus-image"
        },
        "prompt" => "Tampered prompt"
      }

      conn =
        post(
          conn,
          Routes.trigger_point_path(conn, :invoke, map.section.slug),
          %{"trigger" => trigger}
        )

      assert %{"type" => "submitted"} = json_response(conn, 200)

      assert_receive {:trigger,
                      %Oli.Conversation.Trigger{
                        trigger_type: :adaptive_component,
                        prompt: "Authored prompt",
                        data: %{
                          "component_id" => "trigger-1",
                          "component_type" => "janus-ai-trigger"
                        }
                      }}
    end

    test "resolves trap state prompt from server-side authoring rules, not client payload", %{
      conn: conn,
      map: map
    } do
      Oli.Delivery.Sections.enroll(
        map.user1.id,
        map.section.id,
        [Lti_1p3.Roles.ContextRoles.get_role(:context_learner)],
        :enrolled
      )

      Oli.Delivery.Sections.update_section!(map.section, %{
        triggers_enabled: true,
        assistant_enabled: true
      })

      # Set up authoring rules with an activation point action
      existing_content = map.adaptive_revision.content || %{}

      map.adaptive_revision
      |> Revision.changeset(%{
        content:
          Map.put(existing_content, "authoring", %{
            "rules" => [
              %{
                "id" => "r:trap-rule-1.incorrect",
                "name" => "incorrect",
                "correct" => false,
                "event" => %{
                  "type" => "r:trap-rule-1.incorrect",
                  "params" => %{
                    "actions" => [
                      %{
                        "type" => "activationPoint",
                        "params" => %{
                          "prompt" => "  Help the learner recover from this trap state.  "
                        }
                      }
                    ]
                  }
                },
                "conditions" => %{"all" => []}
              }
            ]
          })
      })
      |> Oli.Repo.update!()

      expected_page_resource_id = map.adaptive_page_resource.id
      page_topic = "trigger:#{map.user1.id}:#{map.section.id}:#{expected_page_resource_id}"

      activity_topic =
        "trigger:#{map.user1.id}:#{map.section.id}:#{map.adaptive_revision.resource_id}"

      :ok = PubSub.subscribe(Oli.PubSub, page_topic)
      :ok = PubSub.subscribe(Oli.PubSub, activity_topic)

      trigger = %{
        "trigger_type" => "trap_state",
        "resource_id" => map.adaptive_revision.resource_id,
        "data" => %{
          "component_id" => "trap-rule-1",
          "component_type" => "trap-state-rule",
          "rule_id" => "r:trap-rule-1.incorrect"
        },
        # Client-sent prompt should be ignored
        "prompt" => "Tampered prompt from malicious client"
      }

      conn =
        post(
          conn,
          Routes.trigger_point_path(conn, :invoke, map.section.slug),
          %{"trigger" => trigger}
        )

      assert %{"type" => "submitted"} = json_response(conn, 200)

      # The prompt should come from the server-side authoring rules, not the client payload
      assert_receive {:trigger,
                      %Oli.Conversation.Trigger{
                        trigger_type: :trap_state,
                        prompt: "Help the learner recover from this trap state.",
                        data: %{
                          "component_id" => "trap-rule-1",
                          "component_type" => "trap-state-rule",
                          "rule_id" => "r:trap-rule-1.incorrect"
                        }
                      }},
                     1_000
    end

    test "rejects trap state triggers without a matching rule_id", %{
      conn: conn,
      map: map
    } do
      Oli.Delivery.Sections.enroll(
        map.user1.id,
        map.section.id,
        [Lti_1p3.Roles.ContextRoles.get_role(:context_learner)],
        :enrolled
      )

      Oli.Delivery.Sections.update_section!(map.section, %{
        triggers_enabled: true,
        assistant_enabled: true
      })

      trigger = %{
        "trigger_type" => "trap_state",
        "resource_id" => map.adaptive_revision.resource_id,
        "data" => %{
          "component_id" => "trap-rule-1",
          "component_type" => "trap-state-rule"
        }
      }

      conn =
        post(
          conn,
          Routes.trigger_point_path(conn, :invoke, map.section.slug),
          %{"trigger" => trigger}
        )

      assert %{"type" => "failure", "reason" => "Invalid trigger point"} =
               json_response(conn, 200)
    end

    test "deduplicates repeated adaptive trigger submissions within the cooldown window", %{
      conn: conn,
      map: map
    } do
      Cachex.clear(:adaptive_trigger_invocation_cache)

      Oli.Delivery.Sections.enroll(
        map.user1.id,
        map.section.id,
        [Lti_1p3.Roles.ContextRoles.get_role(:context_learner)],
        :enrolled
      )

      Oli.Delivery.Sections.update_section!(map.section, %{
        triggers_enabled: true,
        assistant_enabled: true
      })

      adaptive_revision =
        map.adaptive_revision
        |> Revision.changeset(%{
          content: %{
            "partsLayout" => [
              %{
                "id" => "trigger-1",
                "type" => "janus-ai-trigger",
                "custom" => %{
                  "launchMode" => "auto",
                  "prompt" => "Authored prompt"
                }
              }
            ]
          }
        })
        |> Oli.Repo.update!()

      # The broadcast topic uses the containing page's resource_id, not the activity's
      topic = "trigger:#{map.user1.id}:#{map.section.id}:#{map.adaptive_page_resource.id}"
      :ok = PubSub.subscribe(Oli.PubSub, topic)

      trigger = %{
        "trigger_type" => "adaptive_page",
        "resource_id" => adaptive_revision.resource_id,
        "data" => %{
          "component_id" => "trigger-1",
          "component_type" => "janus-ai-trigger"
        }
      }

      conn =
        post(
          conn,
          Routes.trigger_point_path(conn, :invoke, map.section.slug),
          %{"trigger" => trigger}
        )

      assert %{"type" => "submitted"} = json_response(conn, 200)
      assert_receive {:trigger, %Oli.Conversation.Trigger{}}

      conn =
        post(
          recycle(conn),
          Routes.trigger_point_path(conn, :invoke, map.section.slug),
          %{"trigger" => trigger}
        )

      assert %{"type" => "submitted"} = json_response(conn, 200)
      refute_receive {:trigger, %Oli.Conversation.Trigger{}}, 100
    end

    test "returns invalid trigger when adaptive partsLayout content is malformed", %{
      conn: conn,
      map: map
    } do
      Oli.Delivery.Sections.enroll(
        map.user1.id,
        map.section.id,
        [Lti_1p3.Roles.ContextRoles.get_role(:context_learner)],
        :enrolled
      )

      Oli.Delivery.Sections.update_section!(map.section, %{
        triggers_enabled: true,
        assistant_enabled: true
      })

      adaptive_revision =
        map.adaptive_revision
        |> Revision.changeset(%{
          content: %{
            "partsLayout" => "bad"
          }
        })
        |> Oli.Repo.update!()

      trigger = %{
        "trigger_type" => "adaptive_component",
        "resource_id" => adaptive_revision.resource_id,
        "data" => %{
          "component_id" => "trigger-1",
          "component_type" => "janus-ai-trigger"
        }
      }

      conn =
        post(
          conn,
          Routes.trigger_point_path(conn, :invoke, map.section.slug),
          %{"trigger" => trigger}
        )

      assert %{"type" => "failure", "reason" => "Invalid trigger point"} =
               json_response(conn, 200)
    end
  end

  defp setup_session(%{conn: conn}) do
    map =
      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_adaptive_page()

    Seeder.ensure_published(map.publication.id)

    map =
      Seeder.create_section_resources(map)

    Cachex.clear(:adaptive_trigger_invocation_cache)

    user = map.user1

    Oli.Lti.TestHelpers.all_default_claims()
    |> put_in(["https://purl.imsglobal.org/spec/lti/claim/context", "id"], map.section.slug)
    |> cache_lti_params(user.id)

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> log_in_user(user)

    {:ok, conn: conn, map: map}
  end
end
