import React, { PropsWithChildren, useState, useEffect, useRef, Suspense } from 'react';
import { throttle } from 'lodash';
import { onEditModel } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { EditorProps } from 'components/editing/elements/interfaces';
import { CaptionEditor } from 'components/editing/elements/common/settings/CaptionEditor';
import { CodeLanguages } from 'components/editing/elements/blockcode/codeLanguages';
import { ReactEditor, useSlate } from 'slate-react';
import { Editor } from 'slate';
import * as monaco from 'monaco-editor';
import { RefEditorInstance } from '@uiw/react-monacoeditor';
import { isDarkMode, addDarkModeListener, removeDarkModeListener } from 'utils/browser';
import { DropdownSelect, DropdownItem } from 'components/common/DropdownSelect';

const MonacoEditor = React.lazy(() => import('@uiw/react-monacoeditor'));

const getInitialModel = (model: ContentModel.Code) => {
  const editor = useSlate();
  // v2 -- code in code attr
  if (model.code) return model.code;

  // v1 -- code is in code_line child elements
  const code = Editor.string(editor, ReactEditor.findPath(editor, model));
  return code;
};

type CodeEditorProps = EditorProps<ContentModel.Code>;
export const CodeEditor = (props: PropsWithChildren<CodeEditorProps>) => {
  const editorContainer = useRef<HTMLDivElement>(null);
  const editorRef = useRef<RefEditorInstance>(null);
  const [value] = useState(getInitialModel(props.model));

  const onEdit = onEditModel(props.model);

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
    <div {...props.attributes} contentEditable={false}>
      <DropdownSelect
        className="my-2"
        text={props.model.language}
        bsBtnClass="btn-outline-secondary btn-sm"
      >
        {CodeLanguages.all().map(({ prettyName }, i) => (
          <DropdownItem
            key={i}
            onClick={() => {
              onEdit({ language: prettyName });

              const model = editorRef.current?.editor?.getModel();
              if (model) {
                monaco.editor.setModelLanguage(model, prettyName);
              }
            }}
            className={prettyName === props.model.language ? 'active' : ''}
          >
            {prettyName}
          </DropdownItem>
        ))}
      </DropdownSelect>
      <div ref={editorContainer} className="border">
        <Suspense fallback={<div>Loading...</div>}>
          <MonacoEditor
            ref={editorRef}
            value={value}
            language={CodeLanguages.byPrettyName(props.model.language).monacoMode}
            options={{
              tabSize: 2,
              scrollBeyondLastLine: false,
              minimap: { enabled: false },
              theme: isDarkMode() ? 'vs-dark' : 'vs-light',
            }}
            onChange={(code) => {
              onEdit({ code });
            }}
            editorDidMount={editorDidMount}
          />
        </Suspense>
      </div>

      {props.children}
      <CaptionEditor onEdit={(caption) => onEdit({ caption })} model={props.model} />
    </div>
  );
};
