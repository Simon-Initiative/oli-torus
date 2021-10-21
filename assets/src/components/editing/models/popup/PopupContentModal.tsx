import { RichTextEditor } from 'components/content/RichTextEditor';
import { CommandContext } from 'components/editing/commands/interfaces';
import { FullScreenModal } from 'components/editing/toolbars/FullScreenModal';
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
  const [trigger, setTrigger] = React.useState(props.model.trigger);

  const isTriggerMode = (mode: ContentModel.PopupTriggerMode) => mode === trigger;

  const triggerSettings = (
    <form onSubmit={() => {}} id="popup__trigger_mode">
      <div className="form-check form-switch">
        <div className="form-group">
          <label className="form-check-label">
            <input
              type="radio"
              className="form-check-input"
              onChange={() => setTrigger('hover')}
              checked={isTriggerMode('hover')}
            />
            <p>Trigger on mouseover</p>
            <small>
              Students on desktop computers will see this content when they hover over the popup
              with their mouse. Students on mobile must press. Good for shorter content.
            </small>
          </label>
        </div>
        <div className="form-group">
          <label className="form-check-label">
            <input
              type="radio"
              className="form-check-input"
              onChange={() => setTrigger('click')}
              checked={isTriggerMode('click')}
            />
            <p>Trigger on click</p>
            <small>
              All students must click the popup to see this content. Good for longer content or
              including audio, videos.
            </small>
          </label>
        </div>
      </div>
    </form>
  );

  return (
    <FullScreenModal
      onCancel={(_e) => props.onCancel()}
      onDone={(newModel) => props.onDone(Object.assign(props.model, newModel))}
    >
      <div className="row">
        <div className="col-12">
          <h3 className="mb-2">Popup Content</h3>
          <p className="mb-4">Shown to students when the popup is active</p>
          <div className="popup__modal-content">
            {triggerSettings}
            <RichTextEditor
              editMode={true}
              text={content}
              projectSlug={props.commandContext.projectSlug}
              onEdit={(content) => setContent(content)}
            />
          </div>
        </div>
      </div>
    </FullScreenModal>
  );
};
