import React from 'react';
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
import { config } from 'ace-builds';
import AceEditor from 'react-ace';
import 'ace-builds/src-noconflict/theme-github';
import 'ace-builds/src-noconflict/mode-assembly_x86';
import 'ace-builds/src-noconflict/mode-c_cpp';
import 'ace-builds/src-noconflict/mode-csharp';
import 'ace-builds/src-noconflict/mode-elixir';
import 'ace-builds/src-noconflict/mode-golang';
import 'ace-builds/src-noconflict/mode-haskell';
import 'ace-builds/src-noconflict/mode-html';
import 'ace-builds/src-noconflict/mode-java';
import 'ace-builds/src-noconflict/mode-javascript';
import 'ace-builds/src-noconflict/mode-kotlin';
import 'ace-builds/src-noconflict/mode-lisp';
import 'ace-builds/src-noconflict/mode-ocaml';
import 'ace-builds/src-noconflict/mode-perl';
import 'ace-builds/src-noconflict/mode-php';
import 'ace-builds/src-noconflict/mode-python';
import 'ace-builds/src-noconflict/mode-r';
import 'ace-builds/src-noconflict/mode-ruby';
import 'ace-builds/src-noconflict/mode-sql';
import 'ace-builds/src-noconflict/mode-text';
import 'ace-builds/src-noconflict/mode-typescript';
import 'ace-builds/src-noconflict/mode-xml';
import { classNames } from 'utils/classNames';
import { ReactEditor, useSelected, useSlate } from 'slate-react';
import { Editor } from 'slate';

config.set('basePath', 'https://cdn.jsdelivr.net/npm/ace-builds@1.4.13/src-noconflict/');
config.setModuleUrl(
  'ace/mode/javascript_worker',
  'https://cdn.jsdelivr.net/npm/ace-builds@1.4.13/src-noconflict/worker-javascript.js',
);

const getInitialModel = (model: ContentModel.Code) => {
  const editor = useSlate();
  // v2 -- code in code attr
  if (model.code) return model.code;

  // v1 -- code is in code_line child elements
  const code = Editor.string(editor, ReactEditor.findPath(editor, model));
  return code;
};

type CodeProps = EditorProps<ContentModel.Code>;
export const CodeEditor = (props: CodeProps) => {
  const isSelected = useSelected();
  const [value, setValue] = React.useState(getInitialModel(props.model));
  const onEdit = onEditModel(props.model);
  const reactAce = React.useRef<AceEditor | null>(null);
  const aceEditor = reactAce.current?.editor;

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
                {CodeLanguages.all().map(({ prettyName, aceMode }, i) => (
                  <DescriptiveButton
                    key={i}
                    description={createButtonCommandDesc({
                      icon: '',
                      description: prettyName,
                      active: () => prettyName === props.model.language,
                      execute: () => {
                        aceEditor?.session.setMode(aceMode);
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
        <>
          <AceEditor
            className={classNames(['code-editor', isSelected && 'active'])}
            ref={reactAce}
            mode={CodeLanguages.byPrettyName(props.model.language).aceMode}
            style={{ width: '100%' }}
            theme="github"
            onChange={(code) => {
              onEdit({ code });
              setValue(code);
            }}
            value={value}
            highlightActiveLine
            tabSize={2}
            wrapEnabled
            setOptions={{
              fontSize: 16,
              showGutter: false,
              minLines: 2,
              maxLines: Infinity,
            }}
            placeholder={'fibs = 0 : 1 : zipWith (+) fibs (tail fibs)'}
          />
          {...props.children}
          <CaptionEditor onEdit={(caption) => onEdit({ caption })} model={props.model} />
        </>
      </HoverContainer>
    </div>
  );
};
