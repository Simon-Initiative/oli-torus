var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import '@testing-library/jest-dom';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { AuthoringElementProvider } from 'components/activities/AuthoringElement';
import { DEFAULT_PART_ID } from 'components/activities/common/utils';
import { MultiInputActions } from 'components/activities/multi_input/actions';
import { MultiInputComponent } from 'components/activities/multi_input/MultiInputAuthoring';
import { addTargetedFeedbackFillInTheBlank } from 'components/activities/multi_input/sections/AnswerKeyTab';
import { defaultModel, multiInputStem } from 'components/activities/multi_input/utils';
import { makeChoice, makeHint, makePart, makeTransformation, Transform, } from 'components/activities/types';
import { Responses } from 'data/activities/model/responses';
import { inputRef } from 'data/content/model/elements/factories';
import React from 'react';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import { Operations } from 'utils/pathOperations';
import { dispatch } from 'utils/test_utils';
import { defaultAuthoringElementProps } from '../utils/activity_mocks';
const input = inputRef();
const choices = [makeChoice('Choice A'), makeChoice('Choice B')];
const _dropdownModel = {
    stem: multiInputStem(input),
    choices,
    inputs: [
        {
            inputType: 'dropdown',
            id: input.id,
            partId: DEFAULT_PART_ID,
            choiceIds: choices.map((c) => c.id),
        },
    ],
    authoring: {
        parts: [makePart(Responses.forMultipleChoice(choices[0].id), [makeHint('')], DEFAULT_PART_ID)],
        targeted: [],
        transformations: [makeTransformation('choices', Transform.shuffle)],
        previewText: 'Example question with a fill in the blank',
    },
};
const _numericModel = {
    stem: multiInputStem(input),
    choices: [],
    inputs: [{ inputType: 'numeric', id: input.id, partId: DEFAULT_PART_ID }],
    authoring: {
        parts: [makePart(Responses.forNumericInput(), [makeHint('')], DEFAULT_PART_ID)],
        targeted: [],
        transformations: [makeTransformation('choices', Transform.shuffle)],
        previewText: 'Example question with a fill in the blank',
    },
};
describe('multi input question - default (with text input)', () => {
    const props = defaultAuthoringElementProps(defaultModel());
    const { model } = props;
    const store = configureStore();
    it('has a stem with an input ref', () => {
        expect(model).toHaveProperty('stem');
    });
    it('has an input', () => {
        expect(model.inputs).toHaveLength(1);
        expect(model.inputs[0]).toHaveProperty('inputType', 'text');
        expect(model.inputs[0]).toHaveProperty('partId', '1');
    });
    it('has a part with text input responses', () => {
        expect(model.authoring.parts).toHaveLength(1);
        const part = model.authoring.parts[0];
        expect(part.responses).toHaveLength(2);
        expect(part.responses[0]).toHaveProperty('score', 1);
        expect(part.responses[0].rule).toMatch(/contains/);
        expect(part.responses[1]).toHaveProperty('score', 0);
        expect(part.responses[1]).toHaveProperty('rule', 'input like {.*}');
    });
    it('has no choices', () => {
        expect(model.choices).toHaveLength(0);
    });
    it('has no targeted responses / mappings', () => {
        expect(model.authoring.targeted).toHaveLength(0);
    });
    it('has preview text', () => {
        expect(model.authoring.previewText).toBeTruthy();
    });
    it('has one hint', () => {
        expect(model.authoring.parts[0].hints).toHaveLength(1);
    });
    it('can add targeted feedback to a text input', () => __awaiter(void 0, void 0, void 0, function* () {
        render(<Provider store={store}>
        <AuthoringElementProvider {...props}>
          <MultiInputComponent />
        </AuthoringElementProvider>
      </Provider>);
        fireEvent.click(screen.getByText('Answer Key'));
        yield screen.findByText('Add targeted feedback');
        fireEvent.click(screen.getByText('Add targeted feedback'));
        const responses = model.authoring.parts[0].responses;
        expect(responses).toHaveLength(3);
        expect(responses[1]).toHaveProperty('rule', 'input contains {another answer}');
        expect(responses[1]).toHaveProperty('score', 0);
    }));
    it('can switch from text to dropdown', () => {
        // add targeted feedback
        const input = model.inputs[0];
        const withTargeted = dispatch(model, addTargetedFeedbackFillInTheBlank(input));
        const updated = dispatch(withTargeted, MultiInputActions.setInputType(input.id, 'dropdown'));
        // choices
        expect(updated.choices).toHaveLength(2);
        const updatedInput = updated.inputs[0];
        expect(updatedInput.inputType).toEqual('dropdown');
        expect(updatedInput.choiceIds).toEqual(updated.choices.map((c) => c.id));
        // responses
        const responses = updated.authoring.parts[0].responses;
        expect(responses).toHaveLength(2);
        expect(responses.map((r) => ({ rule: r.rule, score: r.score }))).toEqual(Responses.forMultipleChoice(updated.choices[0].id).map((r) => ({
            rule: r.rule,
            score: r.score,
        })));
    });
    it('can add a new text input with the add input button', () => __awaiter(void 0, void 0, void 0, function* () {
        render(<Provider store={store}>
        <AuthoringElementProvider {...props}>
          <MultiInputComponent />
        </AuthoringElementProvider>
      </Provider>);
        fireEvent.click(screen.getByText('Add Input'));
        // stem should be updated with new input ref
        yield waitFor(() => {
            const inputRefs = Operations.apply(model, Operations.find('$..children[?(@.type=="input_ref")]'));
            return expect(inputRefs).toHaveLength(2);
        });
        // new part should be added with text input responses
        expect(model.authoring.parts).toHaveLength(2);
        expect(model.authoring.parts[1].responses.map((r) => ({ rule: r.rule, score: r.score }))).toEqual(Responses.forTextInput().map((r) => ({ rule: r.rule, score: r.score })));
        // input should be added as text input
        expect(model.inputs).toHaveLength(2);
        expect(model.inputs[1]).toHaveProperty('inputType', 'text');
    }));
});
//# sourceMappingURL=multi_input_authoring_test.jsx.map