import { EditorProps } from 'components/editing/elements/interfaces';
import { CitationEditor } from 'components/editing/elements/cite/CitationEditor';
import { InlineChromiumBugfix, updateModel } from 'components/editing/elements/utils';
import { HoverContainer } from 'components/editing/toolbar/HoverContainer';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import * as ContentModel from 'data/content/model/elements/types';
import React from 'react';
import { useSelected, useSlate } from 'slate-react';
import { CommandButton } from 'components/editing/toolbar/buttons/CommandButton';
import { createButtonCommandDesc } from '../commands/commandFactories';
import { configureStore } from 'state/store';
import { modalActions } from 'actions/modal';
import ModalSelection from 'components/modal/ModalSelection';
import { Provider } from 'react-redux';

const dismiss = () => window.oliDispatch(modalActions.dismiss());
const display = (c: any) => window.oliDispatch(modalActions.display(c));
const store = configureStore();

export interface Props extends EditorProps<ContentModel.Citation> {}

export const CiteEditor = (props: Props) => {
  const editor = useSlate();
  const selected = useSelected();
  const isOpen = React.useCallback(() => selected, [selected]);

  const onEdit = (updated: Partial<ContentModel.Citation>) =>
    updateModel<ContentModel.Citation>(editor, props.model, updated);

  const onDone = React.useCallback(
    (changes: Partial<ContentModel.Citation>) => {
      dismiss();
      onEdit(changes);
    },
    [onEdit],
  );

  const onCancel = React.useCallback(() => {
    dismiss();
  }, []);

  const execute = React.useCallback(
    (_context, _editor, _params) => {
      let selected = props.model;
      display(
        <Provider store={store}>
          <ModalSelection
            title="Bibliography"
            onCancel={onCancel}
            onInsert={() => onDone({ ...selected })}
            disableInsert={false}
          >
            <CitationEditor
              commandContext={props.commandContext}
              model={props.model}
              onSelectionChange={(selection: ContentModel.Citation) => {
                selected = selection;
              }}
            />
          </ModalSelection>
        </Provider>,
      );
    },
    [props.commandContext, props.model, onDone, onCancel],
  );

  return (
    <cite
      {...props.attributes}
      id={props.model.id}
      // className="inline-link"
      style={{ boxShadow: '0 0 0 3px #ddd' }}
    >
      <HoverContainer
        isOpen={isOpen}
        position="bottom"
        align="start"
        content={
          <Toolbar context={props.commandContext} orientation={'horizontal'}>
            <Toolbar.Group>
              <CommandButton
                description={createButtonCommandDesc({
                  icon: 'edit',
                  description: 'Edit content',
                  execute,
                })}
              />
            </Toolbar.Group>
          </Toolbar>
        }
      ></HoverContainer>
      <InlineChromiumBugfix />
      <sup>{props.children}</sup>
      <InlineChromiumBugfix />
    </cite>
  );
};
