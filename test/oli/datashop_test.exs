defmodule Oli.DatashopTest do
  use Oli.DataCase

  alias Oli.Analytics.Datashop
  alias Oli.Activities.Model.Part
  alias Oli.Publishing

  describe "datashop" do

    setup do
      mc_content = %{
        "authoring" => %{
          "parts" => [
            %{
              "hints" => [
                %{
                  "content" => [
                    %{
                      "children" => [%{"text" => "Hint 1"}],
                      "id" => "3298290731",
                      "type" => "p"
                    }
                  ],
                  "id" => "151590658"
                },
                %{
                  "content" => [
                    %{
                      "children" => [%{"text" => "Hint 2"}],
                      "id" => "3243833733",
                      "type" => "p"
                    }
                  ],
                  "id" => "3059890119"
                },
                %{
                  "content" => [
                    %{
                      "children" => [%{"text" => "Hint 3"}],
                      "id" => "1417062001",
                      "type" => "p"
                    }
                  ],
                  "id" => "77393076"
                }
              ],
              "id" => "1",
              "responses" => [
                %{
                  "feedback" => %{
                    "content" => [
                      %{
                        "children" => [%{"text" => "Correct feedback"}],
                        "id" => "2977707959",
                        "type" => "p"
                      }
                    ],
                    "id" => "2494310518"
                  },
                  "id" => "186429955",
                  "rule" => "input like {4037228206}",
                  "score" => 1
                },
                %{
                  "feedback" => %{
                    "content" => [
                      %{
                        "children" => [%{"text" => "Incorrect feedback"}],
                        "id" => "3921469287",
                        "type" => "p"
                      }
                    ],
                    "id" => "886882922"
                  },
                  "id" => "4213402281",
                  "rule" => "input like {2398016423}",
                  "score" => 0
                }
              ],
              "scoringStrategy" => "average"
            }
          ],
          "transformations" => [
            %{
              "id" => "3743094838",
              "operation" => "shuffle",
              "path" => "choices"
            }
          ]
        },
        "choices" => [
          %{
            "content" => [
              %{
                "children" => [%{"text" => "Choice A (correct)"}],
                "id" => "2686600360",
                "type" => "p"
              }
            ],
            "id" => "4037228206"
          },
          %{
            "content" => [
              %{
                "children" => [%{"text" => "Choice B (incorrect)"}],
                "id" => "4134104312",
                "type" => "p"
              }
            ],
            "id" => "2398016423"
          }
        ],
        "stem" => %{
          "content" => [
            %{
              "children" => [%{"text" => "MC Question stem"}],
              "id" => "367432826",
              "type" => "p"
            }
          ],
          "id" => "110583950"
        }
      }

      mc_transformed_model = %{
        "authoring" => %{
          "parts" => [
            %{
              "hints" => [
                %{
                  "content" => [
                    %{
                      "children" => [%{"text" => "Hint 1"}],
                      "id" => "3298290731",
                      "type" => "p"
                    }
                  ],
                  "id" => "151590658"
                },
                %{
                  "content" => [
                    %{
                      "children" => [%{"text" => "Hint 2"}],
                      "id" => "3243833733",
                      "type" => "p"
                    }
                  ],
                  "id" => "3059890119"
                },
                %{
                  "content" => [
                    %{
                      "children" => [%{"text" => "Hint 3"}],
                      "id" => "1417062001",
                      "type" => "p"
                    }
                  ],
                  "id" => "77393076"
                }
              ],
              "id" => "1",
              "responses" => [
                %{
                  "feedback" => %{
                    "content" => [
                      %{
                        "children" => [%{"text" => "Correct feedback"}],
                        "id" => "2977707959",
                        "type" => "p"
                      }
                    ],
                    "id" => "2494310518"
                  },
                  "id" => "186429955",
                  "rule" => "input like {4037228206}",
                  "score" => 1
                },
                %{
                  "feedback" => %{
                    "content" => [
                      %{
                        "children" => [%{"text" => "Incorrect feedback"}],
                        "id" => "3921469287",
                        "type" => "p"
                      }
                    ],
                    "id" => "886882922"
                  },
                  "id" => "4213402281",
                  "rule" => "input like {2398016423}",
                  "score" => 0
                }
              ],
              "scoringStrategy" => "average"
            }
          ],
          "transformations" => [
            %{
              "id" => "3743094838",
              "operation" => "shuffle",
              "path" => "choices"
            }
          ]
        },
        "choices" => [
          %{
            "content" => [
              %{
                "children" => [%{"text" => "Choice B (incorrect)"}],
                "id" => "4134104312",
                "type" => "p"
              }
            ],
            "id" => "2398016423"
          },
          %{
            "content" => [
              %{
                "children" => [%{"text" => "Choice A (correct)"}],
                "id" => "2686600360",
                "type" => "p"
              }
            ],
            "id" => "4037228206"
          }
        ],
        "stem" => %{
          "content" => [
            %{
              "children" => [%{"text" => "Question stem"}],
              "id" => "367432826",
              "type" => "p"
            }
          ],
          "id" => "110583950"
        }
      }

      sa_content = %{
        "authoring" => %{
          "parts" => [
            %{
              "hints" => [
                %{
                  "content" => [
                    %{
                      "children" => [%{"text" => "Hint 1"}],
                      "id" => "3766589217",
                      "type" => "p"
                    }
                  ],
                  "id" => "1524891687"
                },
                %{
                  "content" => [
                    %{
                      "children" => [%{"text" => "Hint 2"}],
                      "id" => "2516709133",
                      "type" => "p"
                    }
                  ],
                  "id" => "1507444816"
                },
                %{
                  "content" => [
                    %{
                      "children" => [%{"text" => "Hint 3"}],
                      "id" => "3324481138",
                      "type" => "p"
                    }
                  ],
                  "id" => "1137320916"
                }
              ],
              "id" => "1",
              "responses" => [
                %{
                  "feedback" => %{
                    "content" => [
                      %{
                        "children" => [%{"text" => "Feedback (Correct)"}],
                        "id" => "3061950753",
                        "type" => "p"
                      }
                    ],
                    "id" => "269147921"
                  },
                  "id" => "969779512",
                  "rule" => "input like {answer}",
                  "score" => 1
                },
                %{
                  "feedback" => %{
                    "content" => [
                      %{
                        "children" => [%{"text" => "Feedback (Incorrect)"}],
                        "id" => "568333261",
                        "type" => "p"
                      }
                    ],
                    "id" => "3844438371"
                  },
                  "id" => "2059905749",
                  "rule" => "input like {.*}",
                  "score" => 0
                }
              ],
              "scoringStrategy" => "average"
            }
          ],
          "transformations" => []
        },
        "inputType" => "text",
        "stem" => %{
          "content" => [
            %{
              "children" => [%{"text" => "Short answer stem"}],
              "id" => "1064580259",
              "type" => "p"
            }
          ],
          "id" => "4196127524"
        }
      }

      sa_transformed_model = %{
        "authoring" => %{
          "parts" => [
            %{
              "hints" => [
                %{
                  "content" => [
                    %{
                      "children" => [%{"text" => "Hint 1"}],
                      "id" => "3766589217",
                      "type" => "p"
                    }
                  ],
                  "id" => "1524891687"
                },
                %{
                  "content" => [
                    %{
                      "children" => [%{"text" => "Hint 2"}],
                      "id" => "2516709133",
                      "type" => "p"
                    }
                  ],
                  "id" => "1507444816"
                },
                %{
                  "content" => [
                    %{
                      "children" => [%{"text" => "Hint 3"}],
                      "id" => "3324481138",
                      "type" => "p"
                    }
                  ],
                  "id" => "1137320916"
                }
              ],
              "id" => "1",
              "responses" => [
                %{
                  "feedback" => %{
                    "content" => [
                      %{
                        "children" => [%{"text" => "Feedback (Correct)"}],
                        "id" => "3061950753",
                        "type" => "p"
                      }
                    ],
                    "id" => "269147921"
                  },
                  "id" => "969779512",
                  "rule" => "input like {answer}",
                  "score" => 1
                },
                %{
                  "feedback" => %{
                    "content" => [
                      %{
                        "children" => [%{"text" => "Feedback (Incorrect)"}],
                        "id" => "568333261",
                        "type" => "p"
                      }
                    ],
                    "id" => "3844438371"
                  },
                  "id" => "2059905749",
                  "rule" => "input like {.*}",
                  "score" => 0
                }
              ],
              "scoringStrategy" => "average"
            }
          ],
          "transformations" => []
        },
        "inputType" => "text",
        "stem" => %{
          "content" => [
            %{
              "children" => [%{"text" => "Short answer stem"}],
              "id" => "1064580259",
              "type" => "p"
            }
          ],
          "id" => "4196127524"
        }
      }

      map = Seeder.base_project_with_resource2()
      |> Seeder.add_objective("objective one", :o1)
      |> Seeder.add_objective("objective two", :o2)
      |> Seeder.add_objective("objective three", :o3)
      |> Seeder.create_section
      |> Seeder.add_users_to_section(:section, [:user1, :user2, :user3])

      map = map
      |> Seeder.add_activity(%{title: "one", content: mc_content, objectives: %{ "1" => [map.o1.resource.id] }}, :mc1)
      |> Seeder.add_activity(%{title: "two", content: sa_content, objectives: %{ "1" => [map.o2.resource.id, map.o3.resource.id] }, activity_type_id: 2}, :sa1)

      Publishing.publish_project(map.project)

      page1_attrs = %{
        title: "page1",
        content: %{
          "model" => [
            %{"type" => "activity-reference", "activity_id" => Map.get(map, :mc1).resource.id}
          ]
        },
        objectives: %{"attached" => [Map.get(map, :o1).resource.id]}
      }

      page2_attrs = %{
        title: "page2",
        content: %{
          "model" => [
            %{"type" => "activity-reference", "activity_id" => Map.get(map, :sa1).resource.id}
          ]
        },
        objectives: %{"attached" => [
          Map.get(map, :o2).resource.id,
          Map.get(map, :o3).resource.id
        ]}
      }

      map = map
      |> Seeder.add_page(page1_attrs, :p1)
      |> Seeder.add_page(page2_attrs, :p2)
      |> Oli.Seeder.add_resource_accesses(:section, %{
        p1: %{
          out_of: 20,
          scores: %{
            user1: 12,
            user2: 20,
            user3: 19
          }
        },
        p2: %{
          out_of: 5,
          scores: %{
            user1: 0,
            user2: 3,
            user3: 5
          }
        }
        })
      # Multiple choice activity
      # User 1. Two attempts (Incorrect + hint, correct + hint)
      |> Seeder.create_resource_attempt(%{attempt_number: 1}, :user1, :page1, :revision1, :p1_user1_attempt1)
      |> Seeder.create_activity_attempt(%{attempt_number: 1, transformed_model: mc_transformed_model}, :mc1, :p1_user1_attempt1, :mc_user1_attempt1)
      |> Seeder.create_part_attempt(%{
        attempt_number: 1,
        score: 0,
        out_of: 1,
        response: %{"input" => "2398016423"},
        feedback: %{
          "content" => [
            %{
              "children" => [%{"text" => "Incorrect feedback"}],
              "id" => "3921469287",
              "type" => "p"
            }
          ],
          "id" => "886882922"
        },
        hints: ["151590658"]
      }, %Part{id: "1", responses: [], hints: []}, :mc_user1_attempt1, :mc_user1_part_attempt1)
      |> Seeder.create_activity_attempt(%{attempt_number: 2, transformed_model: mc_transformed_model}, :mc1, :p1_user1_attempt1, :mc_user1_attempt2)
      |> Seeder.create_part_attempt(%{
        attempt_number: 2,
        score: 1,
        out_of: 1,
        response: %{"input" => "4037228206"},
        feedback: %{
          "content" => [
            %{
              "children" => [%{"text" => "Correct feedback"}],
              "id" => "3921469287",
              "type" => "p"
            }
          ],
          "id" => "2494310518"
        },
        hints: ["3059890119"]
      }, %Part{id: "1", responses: [], hints: []}, :mc_user1_attempt2, :mc_user1_part_attempt2)
      # User 2. One attempt (correct)
      |> Seeder.create_resource_attempt(%{attempt_number: 1}, :user2, :page1, :revision1, :p1_user2_attempt1)
      |> Seeder.create_activity_attempt(%{attempt_number: 1, transformed_model: mc_transformed_model}, :mc1, :p1_user2_attempt1, :mc_user2_attempt1)
      |> Seeder.create_part_attempt(%{
        attempt_number: 1,
        score: 1,
        out_of: 1,
        response: %{"input" => "4037228206"},
        feedback: %{
          "content" => [
            %{
              "children" => [%{"text" => "Correct feedback"}],
              "id" => "3921469287",
              "type" => "p"
            }
          ],
          "id" => "2494310518"
        },
        hints: ["3059890119"]
      }, %Part{id: "1", responses: [], hints: []}, :mc_user2_attempt1, :mc_user2_part_attempt1)

      # Short answer activity
      # User 1. Two attempts (Incorrect + hint, correct + hint)
      |> Seeder.create_resource_attempt(%{attempt_number: 1}, :user1, :page2, :revision2, :p2_user1_attempt1)
      |> Seeder.create_activity_attempt(%{attempt_number: 1, transformed_model: sa_transformed_model}, :sa1, :p2_user1_attempt1, :sa_user1_attempt1)
      |> Seeder.create_part_attempt(%{
        attempt_number: 1,
        score: 0,
        out_of: 1,
        response: %{"input" => "Student 1's input"},
        feedback: %{
          "content" => [
            %{
              "children" => [%{"text" => "Feedback (Incorrect)"}],
              "id" => "568333261",
              "type" => "p"
            }
          ],
          "id" => "3844438371"
        },
        hints: ["1524891687"]
      }, %Part{id: "1", responses: [], hints: []}, :sa_user1_attempt1, :sa_user1_part_attempt1)
      |> Seeder.create_activity_attempt(%{attempt_number: 2, transformed_model: sa_transformed_model}, :sa1, :p2_user1_attempt1, :sa_user1_attempt2)
      |> Seeder.create_part_attempt(%{
        attempt_number: 2,
        score: 1,
        out_of: 1,
        response: %{"input" => "answer"},
        feedback: %{
          "content" => [
            %{
              "children" => [%{"text" => "Feedback (Correct)"}],
              "id" => "568333261",
              "type" => "p"
            }
          ],
          "id" => "269147921"
        },
        hints: ["1507444816"]
      }, %Part{id: "1", responses: [], hints: []}, :sa_user1_attempt2, :sa_user1_part_attempt2)
      # User2. One attempt (correct + hint)
      |> Seeder.create_resource_attempt(%{attempt_number: 1}, :user2, :page2, :revision2, :p2_user2_attempt1)
      |> Seeder.create_activity_attempt(%{attempt_number: 1, transformed_model: sa_transformed_model}, :sa1, :p2_user2_attempt1, :sa_user2_attempt1)
      |> Seeder.create_part_attempt(%{
        attempt_number: 1,
        score: 1,
        out_of: 1,
        response: %{"input" => "Student 1's input"},
        feedback: %{
          "content" => [
            %{
              "children" => [%{"text" => "Feedback (Correct)"}],
              "id" => "568333261",
              "type" => "p"
            }
          ],
          "id" => "269147921"
        },
        hints: ["1137320916"]
      }, %Part{id: "1", responses: [], hints: []}, :sa_user2_attempt1, :sa_user2_part_attempt1)

      map
    end

    test "export should create a file", %{project: project} do
      Datashop.export(project.id)
      true
    end

    @tag :skip
    test "tutor message should be well formed for hints"
    @tag :skip
    test "tutor message should be well formed for attempts"
    @tag :skip
    test "tool message should be well formed for hints"
    @tag :skip
    test "tool message should be well formed for attempts"
    @tag :skip
    test "context message should be well formed"
    @tag :skip
    test "user1 context message should have right info"
    @tag :skip
    test "user1 hint tool message should match context message"
    @tag :skip
    test "user1 hint tutor message should match context message"
    @tag :skip
    test "user1 hint pair should have matching transaction ids"
    @tag :skip
    test "user1 attempt tool message should have right info"
    @tag :skip
    test "user1 attempt tutor message should have right info"
  end

end
