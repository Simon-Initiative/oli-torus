import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { MathJaxContext } from 'better-react-mathjax';
import { clone, parseBoolean } from 'utils/common';
import { AuthorPartComponentProps } from '../types/parts';
import FormulaPreview from './FormulaPreview';
import MathRenderer from './MathRenderer';
import { FormulaModel } from './schema';

const FormulaAuthor: React.FC<AuthorPartComponentProps<FormulaModel>> = (props) => {
  const { configuremode, id, model: incomingModel, onSaveConfigure, onReady } = props;

  const [model, setModel] = useState<FormulaModel>(incomingModel);
  const [inConfigureMode, setInConfigureMode] = useState(parseBoolean(configuremode));
  const [ready, setReady] = useState(false);
  const [showModal, setShowModal] = useState(false);
  const [mathData, setMathData] = useState({
    input: incomingModel.formula,
    altText: incomingModel.formulaAltText,
  });

  useEffect(() => setModel(incomingModel), [incomingModel]);
  useEffect(() => setInConfigureMode(parseBoolean(configuremode)), [configuremode]);

  const initialize = useCallback(() => setReady(true), []);
  useEffect(() => {
    initialize();
  }, [initialize]);

  useEffect(() => {
    if (ready) {
      onReady({ id, responses: [] });
    }
  }, [ready, id, onReady]);

  const handleFormulaSave = (data: any) => {
    setMathData(data);
    const modelClone = clone(model);
    modelClone.formula = data.input;
    modelClone.formulaAltText = data.altText;
    setModel(modelClone);
    onSaveConfigure({ id, snapshot: modelClone });
  };

  const mathjaxConfig = useMemo(
    () => ({
      loader: { load: ['[tex]/mhchem'] },
      tex: { packages: { '[+]': ['mhchem'] } },
      options: { enableAssistiveMml: true },
    }),
    [],
  );

  const renderPreview = useMemo(() => {
    if (!mathData.input) return null;
    return (
      <MathJaxContext
        config={mathjaxConfig}
        version={3}
        src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"
      >
        <FormulaPreview input={mathData.input} altText={mathData.altText} />
      </MathJaxContext>
    );
  }, [mathData.input, mathData.altText, mathjaxConfig]);

  if (!model.visible || !ready) return null;

  return (
    <div>
      {inConfigureMode ? (
        <MathRenderer
          show={true}
          onClose={() => setShowModal(false)}
          onSave={(data) => setMathData(data)}
          initialInput={mathData.input}
          initialAlt={mathData.altText}
        />
      ) : (
        <>
          <button className="btn btn-primary" onClick={() => setShowModal(true)}>
            {mathData.input ? 'Edit Expression' : 'Add Math Expression'}
          </button>
          {showModal && (
            <MathRenderer
              show={showModal}
              onClose={() => setShowModal(false)}
              onSave={handleFormulaSave}
              initialInput={mathData.input}
              initialAlt={mathData.altText}
            />
          )}
          {renderPreview}
        </>
      )}
    </div>
  );
};

export const tagName = 'janus-formula';
export default React.memo(FormulaAuthor);
