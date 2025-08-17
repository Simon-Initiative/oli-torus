defmodule Oli.GenAI.Tools.ExampleActivityTool do
  @moduledoc """
  MCP tool for retrieving example activities by type.

  This tool provides hardcoded example activities for different activity types
  to help external AI agents understand the structure and create new activities.
  """

  use Hermes.Server.Component, type: :tool

  alias Hermes.Server.Response
  alias Oli.GenAI.Agent.MCPToolRegistry

  # Get field descriptions from MCPToolRegistry at compile time
  @tool_schema MCPToolRegistry.get_tool_schema("example_activity")
  @activity_type_desc get_in(@tool_schema, ["properties", "activity_type", "description"])

  schema do
    field :activity_type, :string, required: true, description: @activity_type_desc
  end

  @impl true
  def execute(%{activity_type: activity_type}, frame) do
    case get_example_activity(activity_type) do
      {:ok, example} ->
        json_content = Jason.encode!(example, pretty: true)
        {:reply, Response.text(Response.tool(), json_content), frame}

      {:error, reason} ->
        {:reply, Response.error(Response.tool(), reason), frame}
    end
  end

  # Returns example activity for the requested type
  defp get_example_activity(activity_type) do
    examples = %{
      "oli_multiple_choice" => multiple_choice_example(),
      "oli_short_answer" => short_answer_example(),
      "oli_check_all_that_apply" => check_all_that_apply_example(),
      "oli_likert" => likert_example(),
      "oli_multi_input" => multi_input_example(),
      "oli_ordering" => ordering_example()
    }

    case Map.get(examples, activity_type) do
      nil ->
        {:error,
         "Unknown activity type: #{activity_type}. Supported types: #{Map.keys(examples) |> Enum.join(", ")}"}

      example ->
        {:ok, example}
    end
  end

  defp multiple_choice_example do
    %{
      "stem" => %{
        "id" => "stem_1",
        "content" => [
          %{
            "type" => "p",
            "children" => [%{"text" => "What is the capital of France?"}]
          }
        ]
      },
      "choices" => [
        %{
          "id" => "choice_1",
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "London"}]
            }
          ],
          "editor" => "slate",
          "textDirection" => "ltr"
        },
        %{
          "id" => "choice_2",
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "Paris", "bold" => true}]
            }
          ],
          "editor" => "slate",
          "textDirection" => "ltr"
        },
        %{
          "id" => "choice_3",
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "Berlin", "italic" => true}]
            }
          ],
          "editor" => "slate",
          "textDirection" => "ltr"
        },
        %{
          "id" => "choice_4",
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "Madrid"}]
            }
          ],
          "editor" => "slate",
          "textDirection" => "ltr"
        }
      ],
      "authoring" => %{
        "version" => 2,
        "targeted" => [],
        "parts" => [
          %{
            "id" => "part_1",
            "gradingApproach" => "automatic",
            "scoringStrategy" => "average",
            "hints" => [
              %{
                "id" => "hint_1",
                "content" => [
                  %{
                    "type" => "p",
                    "children" => [%{"text" => "Think about which city is in France."}]
                  }
                ],
                "editor" => "slate",
                "textDirection" => "ltr"
              }
            ],
            "responses" => [
              %{
                "id" => "response_correct",
                "rule" => "input like {choice_2}",
                "score" => 1,
                "correct" => true,
                "feedback" => %{
                  "id" => "feedback_correct",
                  "content" => [
                    %{
                      "type" => "p",
                      "children" => [%{"text" => "Correct! Paris is the capital of France."}]
                    }
                  ],
                  "editor" => "slate",
                  "textDirection" => "ltr"
                }
              },
              %{
                "id" => "response_incorrect",
                "rule" => "input like {.*}",
                "score" => 0,
                "correct" => false,
                "feedback" => %{
                  "id" => "feedback_incorrect",
                  "content" => [
                    %{
                      "type" => "p",
                      "children" => [
                        %{"text" => "That's not correct. The capital of France is Paris."}
                      ]
                    }
                  ],
                  "editor" => "slate",
                  "textDirection" => "ltr"
                }
              }
            ]
          }
        ],
        "transformations" => [
          %{
            "id" => "shuffle_1",
            "path" => "choices",
            "operation" => "shuffle",
            "firstAttemptOnly" => true
          }
        ],
        "previewText" => "What is the capital of France?"
      }
    }
  end

  defp short_answer_example do
    %{
      "stem" => %{
        "id" => "stem_1",
        "content" => [
          %{
            "type" => "p",
            "children" => [
              %{"text" => "What year did Christopher Columbus first arrive in the Americas?"}
            ]
          }
        ],
        "editor" => "slate",
        "textDirection" => "ltr"
      },
      "inputType" => "text",
      "submitAndCompare" => false,
      "authoring" => %{
        "parts" => [
          %{
            "id" => "part_1",
            "gradingApproach" => "automatic",
            "scoringStrategy" => "average",
            "hints" => [
              %{
                "id" => "hint_1",
                "content" => [
                  %{
                    "type" => "p",
                    "children" => [%{"text" => "It was in the late 15th century."}]
                  }
                ],
                "editor" => "slate",
                "textDirection" => "ltr"
              }
            ],
            "responses" => [
              %{
                "id" => "response_1492",
                "rule" => "input = 1492",
                "score" => 1,
                "correct" => true,
                "feedback" => %{
                  "id" => "feedback_correct",
                  "content" => [
                    %{
                      "type" => "p",
                      "children" => [%{"text" => "Correct! Columbus arrived in 1492."}]
                    }
                  ],
                  "editor" => "slate",
                  "textDirection" => "ltr"
                }
              },
              %{
                "id" => "response_catchall",
                "rule" => "input like {.*}",
                "score" => 0,
                "correct" => false,
                "feedback" => %{
                  "id" => "feedback_incorrect",
                  "content" => [
                    %{
                      "type" => "p",
                      "children" => [
                        %{
                          "text" =>
                            "That's not correct. Columbus arrived in the Americas in 1492."
                        }
                      ]
                    }
                  ],
                  "editor" => "slate",
                  "textDirection" => "ltr"
                }
              }
            ]
          }
        ],
        "transformations" => [],
        "previewText" => "What year did Christopher Columbus first arrive in the Americas?"
      }
    }
  end

  defp check_all_that_apply_example do
    %{
      "stem" => %{
        "id" => "stem_1",
        "content" => [
          %{
            "type" => "p",
            "children" => [
              %{"text" => "Which of the following are primary colors? (Select all that apply)"}
            ]
          }
        ],
        "editor" => "slate",
        "textDirection" => "ltr"
      },
      "choices" => [
        %{
          "id" => "choice_red",
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "Red"}]
            }
          ],
          "editor" => "slate",
          "textDirection" => "ltr"
        },
        %{
          "id" => "choice_green",
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "Green"}]
            }
          ],
          "editor" => "slate",
          "textDirection" => "ltr"
        },
        %{
          "id" => "choice_blue",
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "Blue"}]
            }
          ],
          "editor" => "slate",
          "textDirection" => "ltr"
        },
        %{
          "id" => "choice_yellow",
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "Yellow"}]
            }
          ],
          "editor" => "slate",
          "textDirection" => "ltr"
        },
        %{
          "id" => "choice_purple",
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "Purple"}]
            }
          ],
          "editor" => "slate",
          "textDirection" => "ltr"
        }
      ],
      "authoring" => %{
        "version" => 2,
        "correct" => %{
          "value" => ["choice_red", "choice_blue"],
          "response" => "response_correct"
        },
        "targeted" => [],
        "parts" => [
          %{
            "id" => "part_1",
            "gradingApproach" => "automatic",
            "scoringStrategy" => "average",
            "hints" => [
              %{
                "id" => "hint_1",
                "content" => [
                  %{
                    "type" => "p",
                    "children" => [
                      %{"text" => "Primary colors cannot be created by mixing other colors."}
                    ]
                  }
                ],
                "editor" => "slate",
                "textDirection" => "ltr"
              }
            ],
            "responses" => [
              %{
                "id" => "response_correct",
                "rule" =>
                  "input contains {choice_red} && input contains {choice_blue} && !(input contains {choice_green}) && !(input contains {choice_yellow}) && !(input contains {choice_purple})",
                "score" => 1,
                "correct" => true,
                "feedback" => %{
                  "id" => "feedback_correct",
                  "content" => [
                    %{
                      "type" => "p",
                      "children" => [%{"text" => "Correct! Red and Blue are primary colors."}]
                    }
                  ],
                  "editor" => "slate",
                  "textDirection" => "ltr"
                }
              },
              %{
                "id" => "response_incorrect",
                "rule" => "input like {.*}",
                "score" => 0,
                "correct" => false,
                "feedback" => %{
                  "id" => "feedback_incorrect",
                  "content" => [
                    %{
                      "type" => "p",
                      "children" => [
                        %{"text" => "Not quite. The primary colors are Red and Blue."}
                      ]
                    }
                  ],
                  "editor" => "slate",
                  "textDirection" => "ltr"
                }
              }
            ]
          }
        ],
        "transformations" => [],
        "previewText" => "Which of the following are primary colors?"
      }
    }
  end

  defp likert_example do
    %{
      "stem" => %{
        "id" => "stem_1",
        "content" => [
          %{
            "type" => "p",
            "children" => [
              %{"text" => "Please rate your agreement with the following statements:"}
            ]
          }
        ],
        "editor" => "slate",
        "textDirection" => "ltr"
      },
      "choices" => [
        %{
          "id" => "choice_1",
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "Strongly Disagree"}]
            }
          ],
          "editor" => "slate",
          "textDirection" => "ltr",
          "value" => 1,
          "frequency" => 0
        },
        %{
          "id" => "choice_2",
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "Disagree"}]
            }
          ],
          "editor" => "slate",
          "textDirection" => "ltr",
          "value" => 2,
          "frequency" => 0
        },
        %{
          "id" => "choice_3",
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "Neutral"}]
            }
          ],
          "editor" => "slate",
          "textDirection" => "ltr",
          "value" => 3,
          "frequency" => 0
        },
        %{
          "id" => "choice_4",
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "Agree"}]
            }
          ],
          "editor" => "slate",
          "textDirection" => "ltr",
          "value" => 4,
          "frequency" => 0
        },
        %{
          "id" => "choice_5",
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "Strongly Agree"}]
            }
          ],
          "editor" => "slate",
          "textDirection" => "ltr",
          "value" => 5,
          "frequency" => 0
        }
      ],
      "orderDescending" => false,
      "items" => [
        %{
          "id" => "item_1",
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "The course content was well organized"}]
            }
          ],
          "editor" => "slate",
          "textDirection" => "ltr",
          "required" => true
        },
        %{
          "id" => "item_2",
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "The learning objectives were clear"}]
            }
          ],
          "editor" => "slate",
          "textDirection" => "ltr",
          "required" => true
        },
        %{
          "id" => "item_3",
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "I would recommend this course to others"}]
            }
          ],
          "editor" => "slate",
          "textDirection" => "ltr",
          "required" => false
        }
      ],
      "authoring" => %{
        "targeted" => [],
        "parts" => [
          %{
            "id" => "part_1",
            "gradingApproach" => "automatic",
            "scoringStrategy" => "average",
            "hints" => [],
            "responses" => [
              %{
                "id" => "response_any",
                "rule" => "input like {.*}",
                "score" => 1,
                "correct" => true,
                "feedback" => %{
                  "id" => "feedback_thanks",
                  "content" => [
                    %{
                      "type" => "p",
                      "children" => [%{"text" => "Thank you for your feedback!"}]
                    }
                  ],
                  "editor" => "slate",
                  "textDirection" => "ltr"
                }
              }
            ]
          }
        ],
        "transformations" => [],
        "previewText" => "Course feedback survey"
      },
      "activityTitle" => "Course Feedback Survey"
    }
  end

  defp multi_input_example do
    %{
      "stem" => %{
        "id" => "stem_1",
        "content" => [
          %{
            "type" => "p",
            "children" => [
              %{"text" => "Fill in the blanks: The chemical formula for water is "},
              %{"type" => "input_ref", "id" => "input_1"},
              %{"text" => " and it consists of "},
              %{"type" => "input_ref", "id" => "input_2"},
              %{"text" => " hydrogen atoms and "},
              %{"type" => "input_ref", "id" => "input_3"},
              %{"text" => " oxygen atom(s)."}
            ]
          }
        ],
        "editor" => "slate",
        "textDirection" => "ltr"
      },
      "choices" => [
        %{
          "id" => "choice_h2o",
          "content" => [%{"type" => "p", "children" => [%{"text" => "H2O"}]}],
          "editor" => "slate",
          "textDirection" => "ltr"
        },
        %{
          "id" => "choice_h2o2",
          "content" => [%{"type" => "p", "children" => [%{"text" => "H2O2"}]}],
          "editor" => "slate",
          "textDirection" => "ltr"
        },
        %{
          "id" => "choice_co2",
          "content" => [%{"type" => "p", "children" => [%{"text" => "CO2"}]}],
          "editor" => "slate",
          "textDirection" => "ltr"
        }
      ],
      "inputs" => [
        %{
          "id" => "input_1",
          "inputType" => "dropdown",
          "partId" => "part_1",
          "choiceIds" => ["choice_h2o", "choice_h2o2", "choice_co2"],
          "size" => "medium"
        },
        %{
          "id" => "input_2",
          "inputType" => "numeric",
          "partId" => "part_2",
          "size" => "small"
        },
        %{
          "id" => "input_3",
          "inputType" => "numeric",
          "partId" => "part_3",
          "size" => "small"
        }
      ],
      "submitPerPart" => false,
      "scoringStrategy" => "average",
      "authoring" => %{
        "targeted" => [],
        "parts" => [
          %{
            "id" => "part_1",
            "gradingApproach" => "automatic",
            "scoringStrategy" => "average",
            "hints" => [],
            "responses" => [
              %{
                "id" => "response_1_correct",
                "rule" => "input like {choice_h2o}",
                "score" => 1,
                "correct" => true,
                "feedback" => %{
                  "id" => "feedback_1_correct",
                  "content" => [
                    %{
                      "type" => "p",
                      "children" => [%{"text" => "Correct! H2O is the formula for water."}]
                    }
                  ],
                  "editor" => "slate",
                  "textDirection" => "ltr"
                }
              },
              %{
                "id" => "response_1_incorrect",
                "rule" => "input like {.*}",
                "score" => 0,
                "correct" => false,
                "feedback" => %{
                  "id" => "feedback_1_incorrect",
                  "content" => [
                    %{"type" => "p", "children" => [%{"text" => "The correct formula is H2O."}]}
                  ],
                  "editor" => "slate",
                  "textDirection" => "ltr"
                }
              }
            ]
          },
          %{
            "id" => "part_2",
            "gradingApproach" => "automatic",
            "scoringStrategy" => "average",
            "hints" => [],
            "responses" => [
              %{
                "id" => "response_2_correct",
                "rule" => "input = 2",
                "score" => 1,
                "correct" => true,
                "feedback" => %{
                  "id" => "feedback_2_correct",
                  "content" => [
                    %{
                      "type" => "p",
                      "children" => [%{"text" => "Correct! Water has 2 hydrogen atoms."}]
                    }
                  ],
                  "editor" => "slate",
                  "textDirection" => "ltr"
                }
              },
              %{
                "id" => "response_2_incorrect",
                "rule" => "input like {.*}",
                "score" => 0,
                "correct" => false,
                "feedback" => %{
                  "id" => "feedback_2_incorrect",
                  "content" => [
                    %{"type" => "p", "children" => [%{"text" => "Water has 2 hydrogen atoms."}]}
                  ],
                  "editor" => "slate",
                  "textDirection" => "ltr"
                }
              }
            ]
          },
          %{
            "id" => "part_3",
            "gradingApproach" => "automatic",
            "scoringStrategy" => "average",
            "hints" => [],
            "responses" => [
              %{
                "id" => "response_3_correct",
                "rule" => "input = 1",
                "score" => 1,
                "correct" => true,
                "feedback" => %{
                  "id" => "feedback_3_correct",
                  "content" => [
                    %{
                      "type" => "p",
                      "children" => [%{"text" => "Correct! Water has 1 oxygen atom."}]
                    }
                  ],
                  "editor" => "slate",
                  "textDirection" => "ltr"
                }
              },
              %{
                "id" => "response_3_incorrect",
                "rule" => "input like {.*}",
                "score" => 0,
                "correct" => false,
                "feedback" => %{
                  "id" => "feedback_3_incorrect",
                  "content" => [
                    %{"type" => "p", "children" => [%{"text" => "Water has 1 oxygen atom."}]}
                  ],
                  "editor" => "slate",
                  "textDirection" => "ltr"
                }
              }
            ]
          }
        ],
        "transformations" => [],
        "previewText" => "Water molecule composition"
      }
    }
  end

  defp ordering_example do
    %{
      "stem" => %{
        "id" => "stem_1",
        "content" => [
          %{
            "type" => "p",
            "children" => [%{"text" => "Order these historical events from earliest to latest:"}]
          }
        ],
        "editor" => "slate",
        "textDirection" => "ltr"
      },
      "choices" => [
        %{
          "id" => "choice_1",
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "World War II ends"}]
            }
          ],
          "editor" => "slate",
          "textDirection" => "ltr"
        },
        %{
          "id" => "choice_2",
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "American Civil War begins"}]
            }
          ],
          "editor" => "slate",
          "textDirection" => "ltr"
        },
        %{
          "id" => "choice_3",
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "Moon landing"}]
            }
          ],
          "editor" => "slate",
          "textDirection" => "ltr"
        },
        %{
          "id" => "choice_4",
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "Fall of the Berlin Wall"}]
            }
          ],
          "editor" => "slate",
          "textDirection" => "ltr"
        }
      ],
      "authoring" => %{
        "version" => 2,
        "correct" => %{
          "value" => ["choice_2", "choice_1", "choice_3", "choice_4"],
          "response" => "response_correct"
        },
        "targeted" => [],
        "parts" => [
          %{
            "id" => "part_1",
            "gradingApproach" => "automatic",
            "scoringStrategy" => "average",
            "hints" => [
              %{
                "id" => "hint_1",
                "content" => [
                  %{
                    "type" => "p",
                    "children" => [%{"text" => "Think about the dates: 1861, 1945, 1969, 1989"}]
                  }
                ],
                "editor" => "slate",
                "textDirection" => "ltr"
              }
            ],
            "responses" => [
              %{
                "id" => "response_correct",
                "rule" => "input = {choice_2,choice_1,choice_3,choice_4}",
                "score" => 1,
                "correct" => true,
                "feedback" => %{
                  "id" => "feedback_correct",
                  "content" => [
                    %{
                      "type" => "p",
                      "children" => [
                        %{"text" => "Correct! The events are in chronological order."}
                      ]
                    }
                  ],
                  "editor" => "slate",
                  "textDirection" => "ltr"
                }
              },
              %{
                "id" => "response_incorrect",
                "rule" => "input like {.*}",
                "score" => 0,
                "correct" => false,
                "feedback" => %{
                  "id" => "feedback_incorrect",
                  "content" => [
                    %{
                      "type" => "p",
                      "children" => [
                        %{
                          "text" =>
                            "Not quite. The correct order is: Civil War (1861), WWII ends (1945), Moon landing (1969), Berlin Wall falls (1989)."
                        }
                      ]
                    }
                  ],
                  "editor" => "slate",
                  "textDirection" => "ltr"
                }
              }
            ]
          }
        ],
        "transformations" => [
          %{
            "id" => "shuffle_1",
            "path" => "choices",
            "operation" => "shuffle",
            "firstAttemptOnly" => true
          }
        ],
        "previewText" => "Order historical events"
      }
    }
  end
end
