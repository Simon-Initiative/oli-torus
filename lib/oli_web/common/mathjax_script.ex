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
        packages: ['base', 'ams', 'noerrors', 'noundefined', 'require'],
        require: {
          defaultAllow: false,
          allow: {
            "action": true,
            "amscd": true,
            "bbox": true,
            "boldsymbol": true,
            "braket": true,
            "bussproofs": true,
            "cancel": true,
            "cases": true,
            "centernot": true,
            "color": true,
            "colortbl": true,
            "colorv2": true,
            "configmacros": true,
            "empheq": true,
            "enclose": true,
            "extpfeil": true,
            "gensymb": true,
            "html": true,
            "mathtools": true,
            "mhchem": true,
            "physics": true,
            "setoptions": true,
            "tagformat": true,
            "textcomp": true,
            "textmacros": true,
            "unicode": true,
            "upgreek": true,
            "verb": true
          }
        }
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
