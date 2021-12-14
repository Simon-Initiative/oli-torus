var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import { render, fireEvent, screen } from '@testing-library/react';
import React from 'react';
import { defaultDeliveryElementProps } from '../utils/activity_mocks';
import { act } from 'react-dom/test-utils';
import '@testing-library/jest-dom';
import { defaultModel } from 'components/activities/short_answer/utils';
import { ShortAnswerComponent } from 'components/activities/short_answer/ShortAnswerDelivery';
import { makeHint } from 'components/activities/types';
import { configureStore } from 'state/store';
import { activityDeliverySlice } from 'data/activities/DeliveryState';
import { Provider } from 'react-redux';
import { DeliveryElementProvider } from 'components/activities/DeliveryElement';
import { defaultActivityState } from 'data/activities/utils';
describe('multiple choice delivery', () => {
    it('renders ungraded activities correctly', () => __awaiter(void 0, void 0, void 0, function* () {
        const model = defaultModel();
        model.authoring.parts[0].hints.push(makeHint('Hint 1'));
        const props = {
            model,
            activitySlug: 'activity-slug',
            state: Object.assign(defaultActivityState(model), { hasMoreHints: false }),
            graded: false,
            preview: false,
        };
        const { onSaveActivity, onSubmitActivity } = defaultDeliveryElementProps;
        const store = configureStore({}, activityDeliverySlice.reducer);
        render(<Provider store={store}>
        <DeliveryElementProvider {...defaultDeliveryElementProps} {...props}>
          <ShortAnswerComponent />
        </DeliveryElementProvider>
      </Provider>);
        // expect no hints displayed
        expect(screen.queryAllByLabelText(/hint [0-9]/)).toHaveLength(0);
        // expect hints button
        const requestHintButton = screen.getByLabelText('request hint');
        expect(requestHintButton).toBeTruthy();
        // expect clicking request hint to display a hint
        act(() => {
            fireEvent.click(requestHintButton);
        });
        expect(yield screen.findAllByLabelText(/hint [0-9]/)).toHaveLength(1);
        // enter an input, expect it to save
        act(() => {
            fireEvent.change(screen.getByLabelText('answer submission textbox'), {
                target: { value: 'answer' },
            });
        });
        expect(onSaveActivity).toHaveBeenCalledTimes(1);
        // expect a submit button
        const submitButton = screen.getByLabelText('submit');
        expect(submitButton).toBeTruthy();
        // submit and expect a submission
        act(() => {
            fireEvent.click(submitButton);
        });
        expect(onSubmitActivity).toHaveBeenCalledTimes(1);
        expect(onSubmitActivity).toHaveBeenCalledWith(props.state.attemptGuid, [
            {
                attemptGuid: '1',
                response: { input: 'answer' },
            },
        ]);
        // expect results to be displayed after submission
        expect(yield screen.findAllByLabelText('result')).toHaveLength(1);
        expect(screen.getByLabelText('score')).toHaveTextContent('1');
        expect(screen.getByLabelText('out of')).toHaveTextContent('1');
    }));
});
//# sourceMappingURL=short_answer_delivery_test.jsx.map