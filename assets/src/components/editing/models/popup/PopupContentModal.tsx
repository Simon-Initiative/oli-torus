import { RichTextEditor } from 'components/content/RichTextEditor';
import { CommandContext } from 'components/editing/commands/interfaces';
import { Modal } from 'components/editing/toolbars/Modal';
import * as ContentModel from 'data/content/model';
import React from 'react';

interface Props {
  onDone: (model: ContentModel.Popup) => void;
  onCancel: () => void;
  model: ContentModel.Popup;
  commandContext: CommandContext;
}
export const PopupContentModal = (props: Props) => {
  const [content, setContent] = React.useState(props.model.content);
  return (
    <Modal
      onCancel={(_e) => props.onCancel()}
      onDone={(newModel) => props.onDone(Object.assign(props.model, newModel))}
    >
      <div>
        <h3 className="mb-2">Content</h3>
        <p className="mb-4">Enter the content</p>
        <div
          className="m-auto"
          style={{
            width: 300,
            height: 200,
            backgroundImage: `url(${props.model.src})`,
            backgroundPosition: '50% 50%',
            backgroundSize: 'contain',
            backgroundRepeat: 'no-repeat',
          }}
        ></div>
        <RichTextEditor
          editMode={true}
          text={content}
          projectSlug={props.commandContext.projectSlug}
          onEdit={(content) => setContent(content)}
        />
      </div>
    </Modal>
  );
};
