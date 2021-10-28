import { RichText } from 'components/activities/types';
import { RichTextEditor } from 'components/content/RichTextEditor';
import { CommandContext } from 'components/editing/commands/interfaces';
import { FullScreenModal } from 'components/editing/toolbars/FullScreenModal';
import * as ContentModel from 'data/content/model';
import React from 'react';

interface Props {
  onDone: (changes: Partial<ContentModel.Popup>) => void;
  onCancel: () => void;
  model: ContentModel.Popup;
  commandContext: CommandContext;
}
export const PopupContentModal = (props: Props) => {
  const [content, setContent] = React.useState<RichText>({
    model: props.model.content,
    selection: null,
  });
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
              Good for shorter content. Students on desktop computers will see this content when
              they hover over the popup with a mouse. Students on mobile must press.
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
              Good for longer content or including audio, videos. All students must click the popup
              to see this content.
            </small>
          </label>
        </div>
      </div>
    </form>
  );

  return (
    <FullScreenModal
      onCancel={(_e) => props.onCancel()}
      onDone={(_e) => props.onDone({ content: content.model, trigger })}
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
