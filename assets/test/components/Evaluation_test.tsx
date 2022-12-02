import React from 'react';
import { render, screen } from '@testing-library/react';
import { Evaluation } from '../../src/components/activities/common/delivery/evaluation/Evaluation';
import { ActivityState } from '../../src/components/activities';

describe('<Evaluation/>', () => {
  it('Should show explanation on incorrect', () => {
    const attemptState: ActivityState = {
      activityId: 1,
      attemptGuid: 'b',
      attemptNumber: 1,
      dateEvaluated: new Date(),
      dateSubmitted: new Date(),
      score: 0,
      outOf: 1,
      parts: [
        {
          attemptGuid: 'ag',
          attemptNumber: 1,
          dateEvaluated: new Date(),
          dateSubmitted: new Date(),
          score: 0,
          outOf: 1,
          response: 'Boo',
          feedback: null,
          explanation: {
            id: 'E',
            content: [{ type: 'p', id: 'AP', children: [{ text: 'Explanation' }] }],
          },

          hints: [],
          partId: 'PI',
          hasMoreAttempts: false,
          hasMoreHints: false,
        },
      ],
      hasMoreAttempts: true,
      hasMoreHints: false,
      groupId: 'g',
    };
    const context = {};
    render(<Evaluation attemptState={attemptState} context={context} />);
    expect(screen.getByText('Explanation')).toBeInTheDocument();
  });

  it('Should not show explanation on correct', () => {
    const attemptState: ActivityState = {
      activityId: 1,
      attemptGuid: 'b',
      attemptNumber: 1,
      dateEvaluated: new Date(),
      dateSubmitted: new Date(),
      score: 1,
      outOf: 1,
      parts: [
        {
          attemptGuid: 'ag',
          attemptNumber: 1,
          dateEvaluated: new Date(),
          dateSubmitted: new Date(),
          score: 1,
          outOf: 1,
          response: 'Boo',
          feedback: null,
          explanation: {
            id: 'E',
            content: [{ type: 'p', id: 'AP', children: [{ text: 'Explanation' }] }],
          },

          hints: [],
          partId: 'PI',
          hasMoreAttempts: false,
          hasMoreHints: false,
        },
      ],
      hasMoreAttempts: true,
      hasMoreHints: false,
      groupId: 'g',
    };
    const context = {};
    render(<Evaluation attemptState={attemptState} context={context} />);
    expect(screen.queryByText('Explanation')).toBeNull();
  });
});
