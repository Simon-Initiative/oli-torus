import React from 'react';
import { Button } from 'react-bootstrap';

interface FeedbackItem {
  feedback: string;
  answer: {
    range: boolean;
    correctAnswer?: number;
    correctMin?: number;
    correctMax?: number;
  };
}

interface Props {
  label: string;
  id: string;
  value: FeedbackItem[];
  onChange: (value: FeedbackItem[]) => void;
  onBlur: (id: string, value: FeedbackItem[]) => void;
}
export const AdvancedFeedbackNumberRange: React.FC<Props> = ({
  label,
  id,
  value,
  onChange,
  onBlur,
}) => {
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
          range: false,
          correctAnswer: 0,
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
        />
      ))}

      <button className="btn btn-primary" type="button" onClick={onAddClick}>
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
}> = ({ value, onBlur, onChange, onRemoveRule }) => {
  const onFeedbackChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    onChange({ ...value, feedback: e.target.value });
  };

  const onRangeChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    onChange({
      ...value,
      answer: {
        ...value.answer,
        range: e.target.value === '1',
      },
    });
  };

  const onCorrectAnswerChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    onChange({
      ...value,
      answer: {
        ...value.answer,
        correctAnswer: parseInt(e.target.value, 10),
      },
    });
  };

  const onCorrectMinChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    onChange({
      ...value,
      answer: {
        ...value.answer,
        correctMin: parseInt(e.target.value, 10),
      },
    });
  };

  const onCorrectMaxChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    onChange({
      ...value,
      answer: {
        ...value.answer,
        correctMax: parseInt(e.target.value, 10),
      },
    });
  };

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
          value={value.answer.range ? '1' : '0'}
          onChange={onRangeChange}
        >
          <option value="0">Equal to</option>
          <option value="1">Between two values</option>

          {/* <option value="2">Greater Than or Equal</option>
          <option value="3">Greater Than</option>
          <option value="4">Less Than or Equal</option>
          <option value="5">Less Than</option> */}
        </select>

        {/* <input type="checkbox" checked={value.answer.range} onChange={onRangeChange} /> */}
      </div>
      <div className="row">
        {value.answer.range && (
          <>
            <div className="col-6">
              <input
                className="form-control"
                type="number"
                value={value.answer.correctMin}
                onChange={onCorrectMinChange}
                onBlur={onBlur}
              />
            </div>
            <div className="col-6">
              <input
                className="form-control"
                type="number"
                value={value.answer.correctMax}
                onChange={onCorrectMaxChange}
                onBlur={onBlur}
              />
            </div>
          </>
        )}

        {value.answer.range || (
          <>
            <div className="col-6">
              <input
                className="form-control"
                type="number"
                value={value.answer.correctAnswer}
                onChange={onCorrectAnswerChange}
                onBlur={onBlur}
              />
            </div>
          </>
        )}

        <div className="col-12">
          <label>Feedback</label>
          <input
            className="form-control"
            type="text"
            value={value.feedback}
            onChange={onFeedbackChange}
            onBlur={onBlur}
          />
        </div>
      </div>
      <hr />
    </div>
  );
};
