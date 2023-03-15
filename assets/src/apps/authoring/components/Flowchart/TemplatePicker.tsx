import React, { useCallback, useState } from 'react';
import { Button, Modal } from 'react-bootstrap';
import { screenTypes, screenTypeToTitle } from './screens/screen-factories';
import { Template } from './template-types';

import { templates } from './templates';

interface Props {
  onPick: (template: Template) => void;
  screenType?: string;
}

export const TemplatePicker: React.FC<Props> = ({ onPick, screenType }) => {
  const [selectedTemplate, setSelectedTemplate] = useState<Template | null>(null);
  const [activeScreenType, setActiveScreenType] = useState<string>(screenType || '');

  const onOk = useCallback(() => {
    if (selectedTemplate) {
      onPick(selectedTemplate);
    } else {
      onPick(templates[0]);
    }
  }, [onPick, selectedTemplate]);

  const onScreenType = useCallback(
    (screenType: string) => () => {
      setActiveScreenType((activeScreenType) =>
        screenType === activeScreenType ? '' : screenType,
      );
    },
    [],
  );

  const filterType = useCallback(
    (template: Template) => {
      if (!activeScreenType) {
        return true;
      }
      return template.templateType === activeScreenType;
    },
    [activeScreenType],
  );

  return (
    <Modal show={true} size="xl" scrollable={true} className="template-picker">
      <Modal.Header className="template-picker-header">
        <h1>Choose a template</h1>
        <div className="screen-filter">
          {screenTypes.map((screenType) => (
            <button
              onClick={onScreenType(screenType)}
              key={screenType}
              className={`badge badge-pill ${
                screenType === activeScreenType ? 'badge-primary' : 'badge-light'
              }`}
            >
              {screenTypeToTitle[screenType]}
            </button>
          ))}
        </div>
      </Modal.Header>
      <Modal.Body>
        <div className="picker-list">
          {templates.filter(filterType).map((template, i) => (
            <div
              key={i}
              className={`picker-item ${template === selectedTemplate ? 'active' : ''}`}
              onClick={() => setSelectedTemplate(template)}
            >
              <div className="picker-thumb"></div>
              <div className="picker-title">{template.name}</div>
            </div>
          ))}
        </div>
      </Modal.Body>
      <Modal.Footer>
        <Button disabled={selectedTemplate === null} onClick={onOk}>
          Ok
        </Button>
      </Modal.Footer>
    </Modal>
  );
};
