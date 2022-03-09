import React, { PropsWithChildren, useMemo, useEffect, useState, useCallback } from 'react';
import { throttle } from 'lodash';
import { onEditModel } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { EditorProps } from 'components/editing/elements/interfaces';
import { CaptionEditor } from 'components/editing/elements/common/settings/CaptionEditor';
import { CodeLanguages } from 'components/editing/elements/blockcode/codeLanguages';
import { DropdownButton } from 'components/editing/toolbar/buttons/DropdownButton';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { DescriptiveButton } from 'components/editing/toolbar/buttons/DescriptiveButton';
import { HoverContainer } from 'components/editing/toolbar/HoverContainer';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { ReactEditor, useSelected, useSlate } from 'slate-react';
import { Editor } from 'slate';
import * as monaco from 'monaco-editor';
import ReactMonacoEditor from '@uiw/react-monacoeditor';
import { isDarkMode, addDarkModeListener, removeDarkModeListener } from 'utils/browser';

const getInitialModel = (model: ContentModel.Code) => {
  const editor = useSlate();
  // v2 -- code in code attr
  if (model.code) return model.code;

  // v1 -- code is in code_line child elements
  const code = Editor.string(editor, ReactEditor.findPath(editor, model));
  return code;
};

let editor: monaco.editor.IStandaloneCodeEditor;
let editorContainer: HTMLElement;

type CodeProps = EditorProps<ContentModel.Code>;
export const CodeEditor = (props: PropsWithChildren<CodeProps>) => {
  const isSelected = useSelected();
  const [value] = useState(getInitialModel(props.model));

  const onEdit = onEditModel(props.model);

  const updateSize = () => {
    const contentHeight = Math.min(1000, editor.getContentHeight());
    editorContainer.style.height = `${contentHeight}px`;
    editor.layout({ width: editorContainer.offsetWidth, height: contentHeight });
  };

  const editorDidMount = (e: monaco.editor.IStandaloneCodeEditor) => {
    editor = e;
    editor.onDidContentSizeChange(updateSize);
  };

  useEffect(() => {
    // listen for browser theme changes and update code editor accordingly
    const listener = addDarkModeListener((theme: string) => {
      if (theme === 'light') {
        editor.updateOptions({ theme: 'vs-light' });
      } else {
        editor.updateOptions({ theme: 'vs-dark' });
      }
    });

    const handleResize = throttle(updateSize, 200);
    window.addEventListener('resize', handleResize);

    return () => {
      removeDarkModeListener(listener);
      window.removeEventListener('resize', handleResize);
    };
  }, []);

  return (
    <div {...props.attributes} contentEditable={false}>
      <HoverContainer
        isOpen={isSelected}
        align="start"
        position="top"
        content={
          <Toolbar context={props.commandContext}>
            <Toolbar.Group>
              <DropdownButton
                description={createButtonCommandDesc({
                  icon: '',
                  description: props.model.language,
                  active: (_editor) => false,
                  execute: (_ctx, _editor) => {},
                })}
              >
                {CodeLanguages.all().map(({ prettyName }, i) => (
                  <DescriptiveButton
                    key={i}
                    description={createButtonCommandDesc({
                      icon: '',
                      description: prettyName,
                      active: () => prettyName === props.model.language,
                      execute: () => {
                        onEdit({ language: prettyName });
                      },
                    })}
                  />
                ))}
              </DropdownButton>
            </Toolbar.Group>
          </Toolbar>
        }
      >
        {useMemo(
          () => (
            <div
              ref={(d) => {
                editorContainer = d as HTMLElement;
              }}
            >
              <ReactMonacoEditor
                value={value}
                language={CodeLanguages.byPrettyName(props.model.language).aceMode}
                options={{
                  tabSize: 2,
                  scrollBeyondLastLine: false,
                  minimap: { enabled: false },
                  theme: isDarkMode() ? 'vs-dark' : 'vs-light',
                }}
                onChange={(code) => onEdit({ code })}
                editorDidMount={editorDidMount}
              />
            </div>
          ),
          [],
        )}

        {props.children}
        <CaptionEditor onEdit={(caption) => onEdit({ caption })} model={props.model} />
      </HoverContainer>
    </div>
  );
};
