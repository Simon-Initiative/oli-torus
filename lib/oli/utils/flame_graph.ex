defmodule Oli.Utils.FlameGraph do
  @stack_files_dir "_flame_graph_stacks"
  @svg_dir "priv/static/flame_graphs"
  @url_base "/flame_graphs"

  def create(func, tag) do
    File.mkdir(@stack_files_dir)
    filename = "#{@stack_files_dir}/#{tag}.out"
    :eflame.apply(:normal_with_children, filename, func, [])
  end

  def list() do
    Path.wildcard("#{@stack_files_dir}/*.out")
  end

  def to_svg(stack_filename) do
    File.mkdir(@svg_dir)

    svg_filename = Path.basename(stack_filename, ".out") <> ".svg"

    "deps/eflame/stack_to_flame.sh < #{stack_filename} > #{@svg_dir}/#{svg_filename}"
    |> String.to_charlist()
    |> :os.cmd()

    "#{@url_base}/#{svg_filename}"
  end
end
