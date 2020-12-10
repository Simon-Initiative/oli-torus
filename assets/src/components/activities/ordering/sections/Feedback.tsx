import React, { PropsWithChildren } from 'react';
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
  onToggleFeedbackMode: () => void;
  onEditResponseFeedback: (responseId: ResponseId, content: RichText) => void;
  projectSlug: ProjectSlug;
}
export const Feedback = (props: PropsWithChildren<FeedbackProps>) => {
  const { onEditResponseFeedback, onToggleFeedbackMode, model, editMode, projectSlug } = props;

  return (
    <div className={'mt-5 ' + classNames(['feedback'])}>
      <Heading title="Answer Choice Feedback" subtitle="Providing feedback when a student answers a
        question is one of the best ways to reinforce their understanding." id="feedback" />
      <div className="form-check mb-2">
        <input
          className="form-check-input"
          type="checkbox"
          value=""
          id="targeted-feedback-toggle"
          aria-label="Checkbox for targeted feedback"
          checked={props.model.type === 'TargetedOrdering'}
          onChange={onToggleFeedbackMode}
        />
        <label className="form-check-label" htmlFor="targeted-feedback-toggle">
          Targeted Feedback Mode
        </label>
      </div>
      <div className="mb-3" key={'correct feedback'}>
        <Description>
          <IconCorrect /> Feedback for Correct Answer
        </Description>
        <RichTextEditor projectSlug={projectSlug}
          editMode={editMode} text={getCorrectResponse(model).feedback.content}
          onEdit={content => onEditResponseFeedback(getCorrectResponse(model).id, content)}
        />
      </div>
      {props.children}
      <div className="mb-3" key={'incorrect feedback'}>
        <Description>
          <IconIncorrect /> Catch-all Feedback for Incorrect Answers
        </Description>
        <RichTextEditor projectSlug={projectSlug}
          editMode={editMode} text={getIncorrectResponse(model).feedback.content}
          onEdit={content => onEditResponseFeedback(getIncorrectResponse(model).id, content)}
        />
      </div>
    </div>
  );
};
