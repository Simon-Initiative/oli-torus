import React from 'react';
import { ActivityState, PartState, makeContent, makeFeedback } from 'components/activities/types';
import { WriterContext } from 'data/content/writers/context';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import { isDefined } from 'utils/common';

interface Props {
  shouldShow?: boolean;
  attemptState: ActivityState;
  context: WriterContext;
  partOrder?: string[];
}

export function renderPartFeedback(partState: PartState, context: WriterContext) {
  if (!partState.score && !partState.outOf) {
    return null;
  }
  const errorText = makeContent('There was an error processing this response');
  const error = partState.error;
  const feedback = partState.feedback?.content;
  const feedbackDirection = partState.feedback?.textDirection || 'ltr';
  const resultCl = resultClass(partState.score, partState.outOf, partState.error);
  const explanation = partState.explanation?.content;
  const explanationDirection = partState.explanation?.textDirection || 'ltr';

  return (
    <React.Fragment>
      <Component
        key={`${partState.partId}-feedback`}
        resultClass={resultCl}
        score={partState.score}
        outOf={partState.outOf}
        graded={context.graded}
      >
        <HtmlContentModelRenderer
          content={error ? errorText.content : feedback ? feedback : makeFeedback('').content}
          context={context}
          direction={feedbackDirection}
        />
      </Component>
      {explanation && resultCl !== 'correct' && (
        <Component
          key={`${partState.partId}-explanation`}
          resultClass="explanation"
          graded={context.graded}
        >
          <div>
            <div className="mb-1">
              <b>Explanation:</b>
            </div>
            <div>
              <HtmlContentModelRenderer
                direction={explanationDirection}
                content={explanation}
                context={context}
              />
            </div>
          </div>
        </Component>
      )}
    </React.Fragment>
  );
}

export const Evaluation: React.FC<Props> = ({
  shouldShow = true,
  attemptState,
  context,
  partOrder,
}) => {
  const { parts } = attemptState;
  if (!shouldShow) {
    return null;
  }

  if (parts.length === 1) {
    return renderPartFeedback(parts[0], context);
  }

  // part order for migrated multi-inputs may be random, so allow caller to specify appropriate one
  let orderedParts = parts;
  if (partOrder) {
    const newOrder = partOrder.map((id) => parts.find((ps) => ps.partId === id)).filter(isDefined);
    if (newOrder.length === parts.length) orderedParts = newOrder;
  }

  return <>{orderedParts.map((partState) => renderPartFeedback(partState, context))}</>;
};

interface ComponentProps {
  resultClass: string;
  score?: number | null;
  outOf?: number | null;
  graded?: boolean;
}

const Component: React.FC<ComponentProps> = (props) => {
  const graphic = <div className="mr-2">{graphicForResultClass(props.resultClass)}</div>;

  return (
    <div aria-label="result" className={`evaluation feedback ${props.resultClass} my-1`}>
      {graphic}
      <div className="flex-grow">{props.children}</div>
    </div>
  );
};

const graphicForResultClass = (resultClass: string) => {
  if (resultClass === 'correct') {
    return <i className="fa-solid fa-circle-check"></i>;
  }
  if (resultClass === 'incorrect') {
    return <i className="fa-solid fa-circle-xmark"></i>;
  }
  if (resultClass === 'partially-correct') {
    return <i className="fa-regular fa-circle-check"></i>;
  }

  return <i className="fa-solid fa-circle-exclamation"></i>;
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
