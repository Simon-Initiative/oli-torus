defmodule Oli.ImageClassifier do

  def serving() do

    batch_size = 4
    defn_options = [compiler: EXLA]

    Nx.Serving.new(
      # This function runs on the serving startup
      fn ->
        # Build the Axon model and load params (usually from file)
        model_info = build_model()
        params = download_params()

        # Build the prediction defn function
        {_init_fun, predict_fun} = Axon.build(model_info.model)

        inputs_template = %{"pixel_values" => Nx.template({batch_size, 224, 224, 3}, :f32)}
        template_args = [Nx.to_template(params), inputs_template]

        # Compile the prediction function upfront for the configured batch_size
        predict_fun = Nx.Defn.compile(predict_fun, template_args, defn_options)

        # The returned function is called for every accumulated batch
        fn inputs ->
          inputs = Nx.Batch.pad(inputs, batch_size - inputs.size)
          predict_fun.(params, inputs)
        end
      end,
      batch_size: batch_size
    )
  end

  defp download_params() do
    # download file usign HTTPs:
    model_url = "https://siegel-xapi-dev.s3.us-east-1.amazonaws.com/model.axon"
    {:ok, result} = HTTPoison.get(model_url)

    Nx.deserialize(result.body, [])
  end


  def build_model() do

    labels = labels()

    id_to_label =
      labels
      |> Enum.with_index()
      |> Enum.reduce(%{}, fn {label, idx}, m -> Map.put(m, idx, label) end)

    num_labels = Enum.count(labels)

    {:ok, spec} =
      Bumblebee.load_spec({:hf, "microsoft/resnet-50"},
        architecture: :for_image_classification
      )

    spec = Bumblebee.configure(spec, num_labels: num_labels, id_to_label: id_to_label)
    {:ok, model_info} = Bumblebee.load_model({:hf, "microsoft/resnet-50"}, spec: spec)
    IO.inspect(model_info)
    model_info
  end

  @labels [
    "table",
    "other",
    "code"
  ]
  def labels(), do: @labels

end
