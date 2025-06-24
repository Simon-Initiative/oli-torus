import React, { useEffect, useState } from 'react';
import { MathJax, MathJaxContext } from 'better-react-mathjax';
import { MathLive } from 'components/common/MathLive';
import register from '../customElementWrapper';

const config = {
  loader: {
    load: ['[tex]/mhchem'],
  },
  tex: {
    packages: { '[+]': ['mhchem'] },
  },
  options: {
    enableAssistiveMml: true,
  },
};

interface FormulaEditorProps {
  onClose: () => void;
  onChange: (data: { input: string; altText: string }) => void;
  onSave: (data: { input: string; altText: string }) => void;
  formula: string;
  alttext: string;
}

const FormulaEditor: React.FC<FormulaEditorProps> = ({ onChange, formula, alttext }) => {
  const [input, setInput] = useState(formula || '');
  const [altText, setAltText] = useState(alttext || '');
  const [mode, setMode] = useState<'plain' | 'builder'>('plain');

  const isMathML = input.trim().startsWith('<math');
  const content = isMathML ? input : `\\(${input}\\)`;

  useEffect(() => {
    onChange({ input, altText });
  }, [input, altText, onChange]);

  return (
    <>
      <div className="mb-4">
        <label className="font-semibold text-sm mb-2 block">Choose Input Mode:</label>
        <div className="flex gap-4">
          <label className="flex items-center space-x-2">
            <input
              type="radio"
              name="inputMode"
              value="plain"
              checked={mode === 'plain'}
              onChange={() => setMode('plain')}
            />
            <span>Plain Text / LaTeX / MathML</span>
          </label>
          <label className="flex items-center space-x-2">
            <input
              type="radio"
              name="inputMode"
              value="builder"
              checked={mode === 'builder'}
              onChange={() => setMode('builder')}
            />
            <span>Visual Builder</span>
          </label>
        </div>
      </div>

      {mode === 'plain' ? (
        <label>
          <textarea
            value={input}
            onChange={(e) => setInput(e.target.value)}
            rows={2}
            placeholder="Enter LaTeX or MathML here"
            className="w-full p-3 border border-gray-300 rounded-xl shadow-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 font-mono text-sm"
          />
        </label>
      ) : (
        <MathLive
          value={input}
          options={{ readOnly: false }}
          onChange={(latex: string) => setInput(latex)}
        />
      )}

      <label style={{ display: 'block', marginTop: 12 }}>
        Alt text (for screen readers):
        <input
          type="text"
          value={altText}
          onChange={(e) => setAltText(e.target.value)}
          placeholder="Please enter alt text for screen reader"
          className="w-full p-3 border border-gray-300 rounded-xl shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-sm"
        />
      </label>

      <div style={{ marginTop: 24 }}>
        <div className="text-sm font-bold text-gray-600 mb-2">Live Preview:</div>
        <div
          style={{
            border: '1px solid #ddd',
            borderRadius: '8px',
            padding: '16px',
            backgroundColor: '#f9f9f9',
            fontSize: '20px',
            minHeight: '60px',
          }}
        >
          <MathJaxContext config={config} version={3}>
            <MathJax dynamic>
              <div dangerouslySetInnerHTML={{ __html: content }} role="math" aria-label={altText} />
            </MathJax>
          </MathJaxContext>
        </div>
      </div>
    </>
  );
};

export default FormulaEditor;

export const formulaTagName = 'formula-editor';

export const registerFormulaEditor = () => {
  if (!customElements.get(formulaTagName)) {
    register(FormulaEditor, formulaTagName, ['formula', 'alttext'], {
      customEvents: {
        onSave: `${formulaTagName}-save`,
        onChange: `${formulaTagName}-change`,
        onCancel: `${formulaTagName}-cancel`,
      },
      attrs: {
        tree: {
          json: true,
        },
      },
    });
  }
};
