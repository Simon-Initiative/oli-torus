import React from 'react';
import { Heading } from 'components/misc/Heading';
import { RichTextEditor } from 'components/content/RichTextEditor';
import { ModelEditorProps, TargetedCATA } from '../schema';
import { Description } from 'components/misc/Description';
import { IconIncorrect } from 'components/misc/Icons';
import { ProjectSlug } from 'data/types';
import { classNames } from 'utils/classNames';
import { getTargetedResponses } from '../utils';
import { Typeahead } from 'react-bootstrap-typeahead';

interface Props extends ModelEditorProps {
  // onEditResponse: (id: string, content: RichText) => void;
  model: TargetedCATA;
  projectSlug: ProjectSlug;
}
export const TargetedFeedback = ({ model, editMode, projectSlug }: Props) => {

  return (
    <div className={'my-5 ' + classNames(['feedback'])}>
      {getTargetedResponses(model).map((response, index) =>
        <div className="mb-3" key={response.id}>
          <Description>
            <IconIncorrect /> Feedback for
          </Description>
          <RichTextEditor projectSlug={projectSlug}
            key={response.id} editMode={editMode} text={response.feedback.content}
            onEdit={content =>
            (response.id, content)}/>
        </div>)}
    </div>
  );
};
