import { Transforms, Editor, Element } from 'slate';
import {
  Command,
  CommandContext,
  CommandDescription,
} from 'components/editing/elements/commands/interfaces';
import { isActive } from '../../slateUtils';
import React from 'react';
import { configureStore } from 'state/store';
import { modalActions } from 'actions/modal';
import { CitationEditor } from './CitationEditor';
import { Modal } from 'components/modal/Modal';
import { Provider } from 'react-redux';
import * as ContentModel from 'data/content/model/elements/types';

const dismiss = () => window.oliDispatch(modalActions.dismiss());
const display = (c: any) => window.oliDispatch(modalActions.display(c));
const store = configureStore();

export function selectCitation(
  context: CommandContext,
  model?: ContentModel.Citation,
): Promise<ContentModel.Citation> {
  return new Promise((resolve, _reject) => {
    let selected = model;

    const mediaLibrary = (
      <Provider store={store}>
        <Modal
          title="Select citation"
          onOk={() => {
            dismiss();
            if (selected) resolve(selected);
          }}
          onCancel={() => dismiss()}
        >
          <CitationEditor
            commandContext={context}
            onSelectionChange={(selection: ContentModel.Citation) => {
              selected = selection;
            }}
          />
        </Modal>
      </Provider>
    );

    display(mediaLibrary);
  });
}

const command: Command = {
  execute: (context, editor, _params) => {
    const selection = editor.selection;
    if (!selection) return;

    const at = editor.selection as any;
    selectCitation(context).then((citation) => Transforms.insertNodes(editor, citation, { at }));
  },
  precondition: (editor) => {
    return !isActive(editor, ['code']);
  },
};

export const citationCmdDesc: CommandDescription = {
  type: 'CommandDesc',
  icon: () => <i className="fa-solid fa-book"></i>,
  description: () => 'Cite',
  command,
  active: (e) => isActive(e, 'cite'),
};
