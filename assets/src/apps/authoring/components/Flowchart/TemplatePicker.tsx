import React, { useCallback, useState } from 'react';
import { Button, Modal } from 'react-bootstrap';
import PartsLayoutRenderer from '../../../../components/activities/adaptive/components/delivery/PartsLayoutRenderer';
import { RightArrow } from './onboard-wizard/RightArrow';
import { screenTypeToTitle } from './screens/screen-factories';
import { Template } from './template-types';
import { replaceIds } from './template-utils';
import { templates } from './templates';

interface Props {
  onPick: (template: Template) => void;
  onCancel: () => void;
  screenType?: string;
}

export const screenFilter = [
  'blank_screen',
  'multiple_choice',
  'multiline_text',
  'slider',
  'text_slider',
  'number_input',
  'text_input',
  'dropdown',
  'hub_spoke',
];

export const TemplatePicker: React.FC<Props> = ({ onPick, onCancel, screenType }) => {
  const [selectedTemplate, setSelectedTemplate] = useState<Template | null>(null);
  const [activeScreenType, setActiveScreenType] = useState<string>(
    screenFilter.includes(screenType || '') ? (screenType as string) : 'blank_screen',
  );

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

  const disabled = selectedTemplate === null;

  return (
    <Modal show={true} size="xl" scrollable={true} className="template-picker">
      <Modal.Header className="template-picker-header"></Modal.Header>
      <Modal.Body>
        <h1>Do you want to select the layout?</h1>
        <div className="screen-filter">
          {screenFilter.map((screenType) => (
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
        <div className="picker-list">
          {templates.filter(filterType).map((template, i) => (
            <div
              key={i}
              className={`picker-item ${template === selectedTemplate ? 'active' : ''}`}
              onClick={() => setSelectedTemplate(template)}
            >
              <div className="picker-thumb ">
                <div className="parts-layout-container">
                  <PartsLayoutRenderer
                    parts={template.partsLayout.map((part) => replaceIds({})(part))}
                    onPartInit={() => true}
                    onPartReady={() => true}
                    onPartSave={() => true}
                    onPartSubmit={() => true}
                    onPartResize={() => true}
                    onPartSetData={async () => true}
                    onPartGetData={async () => true}
                  />
                </div>
              </div>
              {/* <div className="picker-title">{template.name}</div> */}
            </div>
          ))}
        </div>
      </Modal.Body>
      <Modal.Footer>
        <Button variant="link" onClick={onCancel}>
          Skip
        </Button>
        <Button variant="link" disabled={disabled} onClick={onOk}>
          Next <RightArrow stroke={disabled ? '#a6a6a6' : undefined} />
        </Button>
      </Modal.Footer>
    </Modal>
  );
};
