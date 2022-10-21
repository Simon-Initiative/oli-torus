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
  const explanation = partState.explanation?.content;

  return (
    <React.Fragment>
      <Component
        key={`${partState.partId}-feedback`}
        resultClass={resultClass(partState.score, partState.outOf, partState.error)}
        score={partState.score}
        outOf={partState.outOf}
        graded={context.graded}
      >
        <HtmlContentModelRenderer
          content={error ? errorText.content : feedback ? feedback : makeFeedback('').content}
          context={context}
        />
      </Component>
      {explanation && (
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
              <HtmlContentModelRenderer content={explanation} context={context} />
            </div>
          </div>
        </Component>
      )}
    </React.Fragment>
  );
}

export const Evaluation: React.FC<Props> = ({ shouldShow = true, attemptState, context }) => {
  const { score, outOf, parts } = attemptState;
  if (!shouldShow) {
    return null;
  }

  if (parts.length === 1) {
    return renderPartFeedback(parts[0], context);
  }

  return (
    <>
      <Component
        resultClass={resultClass(score, outOf, undefined)}
        score={score}
        outOf={outOf}
        graded={context.graded}
      ></Component>
      {parts.map((partState) => renderPartFeedback(partState, context))}
    </>
  );
};

interface ComponentProps {
  resultClass: string;
  score?: number | null;
  outOf?: number | null;
  graded?: boolean;
}
const Component: React.FC<ComponentProps> = (props) => {
  const scoreOrGraphic = props.graded
    ? (props.score || props.outOf) && (
        <div className="result">
          <span aria-label="score" className="score">
            {props.score}
          </span>
          <span className="result-divider">/</span>
          <span aria-label="out of" className="out-of">
            {props.outOf}
          </span>
        </div>
      )
    : graphicForResultClass(props.resultClass);

  return (
    <div aria-label="result" className={`evaluation feedback ${props.resultClass} my-1`}>
      {scoreOrGraphic}
      {props.children}
      <div></div>
    </div>
  );
};

const graphicForResultClass = (resultClass: string) => {
  if (resultClass === 'correct') {
    return <span className="icon_30H-hYww material-icons mr-2">check_circle</span>;
  }
  if (resultClass === 'incorrect') {
    return <span className="icon_30H-hYww material-icons mr-2">cancel</span>;
  }
  if (resultClass === 'partially-correct') {
    return <span className="icon_30H-hYww material-icons mr-2">check</span>;
  }

  return <span className="icon_30H-hYww material-icons mr-2">error</span>;
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
