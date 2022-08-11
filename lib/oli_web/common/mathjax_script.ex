defmodule OliWeb.Common.MathJaxScript do
  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <script>
    window.MathJax = {
      tex: {
        inlineMath: [ ["\\(","\\)"] ],
        displayMath: [ ['$$','$$'], ["\\[","\\]"] ],
        processEscapes: true,
        packages: ['base', 'ams', 'noerrors', 'noundefined', 'require']
      },
      options: {
        ignoreHtmlClass: 'tex2jax_ignore',
        processHtmlClass: 'tex2jax_process'
      },
      loader: {
        load: ['[tex]/noerrors']
      }
    };
    </script>
    <script src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js" id="MathJax-script"></script>
    """
  end
end
