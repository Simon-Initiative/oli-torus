import React from 'react';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import { WriterContext } from 'data/content/writers/context';
import { Card } from 'components/misc/Card';
import { Hint } from 'components/activities/types';

interface Props {
  isEvaluated: boolean;
  hints: Hint[];
  hasMoreHints: boolean;
  context: WriterContext;
  onClick: () => void;
  shouldShow?: boolean;
}

export const HintsDelivery: React.FC<Props> = ({
  isEvaluated,
  hints,
  hasMoreHints,
  context,
  onClick,
  shouldShow = true,
}) => {
  if (!shouldShow) {
    return null;
  }
  // Display nothing if the question has no hints, meaning no hints have been requested so far
  // and there are no more available to be requested
  const noHintsRequested = hints.length === 0;
  if (noHintsRequested && !hasMoreHints) {
    return null;
  }
  return (
    <Card.Card>
      <Card.Title>Hints</Card.Title>
      <Card.Content>
        {hints.map((hint, index) => (
          <div key={hint.id} className="d-flex align-items-center mb-2">
            <span className="mr-2">{index + 1}.</span>
            <HtmlContentModelRenderer text={hint.content} context={context} />
          </div>
        ))}
        {hasMoreHints && (
          <button
            aria-label="request hint"
            onClick={onClick}
            disabled={isEvaluated || !hasMoreHints}
            className="btn btn-sm btn-link"
            style={{ padding: 0 }}
          >
            Request Hint
          </button>
        )}
      </Card.Content>
    </Card.Card>
  );
};
