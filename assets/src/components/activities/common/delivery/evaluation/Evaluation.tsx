import React from 'react';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import { WriterContext } from 'data/content/writers/context';
import { ActivityState, makeContent, makeFeedback } from 'components/activities/types';

interface Props {
  shouldShow?: boolean;
  attemptState: ActivityState;
  context: WriterContext;
}
export const Evaluation: React.FC<Props> = ({ shouldShow = true, attemptState, context }) => {
  if (!shouldShow) {
    return null;
  }
  const { score, outOf, parts } = attemptState;
  const error = parts[0].error;
  const feedback = parts[0].feedback?.content;

  const errorText = makeContent('There was an error processing this response');

  let resultClass = 'incorrect';
  if (error !== undefined && error !== null) {
    resultClass = 'error';
  } else if (score === outOf) {
    resultClass = 'correct';
  } else if ((score as number) > 0) {
    resultClass = 'incorrect';
  }

  return (
    <div aria-label="result" className={`evaluation feedback ${resultClass} my-1`}>
      <div className="result">
        <span aria-label="score" className="score">
          {score}
        </span>
        <span className="result-divider">/</span>
        <span aria-label="out of" className="out-of">
          {outOf}
        </span>
      </div>
      <HtmlContentModelRenderer
        text={error ? errorText.content : feedback ? feedback : makeFeedback('').content}
        context={context}
      />
    </div>
  );
};
