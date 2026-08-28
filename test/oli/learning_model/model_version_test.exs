defmodule Oli.LearningModel.ModelVersionTest do
  use ExUnit.Case, async: true

  alias Oli.LearningModel.ModelVersion

  test "exposes and encodes only semantic model versions" do
    assert ModelVersion.values() == [:naive, :lkt_aoa]
    assert ModelVersion.encode(:naive) == "naive"
    assert ModelVersion.encode(:lkt_aoa) == "lkt_aoa"
  end

  test "decodes supported archive strings" do
    assert ModelVersion.decode_archive("naive", :lkt_aoa) == {:ok, :naive}
    assert ModelVersion.decode_archive("lkt_aoa", :naive) == {:ok, :lkt_aoa}
  end

  test "uses the caller's fallback only for a missing archive value" do
    assert ModelVersion.decode_archive(nil, :naive) == {:ok, :naive}
    assert ModelVersion.decode_archive(nil, :lkt_aoa) == {:ok, :lkt_aoa}

    assert ModelVersion.decode_archive("", :naive) ==
             {:error, {:invalid_learning_model_version, ""}}

    assert ModelVersion.decode_archive(:lkt_aoa, :naive) ==
             {:error, {:invalid_learning_model_version, :lkt_aoa}}

    assert ModelVersion.decode_archive(2, :naive) ==
             {:error, {:invalid_learning_model_version, 2}}
  end

  test "rejects an unsupported fallback" do
    assert ModelVersion.decode_archive(nil, :v2) ==
             {:error, {:invalid_learning_model_version, :v2}}
  end
end
