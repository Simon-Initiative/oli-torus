defmodule OliWeb.Common.MathJaxScript do
  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <script>
      const mathJaxBlue = document.documentElement.classList.contains('dark') ? '#4CA6FF' : '#1B67B2';
      const mathJaxRed = document.documentElement.classList.contains('dark') ? '#FF4040' : '#B60202';
      window.MathJax = {
        tex: {
          inlineMath: [ ["\\(","\\)"] ],
          displayMath: [ ['$$','$$'], ["\\[","\\]"] ],
          processEscapes: true,
          packages: ['base', 'ams', 'noerrors', 'noundefined', 'require', 'autoload'],
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
          },
          color: {
            colors: {
              blue: mathJaxBlue,
              Blue: mathJaxBlue,
              red: mathJaxRed,
              Red: mathJaxRed
            }
          }
        },
        options: {
          ignoreHtmlClass: 'tex2jax_ignore',
          processHtmlClass: 'tex2jax_process'
        },
        loader: {
          load: ['[tex]/noerrors']
        },
        renderMathML(math, doc) {
          math.typesetRoot = document.createElement('mjx-container');
          math.typesetRoot.innerHTML = MathJax.startup.toMML(math.root);
          math.display && math.typesetRoot.setAttribute('display', 'block');
        }
      };
    </script>
    <style>
      :root.dark mjx-container [style*="color: rgb(0, 0, 255)"],
      :root.dark mjx-container [style*="color: #0000ff"] {
        color: #4CA6FF !important;
      }
      :root.dark mjx-container [style*="color: rgb(255, 0, 0)"],
      :root.dark mjx-container [style*="color: #ff0000"] {
        color: #FF4040 !important;
      }
      :root:not(.dark) mjx-container [style*="color: rgb(0, 0, 255)"],
      :root:not(.dark) mjx-container [style*="color: #0000ff"] {
        color: #1B67B2 !important;
      }
      :root:not(.dark) mjx-container [style*="color: rgb(255, 0, 0)"],
      :root:not(.dark) mjx-container [style*="color: #ff0000"] {
        color: #B60202 !important;
      }
    </style>
    <script src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js" id="MathJax-script">
    </script>
    """
  end
end
