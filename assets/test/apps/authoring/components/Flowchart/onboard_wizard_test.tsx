import React from 'react';
import { fireEvent, render, screen } from '@testing-library/react';
import { OnboardWizard } from 'apps/authoring/components/Flowchart/onboard-wizard/OnboardWizard';

describe('OnboardWizard', () => {
  test('keeps the default three-step title screen for standard onboarding', () => {
    render(<OnboardWizard onSetupComplete={jest.fn()} />);

    expect(
      screen.getByRole('heading', { name: '1. Write a title for your lesson' }),
    ).toBeInTheDocument();
    expect(screen.getByText('Step 1/3')).toBeInTheDocument();
  });

  test('uses the compact advanced-author flow when expert mode is preset', () => {
    const onSetupComplete = jest.fn();

    render(
      <OnboardWizard
        onSetupComplete={onSetupComplete}
        initialTitle="New Adaptive Page"
        presetMode="expert"
      />,
    );

    expect(
      screen.getByRole('heading', { name: 'Write a title for your lesson' }),
    ).toBeInTheDocument();
    expect(screen.queryByText('1. Write a title for your lesson')).not.toBeInTheDocument();
    expect(screen.queryByText('Step 1/3')).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: /Next/i }));

    expect(onSetupComplete).toHaveBeenCalledWith('expert', 'New Adaptive Page');
    expect(screen.getByRole('heading', { name: 'Opening in Edit Mode' })).toBeInTheDocument();
  });
});
