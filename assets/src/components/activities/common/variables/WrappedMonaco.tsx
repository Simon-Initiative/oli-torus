import React, { PropsWithChildren, useEffect, useRef, Suspense, useState } from 'react';
import { throttle } from 'lodash';
import { CodeLanguages } from 'components/editing/elements/blockcode/codeLanguages';
import * as monaco from 'monaco-editor';
import { RefEditorInstance } from '@uiw/react-monacoeditor';
import { isDarkMode, addDarkModeListener, removeDarkModeListener } from 'utils/browser';

const MonacoEditor = React.lazy(() => import('@uiw/react-monacoeditor'));

type WrappedMonacoProps = {
  model: string;
  onEdit: (model: string) => void;
  editMode: boolean;
};

export const WrappedMonaco = (props: PropsWithChildren<WrappedMonacoProps>) => {
  const editorContainer = useRef<HTMLDivElement>(null);
  const editorRef = useRef<RefEditorInstance>(null);
  const [model] = useState(props.model);

  const updateSize = (editor?: monaco.editor.IStandaloneCodeEditor) => {
    if (editor && editorContainer.current) {
      const contentHeight = Math.min(1000, editor.getContentHeight());
      editorContainer.current.style.height = `${contentHeight}px`;
      editor.layout({
        width: editorContainer.current.offsetWidth,
        height: contentHeight,
      });
    }
  };

  const editorDidMount = (e: monaco.editor.IStandaloneCodeEditor) => {
    e.onDidContentSizeChange(() => updateSize(e));
    updateSize(e);
  };

  useEffect(() => {
    // listen for browser theme changes and update code editor accordingly
    const listener = addDarkModeListener((theme: string) => {
      if (theme === 'light') {
        editorRef.current?.editor?.updateOptions({ theme: 'vs-light' });
      } else {
        editorRef.current?.editor?.updateOptions({ theme: 'vs-dark' });
      }
    });

    const handleResize = throttle(() => updateSize(editorRef.current?.editor), 200);
    window.addEventListener('resize', handleResize);

    return () => {
      removeDarkModeListener(listener);
      window.removeEventListener('resize', handleResize);
    };
  }, []);

  return (
    <div>
      <div ref={editorContainer} className="border">
        <Suspense fallback={<div>Loading...</div>}>
          <MonacoEditor
            ref={editorRef}
            value={model}
            language={CodeLanguages.byPrettyName('JavaScript').monacoMode}
            options={{
              tabSize: 2,
              scrollBeyondLastLine: false,
              minimap: { enabled: false },
              theme: isDarkMode() ? 'vs-dark' : 'vs-light',
            }}
            onChange={(code) => props.onEdit(code)}
            editorDidMount={editorDidMount}
          />
        </Suspense>
      </div>
    </div>
  );
};
