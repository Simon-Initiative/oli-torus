import React, { useCallback } from 'react';
import { useEditModelCallback } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { useElementSelected } from '../../../../data/content/utils';
import { EditorProps } from 'components/editing/elements/interfaces';
import { HoverContainer } from '../../toolbar/HoverContainer';
import { Toolbar } from '../../toolbar/Toolbar';
import { CommandButton } from '../../toolbar/buttons/CommandButton';
import { createButtonCommandDesc } from '../commands/commandFactories';
import { ForeignModal } from './ForeignModal';
import { modalActions } from '../../../../actions/modal';

interface Props extends EditorProps<ContentModel.Foreign> {}

const dismiss = () => window.oliDispatch(modalActions.dismiss());
const display = (c: any) => window.oliDispatch(modalActions.display(c));

export const ForeignEditor = (props: Props) => {
  const onEdit = useEditModelCallback(props.model);
  const selected = useElementSelected();

  const onModalDone = useCallback(
    (changes: Partial<ContentModel.Foreign>) => {
      // The modal will pass back an empty string for project default, but we want to
      // remove the attribute instead of have an empty string in that case.
      const lang = changes.lang === '' ? undefined : changes.lang;
      onEdit({
        ...props.model,
        ...changes,
        lang,
      });
      dismiss();
    },
    [onEdit, props.model],
  );

  const onChangeLang = useCallback(
    () =>
      display(
        <ForeignModal
          commandContext={props.commandContext}
          model={props.model}
          onDone={onModalDone}
          onCancel={dismiss}
        />,
      ),
    [onModalDone, props.commandContext, props.model],
  );

  return (
    <HoverContainer
      position="bottom"
      align="start"
      isOpen={selected}
      content={
        <Toolbar context={props.commandContext}>
          <Toolbar.Group>
            <CommandButton
              description={createButtonCommandDesc({
                icon: <i className="fa-solid fa-pencil"></i>,
                description: 'Change Language',
                execute: onChangeLang,
              })}
            />
          </Toolbar.Group>
        </Toolbar>
      }
    >
      <span className="foreign-editor" lang={props.model.lang} {...props.attributes}>
        {props.children}
      </span>
    </HoverContainer>
  );
};
