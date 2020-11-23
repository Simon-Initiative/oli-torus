import React from 'react';
import { Heading } from 'components/misc/Heading';
import { RichTextEditor } from 'components/content/RichTextEditor';
import { ModelEditorProps } from '../schema';
import { ResponseId, RichText } from '../../types';
import { Description } from 'components/misc/Description';
import { IconCorrect, IconIncorrect } from 'components/misc/Icons';
import { ProjectSlug } from 'data/types';
import { classNames } from 'utils/classNames';
import { getCorrectResponse, getIncorrectResponse } from '../utils';

interface FeedbackProps extends ModelEditorProps {
  onEditResponseFeedback: (responseId: ResponseId, content: RichText) => void;
  projectSlug: ProjectSlug;
}
export const Feedback = (props: FeedbackProps) => {
  const { onEditResponseFeedback, model, editMode, projectSlug } = props;

  return (
    <div className={'my-5 ' + classNames(['feedback'])}>
      <Heading title="Answer Choice Feedback" subtitle="Providing feedback when a student answers a
        question is one of the best ways to reinforce their understanding." id="feedback" />
      <div className="mb-3" key={'correct feedback'}>
        <Description>
          <IconCorrect /> Feedback for Correct Answer
        </Description>
        <RichTextEditor projectSlug={projectSlug}
          editMode={editMode} text={getCorrectResponse(model).feedback.content}
          onEdit={content => onEditResponseFeedback(getCorrectResponse(model).id, content)}
        />
      </div>
      <div className="mb-3" key={'incorrect feedback'}></div>
        <Description>
          <IconIncorrect /> Feedback for Incorrect Answer
        </Description>
        <RichTextEditor projectSlug={projectSlug}
          editMode={editMode} text={getIncorrectResponse(model).feedback.content}
          onEdit={content => onEditResponseFeedback(getIncorrectResponse(model).id, content)}
        />
      </div>
  );
};
