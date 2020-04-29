import React, { ChangeEvent } from 'react';
import ReactDOM from 'react-dom';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { MultipleChoiceModelSchema, Choice, Feedback, Hint, Stem } from './schema';
import { RichText } from 'components/activities/multiple_choice/schema';
import * as ActivityTypes from '../types';
import { getToolbarForResourceType } from 'components/resource/toolbar';
import { Editor } from 'components/editor/Editor';
import { fromText, feedback as makeFeedback } from './authoring-entry';

type ModelSliceEditorProps = {
  editMode: boolean;
  text: RichText;
  onEdit: (text: RichText) => void;
};
const ModelSliceEditor = ({ editMode, text, onEdit }: ModelSliceEditorProps) => {
  return (
    <div style={{
      border: '1px solid #e5e5e5',
      borderRadius: '2px',
      color: '#666',
      padding: '10px',
      fontFamily: 'Inter',
      fontSize: '11px',
    }}>
      <Editor
        editMode={editMode}
        value={text}
        onEdit={(value) => {
          console.log(value)
          onEdit(value);
        }}
        toolbarItems={getToolbarForResourceType(1)}
      />
    </div>
  );
};

const questionTypes = [
  { value: 'mc', displayValue: 'Multiple Choice' },
  { value: 'sa', displayValue: 'Short Answer' },
];

type OptionsProps = {
  options: { value: string, displayValue: string}[];
  editMode: boolean;
};
const QuestionTypeDropdown = ({ options }: OptionsProps) => {
  const onChange = (v: ChangeEvent<HTMLSelectElement>) => null;

  return (
    <div>
      <label htmlFor="question-type">Question Type</label>
      <select
        style={{ width: '200px' }}
        disabled
        className="form-control"
        value="mc"
        onChange={onChange}
        name="question-type"
        id="question-type">
        {options.map(option => (
          <option
            key={option.value}
            value={option.value}>
            {option.displayValue}
          </option>
        ))}
      </select>
    </div>
  );
};

type StemProps = {
  stem: Stem;
  onEdit: (modelSlice: ModelSlice) => void;
  editMode: boolean;
};
const Stem = ({ stem, onEdit, editMode }: StemProps) => {
  const onStemEdit = (content: RichText) => {
    onEdit({
      stem: Object.assign({}, stem, { content }),
    });
  };

  return (
    <div style={{ margin: '2rem 0' }}>
      <h5>Stem</h5>
      <small>If students have learned the skills you're targeting,
        they should be able to answer this question:
      </small>
      <ModelSliceEditor
        editMode={editMode}
        text={stem.content}
        onEdit={onStemEdit}
      />
    </div>
  );
};

type ChoicesProps = {
  editMode: boolean;
  onEdit: (modelSlice: ModelSlice) => void;
  choices: Choice[],
  feedback: Feedback[],
};
const Choices = ({ onEdit, editMode, choices, feedback }: ChoicesProps) => {
  const isCorrect = (feedback: Feedback) => feedback.score === 1;

  const correctChoice = choices.reduce((correct, choice) => {
    const feedbackMatchesChoice = (feedback: Feedback, choice: Choice) =>
      feedback.match === choice.id;
    if (correct) return correct;
    if (feedback.find(feedback =>
      feedbackMatchesChoice(feedback, choice) && isCorrect(feedback))) return choice;
    throw new Error('Correct choice could not be found:' + JSON.stringify(choices));
  });

  const incorrectChoices = choices.filter(choice => choice.id !== correctChoice.id);

  const onChoiceEdit = (content: RichText, id: number) => {
    onEdit({
      choices: choices.map((choice) => {
        if (choice.id !== id) return choice;
        return Object.assign({}, choice, { content }) as Choice;
      }),
    });
  };

  const onAddChoice = () => {
    const newChoice: Choice = fromText('');
    const newFeedback: Feedback = makeFeedback('', newChoice.id, 0);

    onEdit({
      choices: choices.concat(newChoice),
      authoring: {
        feedback: feedback.concat(newFeedback),
      },
    });
  };

  const onRemoveChoice = (id: number) => {
    // Prevent removing correct answer choice
    if (id === correctChoice.id) return;

    onEdit({
      choices: choices.filter(choice => choice.id !== id),
      authoring: {
        feedback: feedback.filter(feedback => feedback.match !== id),
      },
    });
  };

  return (
    <div style={{ margin: '2rem 0' }}>
      <h5>Answer Choices</h5>
      <small>One correct answer choice and as many incorrect answer choices as you like.</small>
      <div key={correctChoice.id}>
          <div>
            <i style={{ color: '#55C273' }} className="material-icons-outlined icon">done</i>
            Correct answer
          </div>
          <ModelSliceEditor
            editMode={editMode}
            text={correctChoice.content}
            onEdit={(text: RichText) => onChoiceEdit(text, correctChoice.id)}
          />
        </div>
      {incorrectChoices.map((choice, index) => (
        <div key={choice.id}>
          <div>
            <button
              type="button"
              className="close"
              aria-label="Close"
              onClick={e => onRemoveChoice(choice.id)}
              style={{ float: 'left' }}
            >
              <i className="material-icons-outlined icon">close</i>
            </button>
            Common Misconception {index + 1}
          </div>
          <ModelSliceEditor
            editMode={editMode}
            text={choice.content}
            onEdit={(text: RichText) => onChoiceEdit(text, choice.id)}
          />
        </div>
      ))}
      <button
        disabled={!editMode}
        onClick={e => onAddChoice()}
        className="btn btn-primary">Add incorrect answer choice
      </button>
    </div>
  );
};

