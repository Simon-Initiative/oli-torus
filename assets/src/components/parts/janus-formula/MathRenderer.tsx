import React, { useState } from 'react';
import { Button, Modal } from 'react-bootstrap';
import { MathJax, MathJaxContext } from 'better-react-mathjax';
import { MathLive } from 'components/common/MathLive';

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

interface MathEditorModalProps {
  show: boolean;
  onClose: () => void;
  onSave: (data: { input: string; altText: string }) => void;
  initialInput: string;
  initialAlt: string;
}

const MathRenderer: React.FC<MathEditorModalProps> = ({
  show,
  onClose,
  onSave,
  initialInput,
  initialAlt,
}) => {
  const [input, setInput] = useState(initialInput || '');
  const [altText, setAltText] = useState(initialAlt || '');
  const [mode, setMode] = useState<'plain' | 'builder'>('plain');

  const isMathML = input.trim().startsWith('<math');
  const content = isMathML ? input : `\\(${input}\\)`;

  const handleSave = () => {
    onSave({ input, altText });
    onClose();
  };

  return (
    <Modal show={show} onHide={onClose} size="lg">
      <Modal.Header closeButton className="bg-gray-50 border-b border-gray-200 px-6 py-4">
        <Modal.Title className="text-lg font-semibold text-gray-800">
          Math Expression Editor
        </Modal.Title>
      </Modal.Header>
      <Modal.Body>
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
          <div
            style={{
              fontWeight: 'bold',
              fontSize: '14px',
              marginBottom: '8px',
              color: '#555',
            }}
          >
            Live Preview:
          </div>
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
            <MathJaxContext
              config={config}
              version={3}
              src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"
            >
              <MathJax dynamic>
                <div
                  dangerouslySetInnerHTML={{ __html: content }}
                  role="math"
                  aria-label={altText}
                />
              </MathJax>
            </MathJaxContext>
          </div>
        </div>
      </Modal.Body>
      <Modal.Footer className="bg-gray-50 border-t border-gray-200 px-6 py-3 flex justify-end space-x-2">
        <Button variant="secondary" onClick={onClose}>
          Cancel
        </Button>
        <Button variant="primary" onClick={handleSave}>
          Save
        </Button>
      </Modal.Footer>
    </Modal>
  );
};

export default MathRenderer;
