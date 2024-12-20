import React from 'react';
import { Button } from 'react-bootstrap';

interface FeedbackItem {
  feedback: string;
  answer: {
    answerType: number;
    correctAnswer?: number | string;
    correctMin?: number | string;
    correctMax?: number | string;
  };
}

interface Props {
  label: string;
  id: string;
  value: FeedbackItem[];
  onChange: (value: FeedbackItem[]) => void;
  onBlur: (id: string, value: FeedbackItem[]) => void;
}
export const AdvancedFeedbackNumberRange: React.FC<Props> = ({ id, value, onChange, onBlur }) => {
  const onControlBlur = () => {
    onBlur(id, value);
  };

  const onAddClick = () => {
    console.log('onAddClick');
    onChange([
      ...value,
      {
        feedback: '',
        answer: {
          answerType: 0,
          correctAnswer: 0,
          correctMax: 0,
          correctMin: 0,
        },
      },
    ]);
  };

  return (
    <div>
      <h2>Advanced Feedback:</h2>

      {value.length === 0 && (
        <div>
          <i>
            Use Advanced Feedback to respond to the learner with targeted feedback on specific
            answers.
          </i>
        </div>
      )}

      {value.map((item, index) => (
        <FeedbackEditor
          key={index}
          onBlur={onControlBlur}
          value={item}
          onRemoveRule={() => onChange(value.filter((v, i) => i !== index))}
          onChange={(newItem) => onChange(value.map((v, i) => (i === index ? newItem : v)))}
          onfocusHandler={() => onBlur('partPropertyElementFocus', [])}
        />
      ))}

      <button className="btn btn-primary mt-3" type="button" onClick={onAddClick}>
        + Add new feedback
      </button>
    </div>
  );
};

const FeedbackEditor: React.FC<{
  value: FeedbackItem;
  onChange: (value: FeedbackItem) => void;
  onBlur: () => void;
  onRemoveRule: () => void;
  onfocusHandler: (changes: boolean) => void;
}> = ({ value, onBlur, onChange, onRemoveRule, onfocusHandler }) => {
  const onFeedbackChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    onChange({ ...value, feedback: e.target.value });
  };

  const onAnswerTypeChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    onChange({
      ...value,
      answer: {
        ...value.answer,
        answerType: parseInt(e.target.value, 10),
      },
    });
  };

  const onCorrectAnswerChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    onChange({
      ...value,
      answer: {
        ...value.answer,
        correctAnswer: e.target.value && parseFloat(e.target.value),
      },
    });
  };

  const onCorrectMinChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    onChange({
      ...value,
      answer: {
        ...value.answer,
        correctMin: e.target.value && parseFloat(e.target.value),
      },
    });
  };

  const onCorrectMaxChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    onChange({
      ...value,
      answer: {
        ...value.answer,
        correctMax: e.target.value && parseFloat(e.target.value),
      },
    });
  };

  const isRange = value.answer.answerType === 1;

  return (
    <div className="advanced-number-feedback">
      <div>
        <div className="rule-top-label">
          <span>When value is:</span>
          <Button variant="link" onClick={onRemoveRule}>
            Remove this rule
          </Button>
        </div>

        <select
          className="form-control"
          value={value.answer.answerType || 0}
          onChange={onAnswerTypeChange}
        >
          <option value="0">Equal to</option>
          <option value="1">Between two values</option>
          <option value="2">Greater Than</option>
          <option value="3">Greater Than or Equal</option>
          <option value="4">Less Than</option>
          <option value="5">Less Than or Equal</option>
        </select>
      </div>
      <div className="grid grid-cols-12 gap-4">
        {isRange && (
          <>
            <div className="col-span-6">
              <input
                className="form-control"
                type="number"
                value={value.answer.correctMin}
                onChange={onCorrectMinChange}
                onBlur={onBlur}
                onFocus={() => onfocusHandler(false)}
              />
            </div>
            <div className="col-span-6">
              <input
                className="form-control"
                type="number"
                value={value.answer.correctMax}
                onChange={onCorrectMaxChange}
                onBlur={onBlur}
                onFocus={() => onfocusHandler(false)}
              />
            </div>
          </>
        )}

        {isRange || (
          <>
            <div className="col-span-6">
              <input
                className="form-control"
                type="number"
                value={value.answer.correctAnswer}
                onChange={onCorrectAnswerChange}
                onBlur={onBlur}
                onFocus={() => onfocusHandler(false)}
              />
            </div>
          </>
        )}

        <div className="col-span-12">
          <label>Feedback</label>
          <input
            className="form-control"
            type="text"
            value={value.feedback}
            onChange={onFeedbackChange}
            onBlur={onBlur}
            onFocus={() => onfocusHandler(false)}
          />
        </div>
      </div>
      <hr />
    </div>
  );
};