type FeedbackProps = {
  feedback: Feedback[],
  onEdit: (modelSlice: ModelSlice) => void;
  editMode: boolean;
};
const Feedback = ({ feedback, onEdit, editMode }: FeedbackProps) => {
  const isCorrect = (feedback: Feedback) => feedback.score === 1;
  const correctFeedback = feedback.find(isCorrect);
  if (!correctFeedback) {
    throw new Error('Correct feedback could not be found:' + JSON.stringify(feedback));
  }
  const incorrectFeedback = feedback.filter(feedback => feedback.id !== correctFeedback.id);


  const onFeedbackEdit = (content: RichText, id: number) => {
    onEdit({
      authoring: {
        feedback: feedback.map((feedback) => {
          if (feedback.id !== id) return feedback;
          return Object.assign({}, feedback, { content }) as Feedback;
        }),
      },
    });
  };

  return (
    <div style={{ margin: '2rem 0' }}>
      <h5>Answer Choice Feedback</h5>
      <small>Providing feedback when a student answers a
        question is one of the best ways to reinforce their understanding.
      </small>
      <div key={correctFeedback.id}>
        <div>
          <i style={{ color: '#55C273' }} className="material-icons-outlined icon">done</i>
          Feedback for Correct answer
        </div>
        <ModelSliceEditor
          editMode={editMode}
          text={correctFeedback.content}
          onEdit={(text: RichText) => onFeedbackEdit(text, correctFeedback.id)}
        />
      </div>
      {incorrectFeedback.map((feedback, index) => (
        <div key={feedback.id}>
          <div>
            Feedback for Common Misconception {index + 1}
          </div>
          <ModelSliceEditor
            editMode={editMode}
            text={feedback.content}
            onEdit={(text: RichText) => onFeedbackEdit(text, feedback.id)}
          />
        </div>
      ))}
    </div>
  );
};

