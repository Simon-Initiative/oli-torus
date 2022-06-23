import { FullScreenModal } from 'components/editing/toolbar/FullScreenModal';
import React, { Suspense, useState } from 'react';
import * as ContentModel from 'data/content/model/elements/types';
import * as monaco from 'monaco-editor';
import { Formula } from '../../../common/Formula';
import { isDarkMode } from '../../../../utils/browser';
import { FormulaToolbar } from './FormulaToolbar';

const MonacoEditor = React.lazy(() => import('@uiw/react-monacoeditor'));

type AllFormulaType = ContentModel.FormulaBlock | ContentModel.FormulaInline;

interface ModalProps {
  onDone: (x: any) => void;
  onCancel: () => void;
  model: AllFormulaType;
}

const languageForSubtype = (subtype: ContentModel.FormulaSubTypes) =>
  subtype === 'mathml' ? 'xml' : 'text';

export const FormulaModal = ({ onDone, onCancel, model }: ModalProps) => {
  const [src, setSrc] = useState(model.src);
  const [subtype, setSubtype] = useState(model.subtype);

  const editorDidMount = (e: monaco.editor.IStandaloneCodeEditor) => {
    e.layout({
      width: 600,
      height: 300,
    });
  };

  return (
    <FullScreenModal onCancel={(_e) => onCancel()} onDone={() => onDone({ src, subtype })}>
      <div className="formula-editor">
        <h3 className="mb-2">Formula Editor</h3>
        <div className="split-editor">
          <div className="editor">
            <FormulaToolbar setSubtype={setSubtype} subtype={subtype} />
            <Suspense fallback={<div>Loading...</div>}>
              <MonacoEditor
                value={model.src}
                language={languageForSubtype(subtype)}
                key={subtype}
                options={{
                  tabSize: 2,
                  scrollBeyondLastLine: false,
                  minimap: { enabled: false },
                  theme: isDarkMode() ? 'vs-dark' : 'vs-light',
                }}
                onChange={setSrc}
                editorDidMount={editorDidMount}
              />
            </Suspense>
          </div>
          <div className="preview">
            <h4>Preview</h4>
            <Formula src={src} subtype={subtype} />
          </div>
        </div>
      </div>
    </FullScreenModal>
  );
};
