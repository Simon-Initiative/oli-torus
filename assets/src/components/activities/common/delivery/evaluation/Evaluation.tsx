import {
  ActivityState,
  makeContent,
  makeFeedback,
  RichText,
  PartState,
} from 'components/activities/types';
import { WriterContext } from 'data/content/writers/context';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import React from 'react';
import guid from 'utils/guid';

interface Props {
  shouldShow?: boolean;
  attemptState: ActivityState;
  context: WriterContext;
}

export function renderPartFeedback(partState: PartState, context: WriterContext) {
  if (!partState.score && !partState.outOf) {
    return null;
  }
  const errorText = makeContent('There was an error processing this response');
  const error = partState.error;
  const feedback = partState.feedback?.content;
  return (
    <Component
      key={partState.partId}
      resultClass={resultClass(partState.score, partState.outOf, partState.error)}
      score={partState.score}
      outOf={partState.outOf}
    >
      <HtmlContentModelRenderer
        content={error ? errorText.content : feedback ? feedback : makeFeedback('').content}
        context={context}
      />
    </Component>
  );
}

export const Evaluation: React.FC<Props> = ({ shouldShow = true, attemptState, context }) => {
  const { score, outOf, parts } = attemptState;
  if (!shouldShow || outOf === null || score === null) {
    return null;
  }

  if (parts.length === 1) {
    return renderPartFeedback(parts[0], context);
  }

  const totalScoreText: RichText = [
    {
      type: 'p',
      children: [{ text: 'Total Score', strong: true }],
      id: guid(),
    },
  ];

  return (
    <>
      <Component resultClass={resultClass(score, outOf, undefined)} score={score} outOf={outOf}>
        <HtmlContentModelRenderer content={totalScoreText} context={context} />
      </Component>
      {parts.map((partState) => renderPartFeedback(partState, context))}
    </>
  );
};

interface ComponentProps {
  resultClass: string;
  score: number | null;
  outOf: number | null;
}
const Component: React.FC<ComponentProps> = (props) => {
  return (
    <div aria-label="result" className={`evaluation feedback ${props.resultClass} my-1`}>
      <div className="result">
        <span aria-label="score" className="score">
          {props.score}
        </span>
        <span className="result-divider">/</span>
        <span aria-label="out of" className="out-of">
          {props.outOf}
        </span>
      </div>
      {props.children}
    </div>
  );
};

const resultClass = (score: number | null, outOf: number | null, error: string | undefined) => {
  if (typeof error === 'string' || outOf === null || score === null) {
    return 'error';
  }
  if (score === outOf) {
    return 'correct';
  }
  if (score === 0) {
    return 'incorrect';
  }
  if (score > 0) {
    return 'partially-correct';
  }
  return '';
};
