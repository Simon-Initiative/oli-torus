import React from 'react';
import { Provider } from 'react-redux';
import { useSelected, useSlate } from 'slate-react';
import { CitationEditor } from 'components/editing/elements/cite/CitationEditor';
import { EditorProps } from 'components/editing/elements/interfaces';
import { InlineChromiumBugfix, updateModel } from 'components/editing/elements/utils';
import { HoverContainer } from 'components/editing/toolbar/HoverContainer';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { CommandButton } from 'components/editing/toolbar/buttons/CommandButton';
import { Modal } from 'components/modal/Modal';
import { modalActions } from 'actions/modal';
import * as ContentModel from 'data/content/model/elements/types';
import { configureStore } from 'state/store';
import { createButtonCommandDesc } from '../commands/commandFactories';

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
          <Modal
            title="Bibliography"
            onCancel={onCancel}
            onOk={() => onDone({ ...selected })}
            disableOk={false}
          >
            <CitationEditor
              commandContext={props.commandContext}
              model={props.model}
              onSelectionChange={(selection: ContentModel.Citation) => {
                selected = selection;
              }}
            />
          </Modal>
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
          <Toolbar context={props.commandContext}>
            <Toolbar.Group>
              <CommandButton
                description={createButtonCommandDesc({
                  icon: <i className="fa-solid fa-pencil"></i>,
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
