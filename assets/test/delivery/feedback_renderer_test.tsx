import React from 'react';
import '@testing-library/jest-dom';
import { render, screen } from '@testing-library/react';
import FeedbackRenderer from 'apps/delivery/layouts/deck/components/FeedbackRenderer';

describe('FeedbackRenderer', () => {
  it('renders a loading state while AI feedback is pending', () => {
    render(<FeedbackRenderer feedbacks={[]} pending={true} snapshot={{}} />);

    expect(
      screen.getByRole('status', { name: 'AI-generated feedback is loading' }),
    ).toBeInTheDocument();
    expect(screen.getByText('AI-generated')).toBeInTheDocument();
    expect(screen.getByText('Generating AI-generated feedback...')).toBeInTheDocument();
  });

  it('renders AI-generated feedback text when available', () => {
    render(
      <FeedbackRenderer
        feedbacks={[{ ai_generated: true, text: 'Try comparing the slope between the two lines.' }]}
        snapshot={{}}
      />,
    );

    expect(screen.getByLabelText('AI-generated feedback')).toBeInTheDocument();
    expect(screen.getByText('Try comparing the slope between the two lines.')).toBeInTheDocument();
  });
});
