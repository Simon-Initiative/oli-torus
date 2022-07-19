import React, { useCallback, useState } from 'react';
import { Modal, Button } from 'react-bootstrap';
import { useSelector } from 'react-redux';
import { ObjectivesSelection } from '../../../../../components/resource/objectives/ObjectivesSelection';
import { ObjectivesMap, selectProjectSlug } from '../../../store/app/slice';

interface LearningModalObjectiveProps {
  readonly: boolean;
  handleClose: () => void;
  onChange: (items: number[]) => void;
  currentObjectives: number[];
  objectiveMap: ObjectivesMap;
}
export const LearningObjectivesModal: React.FC<LearningModalObjectiveProps> = ({
  readonly,
  handleClose,
  onChange,
  currentObjectives,
  objectiveMap,
}) => {
  const projectSlug = useSelector(selectProjectSlug);

  return (
    <Modal onHide={handleClose} show={true} size="xl">
      <Modal.Header closeButton>
        <Modal.Title>Objectives editor</Modal.Title>
      </Modal.Header>
      <Modal.Body>
        <ObjectivesSelection
          editMode={!readonly}
          objectives={Object.values(objectiveMap)}
          selected={currentObjectives}
          onEdit={onChange}
          projectSlug={projectSlug}
        />
      </Modal.Body>
      <Modal.Footer>
        <Button variant="primary" onClick={handleClose}>
          Finished
        </Button>
      </Modal.Footer>
    </Modal>
  );
};
