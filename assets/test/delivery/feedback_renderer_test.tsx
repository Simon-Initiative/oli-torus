import React from 'react';
import '@testing-library/jest-dom';
import { render, screen } from '@testing-library/react';
import FeedbackRenderer from 'apps/delivery/layouts/deck/components/FeedbackRenderer';

describe('FeedbackRenderer', () => {
  it('renders a loading state while AI feedback is pending', () => {
    render(<FeedbackRenderer feedbacks={[]} pending={true} snapshot={{}} />);

    const pendingStatus = screen.getByRole('status', { name: 'AI-generated feedback is loading' });

    expect(pendingStatus).toBeInTheDocument();
    expect(pendingStatus).toHaveAttribute('tabindex', '-1');
    expect(screen.getByText('AI-generated')).toBeInTheDocument();
    expect(screen.getByText('Generating AI-generated feedback...')).toBeInTheDocument();
  });

  it('hides stale feedback content while AI feedback is still pending', () => {
    render(
      <FeedbackRenderer
        feedbacks={[{ ai_generated: true, text: 'Previous feedback should stay hidden.' }]}
        pending={true}
        snapshot={{}}
      />,
    );

    expect(
      screen.getByRole('status', { name: 'AI-generated feedback is loading' }),
    ).toBeInTheDocument();
    expect(screen.queryByText('Previous feedback should stay hidden.')).not.toBeInTheDocument();
  });

  it('renders AI-generated feedback text when available', () => {
    render(
      <FeedbackRenderer
        feedbacks={[{ ai_generated: true, text: 'Try comparing the slope between the two lines.' }]}
        snapshot={{}}
      />,
    );

    expect(screen.getByLabelText('AI-generated feedback')).toHaveAttribute('tabindex', '-1');
    expect(screen.getByText('Try comparing the slope between the two lines.')).toBeInTheDocument();
  });

  it('renders an inline retry message when feedback loading fails', () => {
    render(
      <FeedbackRenderer
        feedbacks={[{ system_error: true, text: 'We could not load feedback. Please try again.' }]}
        snapshot={{}}
      />,
    );

    expect(screen.getByRole('alert', { name: 'Feedback could not be loaded' })).toBeInTheDocument();
    expect(screen.getByText('We could not load feedback. Please try again.')).toBeInTheDocument();
  });
});
