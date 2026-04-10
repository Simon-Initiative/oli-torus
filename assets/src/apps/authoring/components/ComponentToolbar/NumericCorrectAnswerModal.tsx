import React, { useEffect, useMemo, useState } from 'react';
import { Button, Form, Modal } from 'react-bootstrap';
import {
  NumericCorrectAnswer,
  defaultExactCorrectAnswer,
  defaultRangeCorrectAnswer,
} from './numericCorrectAnswerUtils';

interface Props {
  show: boolean;
  partTitle: string;
  partCustom?: Record<string, any>;
  onCancel: () => void;
  onConfirm: (answer: NumericCorrectAnswer) => void;
}

const parseNumberOrUndefined = (value: string) => {
  if (value.trim() === '') return undefined;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
};

const NumericCorrectAnswerModal: React.FC<Props> = ({
  show,
  partTitle,
  partCustom = {},
  onCancel,
  onConfirm,
}) => {
  const initialExact = useMemo(() => defaultExactCorrectAnswer(partCustom), [partCustom]);
  const initialRange = useMemo(() => defaultRangeCorrectAnswer(partCustom), [partCustom]);

  const [useRange, setUseRange] = useState(false);
  const [exactValue, setExactValue] = useState(String(initialExact));
  const [rangeMin, setRangeMin] = useState(String(initialRange.correctMin ?? initialExact));
  const [rangeMax, setRangeMax] = useState(String(initialRange.correctMax ?? initialExact));
  const [validationMessage, setValidationMessage] = useState('');

  useEffect(() => {
    if (!show) return;

    setUseRange(false);
    setExactValue(String(initialExact));
    setRangeMin(String(initialRange.correctMin ?? initialExact));
    setRangeMax(String(initialRange.correctMax ?? initialExact));
    setValidationMessage('');
  }, [initialExact, initialRange, show]);

  const onSave = () => {
    if (useRange) {
      const correctMin = parseNumberOrUndefined(rangeMin);
      const correctMax = parseNumberOrUndefined(rangeMax);

      if (correctMin === undefined || correctMax === undefined) {
        setValidationMessage('Enter both minimum and maximum values for the correct range.');
        return;
      }

      if (correctMin > correctMax) {
        setValidationMessage('The correct range minimum cannot be greater than the maximum.');
        return;
      }

      onConfirm({ range: true, correctMin, correctMax });
      return;
    }

    const correctAnswer = parseNumberOrUndefined(exactValue);
    if (correctAnswer === undefined) {
      setValidationMessage('Enter the exact correct value before adding this component.');
      return;
    }

    onConfirm({ range: false, correctAnswer });
  };

  return (
    <Modal show={show} onHide={onCancel} centered={true}>
      <Modal.Header closeButton={true}>
        <Modal.Title>{`Set Correct Answer for ${partTitle}`}</Modal.Title>
      </Modal.Header>
      <Modal.Body>
        <p className="mb-3">
          This adaptive input requires an authored correct answer before it can be placed on the
          screen.
        </p>

        <Form>
          <Form.Group className="mb-3">
            <Form.Check
              type="radio"
              id="numeric-correct-answer-exact"
              name="numeric-correct-answer-mode"
              label="Use one exact correct value"
              checked={!useRange}
              onChange={() => setUseRange(false)}
            />
            <Form.Check
              type="radio"
              id="numeric-correct-answer-range"
              name="numeric-correct-answer-mode"
              label="Use a correct range"
              checked={useRange}
              onChange={() => setUseRange(true)}
            />
          </Form.Group>

          {useRange ? (
            <div className="grid grid-cols-12 gap-3">
              <Form.Group className="col-span-6">
                <Form.Label>Correct range minimum</Form.Label>
                <Form.Control
                  type="number"
                  value={rangeMin}
                  onChange={(e) => setRangeMin(e.target.value)}
                />
              </Form.Group>
              <Form.Group className="col-span-6">
                <Form.Label>Correct range maximum</Form.Label>
                <Form.Control
                  type="number"
                  value={rangeMax}
                  onChange={(e) => setRangeMax(e.target.value)}
                />
              </Form.Group>
            </div>
          ) : (
            <Form.Group>
              <Form.Label>Correct value</Form.Label>
              <Form.Control
                type="number"
                value={exactValue}
                onChange={(e) => setExactValue(e.target.value)}
              />
            </Form.Group>
          )}

          {validationMessage !== '' && (
            <div className="alert alert-danger mt-3 mb-0" role="alert">
              {validationMessage}
            </div>
          )}
        </Form>
      </Modal.Body>
      <Modal.Footer>
        <Button variant="secondary" onClick={onCancel}>
          Cancel
        </Button>
        <Button variant="primary" onClick={onSave}>
          Add Component
        </Button>
      </Modal.Footer>
    </Modal>
  );
};

export default NumericCorrectAnswerModal;
