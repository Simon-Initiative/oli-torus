import { render, fireEvent, waitFor, screen } from '@testing-library/react';
import '@testing-library/jest-dom/extend-expect';
import React from 'react';
import { defaultState, TestModeHandler } from 'components/resource/TestModeHandler';
import {
  createMatchRule, createRuleForIds, defaultCATAModel, getChoiceIds, getCorrectResponse,
  getHints,
  getIncorrectResponse, getResponseId, getResponses, getTargetedResponses,
  invertRule, unionRules,
} from 'components/activities/check_all_that_apply/utils';
import { Editors } from 'components/resource/editors/Editors';
import { createEditor } from 'components/resource/editors/createEditor';

// TestModeHandler


test('a test', async () => {
  const model = defaultCATAModel();
  const props = {
    model: JSON.stringify(model),
    activitySlug: 'activity-slug',
    state: JSON.stringify(defaultState(model)),
    graded: false,
  };

  render(
    React.createElement(TestModeHandler,
      { model },
      React.createElement('oli-check-all-that-apply-delivery', props)),
  );
  screen.debug();
  console.log(document.querySelector('oli-check-all-that-apply-delivery')?.children)
  expect(document.querySelector('oli-check-all-that-apply-delivery')).toBe(1);
});

// test('loads and displays greeting', async () => {
//   render(<Fetch url="/greeting" />)

//   fireEvent.click(screen.getByText('Load Greeting'))

//   await waitFor(() => screen.getByRole('heading'))

//   expect(screen.getByRole('heading')).toHaveTextContent('hello there')
//   expect(screen.getByRole('button')).toHaveAttribute('disabled')
// })

// test('handles server error', async () => {
//   server.use(
//     rest.get('/greeting', (req, res, ctx) => {
//       return res(ctx.status(500))
//     })
//   )

//   render(<Fetch url="/greeting" />)

//   fireEvent.click(screen.getByText('Load Greeting'))

//   await waitFor(() => screen.getByRole('alert'))

//   expect(screen.getByRole('alert')).toHaveTextContent('Oops, failed to fetch!')
//   expect(screen.getByRole('button')).not.toHaveAttribute('disabled')
// })
