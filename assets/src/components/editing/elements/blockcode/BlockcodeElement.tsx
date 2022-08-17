import React, { PropsWithChildren, useEffect, useRef, Suspense, useState } from 'react';
import { throttle } from 'lodash';
import { useEditModelCallback } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { EditorProps } from 'components/editing/elements/interfaces';
import { CaptionEditor } from 'components/editing/elements/common/settings/CaptionEditor';
import { CodeLanguages } from 'components/editing/elements/blockcode/codeLanguages';
import * as monaco from 'monaco-editor';
import { RefEditorInstance } from '@uiw/react-monacoeditor';
import { isDarkMode, addDarkModeListener, removeDarkModeListener } from 'utils/browser';
import { DropdownSelect, DropdownItem } from 'components/common/DropdownSelect';
import './BlockcodeElement.scss';

const MonacoEditor = React.lazy(() => import('@uiw/react-monacoeditor'));

const isCodeV2Model = (model: any) => model.code !== undefined;

const migrateV1toV2 = (model: ContentModel.CodeV1) => {
  const code = (model as ContentModel.CodeV1).children
    .map((c) => c.children.map((t) => t.text).join(''))
    .join('\n');

  const updatedModel = model as any as ContentModel.CodeV2;
  updatedModel.code = code;
  updatedModel.children = [{ text: '' }];

  return updatedModel;
};

const getInitialModel = (model: ContentModel.CodeV2 | ContentModel.CodeV1): ContentModel.CodeV2 => {
  if (isCodeV2Model(model)) {
    return model as ContentModel.CodeV2;
  }

  // v1 -- code is in code_line child elements, upgrade model to v2
  return migrateV1toV2(model as ContentModel.CodeV1);
};

type CodeEditorProps = EditorProps<ContentModel.Code>;
export const CodeEditor = (props: PropsWithChildren<CodeEditorProps>) => {
  const editorContainer = useRef<HTMLDivElement>(null);
  const editorRef = useRef<RefEditorInstance>(null);
  const [model] = useState(getInitialModel(props.model));

  const onEdit = useEditModelCallback(model);

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
            value={model.code}
            language={CodeLanguages.byPrettyName(props.model.language).monacoMode}
            options={{
              tabSize: 2,
              scrollBeyondLastLine: false,
              minimap: { enabled: false },
              theme: isDarkMode() ? 'vs-dark' : 'vs-light',
            }}
            onChange={(code) => onEdit({ code })}
            editorDidMount={editorDidMount}
          />
        </Suspense>
      </div>

      {props.children}
      <CaptionEditor
        onEdit={(caption) => onEdit({ caption })}
        model={props.model}
        commandContext={props.commandContext}
      />
    </div>
  );
};