type HintsProps = {
  hints: Hint[],
  onEdit: (modelSlice: ModelSlice) => void;
  editMode: boolean;
};
const Hints = ({ hints, onEdit, editMode }: HintsProps) => {
  const deerInHeadlightsHint = hints[0];
  const bottomOutHint = hints[hints.length - 1];
  const cognitiveHints = hints.slice(1, hints.length - 1);

  const onHintEdit = (content: RichText, id: number) => {
    console.log('content', content, id)
    onEdit({
      authoring: {
        hints: hints.map((hint) => {
          if (hint.id !== id) return hint;
          return Object.assign({}, hint, { content }) as Hint;
        }),
      },
    });
  };

  const onRemoveHint = (id: number) => {
    // only cognitive hints after the first can be removed.
    if (hints.length <= 3) return;
    const hintIndex = hints.findIndex(hint => hint.id === id);
    const isValidIndex = hintIndex > 1 && hintIndex < hints.length - 1;
    if (!isValidIndex) return;

    onEdit({
      authoring: {
        hints: hints.filter(hint => hint.id !== id),
      },
    });
  };

  const onAddHint = () => {
    const newHint: Hint = fromText('');

    // new hints are always cognitive hints. they should be inserted
    // right before the bottomOut hint at the end of the list
    const bottomOutIndex = hints.length - 1;

    onEdit({
      authoring: {
        hints: hints.slice(0, bottomOutIndex).concat(newHint).concat(hints[bottomOutIndex]),
      },
    });
  };

  return (
    <div style={{ margin: '2rem 0' }}>
      <h5>Hints</h5>
      <small>
        The best hints follow a pattern:
      </small>

      <div>
        <div>
          "Deer in headlights" hint - restate the problem for students who are totally confused
        </div>
        <ModelSliceEditor
          editMode={editMode}
          text={deerInHeadlightsHint.content}
          onEdit={(text: RichText) => onHintEdit(text, deerInHeadlightsHint.id)}
        />
      </div>

      <div>
        One or more "Cognitive" hints - explain how to solve the problem
      </div>
      {cognitiveHints.map((hint, index) => (
        <div key={hint.id}>
          {index > 0 ?
            <button
              type="button"
              className="close"
              aria-label="Close"
              onClick={e => onRemoveHint(hint.id)}
              style={{ float: 'left' }}
            >
              <i className="material-icons-outlined icon">close</i>
            </button>
            : null
          }
          <ModelSliceEditor
            editMode={editMode}
            text={hint.content}
            onEdit={(text: RichText) => onHintEdit(text, hint.id)}
          />
        </div>
      ))}
      <button
        disabled={!editMode}
        onClick={e => onAddHint()}
        className="btn btn-primary">
          Add cognitive hint
      </button>

      <div>
        <div>
          "Bottom out" hint - explain the answer for students who are still lost
        </div>
        <ModelSliceEditor
          editMode={editMode}
          text={bottomOutHint.content}
          onEdit={(text: RichText) => onHintEdit(text, bottomOutHint.id)}
        />
      </div>
    </div>
  );
};

type ModelSlice = Partial<MultipleChoiceModelSchema> |
  { authoring: Partial<MultipleChoiceModelSchema['authoring']> }
  | Partial<MultipleChoiceModelSchema> &
  { authoring: Partial<MultipleChoiceModelSchema['authoring']> };

const MultipleChoice = (props: AuthoringElementProps<MultipleChoiceModelSchema>) => {
  console.log('model', props.model)
  console.log('props.editmode', props.editMode)

  const onModelEdit = (modelSlice: ModelSlice) => {
    let authoringSlice;

    function hasAuthoringKey(slice: ModelSlice): slice is { authoring: any } {
      return (slice as Partial<MultipleChoiceModelSchema>).authoring !== undefined;
    }

    if (!props.editMode) return;

    // convert all this junk to immer....

    if (hasAuthoringKey(modelSlice)) {
      authoringSlice = Object.assign({}, props.model.authoring, modelSlice.authoring);
    }

    const nonAuthoringSlice = Object.entries(modelSlice)
      .filter(([k, v]) => k !== 'authoring')
      .reduce((acc, [k, v]) => {
        acc[k] = v;
        return acc;
      }, {} as any);
    const newModel = Object.assign({}, props.model,
      { authoring: authoringSlice }, nonAuthoringSlice);

    console.log('newModel', newModel)
    props.onEdit(newModel);
  };

  const { choices, stem, authoring: { feedback, hints } } = props.model;

  const commonProps = {
    onEdit: onModelEdit,
    editMode: props.editMode,
  };

  return (
    <div className="card">
      <div className="card-body" style={{ padding: '2rem' }}>
        <QuestionTypeDropdown
          {...commonProps}
          options={questionTypes}
        />
        <Stem
          {...commonProps}
          stem={stem}
        />
        <Choices
          {...commonProps}
          choices={choices}
          feedback={feedback}
        />
        <Feedback
          {...commonProps}
          feedback={feedback}
        />
        <Hints
          {...commonProps}
          hints={hints}
        />
      </div>
    </div>
  );
};

export class MultipleChoiceAuthoring extends AuthoringElement<MultipleChoiceModelSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<MultipleChoiceModelSchema>) {
    ReactDOM.render(<MultipleChoice {...props} />, mountPoint);
  }
}

const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, MultipleChoiceAuthoring);
