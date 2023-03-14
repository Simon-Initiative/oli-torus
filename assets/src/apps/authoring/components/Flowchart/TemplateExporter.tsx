import React from 'react';
import { Modal } from 'react-bootstrap';
import { useSelector } from 'react-redux';
import { IActivity, selectAllActivities } from '../../../delivery/store/features/activities/slice';
import { selectSequence } from '../../../delivery/store/features/groups/selectors/deck';
import { Template } from './template-types';

interface Props {
  onToggleExport: () => void;
}

const exportActivity = (id: number, seq: any[], activities: IActivity[]): Template => {
  const sequence = seq.find((s) => s.resourceId === id);
  const { resourceId, custom } = sequence;
  const { layerRef } = custom;
  const parentSequence = seq.find((s) => s.custom.sequenceId === layerRef);
  const activity = activities.find((a) => a.resourceId === resourceId);

  return {
    name: activity?.title || 'Untitled',
    templateType: parentSequence.custom.sequenceName,
    parts: activity?.authoring?.parts || [],
    partsLayout: activity?.content?.partsLayout || [],
  };
};

const preamble = `import { Template } from './template-types';

export const templates: Template[] =`;

export const TemplateExporter: React.FC<Props> = ({ onToggleExport }) => {
  const seq = useSelector(selectSequence);
  const activities = useSelector(selectAllActivities);

  const exp = seq
    .filter((s) => !(s.custom.isLayer || s.custom.isBank))
    .map((s) => exportActivity(s.resourceId, seq, activities));

  const onCopy = () => {
    navigator.clipboard.writeText(preamble + JSON.stringify(exp, null, 2));
  };

  return (
    <Modal show={true} onHide={onToggleExport} style={{ overflow: 'auto' }}>
      <Modal.Header>
        <span className="title">Template Exporter</span>
      </Modal.Header>
      <Modal.Body>
        <button className="btn btn-primary" onClick={onCopy}>
          Copy Templates
        </button>
        <h1>Found templates:</h1>
        <ul>
          {exp.map((e, i) => (
            <li key={i}>
              {e.name} ({e.templateType})
            </li>
          ))}
        </ul>
      </Modal.Body>
      <Modal.Footer></Modal.Footer>
    </Modal>
  );
};
