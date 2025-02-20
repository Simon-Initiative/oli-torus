import React, { useCallback, useMemo, useState } from 'react';
import { Modal, OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { setCurrentPartPropertyFocus } from 'apps/authoring/store/parts/slice';
import { selectAllActivities } from 'apps/delivery/store/features/activities/slice';
import { selectSequence } from 'apps/delivery/store/features/groups/selectors/deck';
import { useToggle } from '../../../../../components/hooks/useToggle';
import { AdvancedAuthoringModal } from '../../AdvancedAuthoringModal';
import { ScreenDeleteIcon } from '../../Flowchart/chart-components/ScreenDeleteIcon';
import { ScreenEditIcon } from '../../Flowchart/chart-components/ScreenEditIcon';

type OptionsType = {
  spokeLabel: string;
  targetScreen: string;
  destinationActivityId: string;
  IsCompleted: boolean;
};

interface Props {
  id: string;
  value: OptionsType[];
  onChange: (value: OptionsType[]) => void;
  onBlur: (id: string, value: OptionsType[]) => void;
}

export const SpokeOptionsEditor: React.FC<Props> = ({ id, value, onChange, onBlur }) => {
  const editEntry = useCallback(
    (index) => (modified: OptionsType) => {
      const newValue = value.map((v, i) => (i === index ? modified : v));
      onChange(newValue);
      // The property editor has an interesting method of commiting changes on blur that could use a look, but think of this as a way
      // for the control to signal that it's time to commit the value. It's much more natural on controls like a text input, but even
      // then it's a bit awkward.
      setTimeout(() => onBlur(id, newValue), 0);
    },
    [id, onBlur, onChange, value],
  );

  const deleteEntry = useCallback(
    (index) => () => {
      const newValue = value.filter((v, i) => i !== index);
      onChange(newValue);
      setTimeout(() => onBlur(id, newValue), 0);
    },
    [id, onBlur, onChange, value],
  );

  const onAddOption = useCallback(() => {
    const newValue = [...value, optionTemplate(value.length + 1)];
    onChange(newValue);
    setTimeout(() => onBlur(id, newValue), 0);
  }, [id, onBlur, onChange, value]);

  return (
    <div>
      <label className="form-label">Number of spokes</label>
      <div>
        {value.map((option, index) => (
          <OptionsEditor
            key={index}
            value={option}
            onChange={editEntry(index)}
            onDelete={deleteEntry(index)}
            totalspoke={value}
          />
        ))}
      </div>

      <button className="btn btn-primary" disabled={value.length >= 5} onClick={onAddOption}>
        <OverlayTrigger
          placement="bottom"
          delay={{ show: 150, hide: 150 }}
          overlay={
            <Tooltip placement="top" id="button-tooltip" style={{ fontSize: '12px' }}>
              {value?.length >= 5 ? <div>Maximum 5 spokes are allowed</div> : <div>Add spoke</div>}
            </Tooltip>
          }
        >
          <div>+ Add Spoke</div>
        </OverlayTrigger>
      </button>
    </div>
  );
};

const OptionsEditor: React.FC<{
  value: OptionsType;
  onChange: (v: OptionsType) => void;
  onDelete: () => void;
  totalspoke: OptionsType[];
}> = ({ value, onChange, onDelete, totalspoke }) => {
  const sequence = useSelector(selectSequence);
  const activities = useSelector(selectAllActivities);
  const [editorOpen, , openEditor, closeEditor] = useToggle(false);
  const [tempValue, setTempValue] = useState<{ value: string }>({ value: '' });
  const dispatch = useDispatch();
  const [currentSpokeLabel, setCurrentSpokeLabel] = useState('');
  const [currentSpokeDestination, setCurrentSpokeDestination] = useState('');
  const [currentSpokeDestinationActivityId, setCurrentSpokeDestinationActivityId] = useState('');
  const screens: Record<string, string> = useMemo(() => {
    return activities.reduce((acc, activity) => {
      const filterhubSpokeScreens = activity.content?.partsLayout.find(
        (parts) => parts.type === 'janus-hub-spoke',
      );
      const validScreens =
        activity.authoring?.flowchart?.screenType !== 'welcome_screen' &&
        activity.authoring?.flowchart?.screenType !== 'end_screen';

      if (!filterhubSpokeScreens && validScreens) {
        return {
          ...acc,
          [activity.id]: activity.title || 'Untitled',
        };
      }
      return acc;
    }, {} as Record<string, string>);
  }, [activities]);
  const onSave = useCallback(() => {
    closeEditor();

    const sequenceEntry = sequence.find((s) => s.resourceId == currentSpokeDestination);
    const activityId = sequenceEntry?.custom.sequenceId ?? currentSpokeDestinationActivityId;
    const newValue = {
      ...value,
      spokeLabel: currentSpokeLabel,
      targetScreen: currentSpokeDestination,
      destinationActivityId: activityId,
    };
    onChange(newValue);
    dispatch(setCurrentPartPropertyFocus({ focus: true }));
  }, [tempValue.value, value, currentSpokeLabel, currentSpokeDestination]);
  const onEdit = useCallback(() => {
    if (!value.targetScreen?.trim()?.length) {
      const sequenceEntry = sequence.find((s) => s.resourceId == Object.keys(screens)[0]);
      if (sequenceEntry) {
        setCurrentSpokeDestination(sequenceEntry?.resourceId);
        setCurrentSpokeDestinationActivityId(sequenceEntry?.custom?.sequenceId);
      }
    } else {
      setCurrentSpokeDestination(value.targetScreen);
      setCurrentSpokeDestinationActivityId(value.destinationActivityId);
    }
    openEditor();
    setTempValue({ value: value.spokeLabel });
    dispatch(setCurrentPartPropertyFocus({ focus: false }));
    setCurrentSpokeLabel(value.spokeLabel);
  }, [openEditor, value.spokeLabel]);

  return (
    <div className="flex">
      <div className="flex-1">{value.spokeLabel}</div>
      <div className="flex-none">
        <button className="btn btn-link p-0 mr-1" onClick={onEdit}>
          <ScreenEditIcon />
        </button>
        <button disabled={totalspoke?.length <= 2} className="btn btn-link p-0" onClick={onDelete}>
          <OverlayTrigger
            placement="bottom"
            delay={{ show: 150, hide: 150 }}
            overlay={
              <Tooltip placement="top" id="button-tooltip" style={{ fontSize: '12px' }}>
                {totalspoke?.length <= 2 ? (
                  <div>Minimum 2 spokes are required</div>
                ) : (
                  <div>Delete the spoke</div>
                )}
              </Tooltip>
            }
          >
            <div>
              <ScreenDeleteIcon />
            </div>
          </OverlayTrigger>
        </button>
      </div>
      {editorOpen && (
        <AdvancedAuthoringModal show={true}>
          <Modal.Header closeButton={true} onClick={closeEditor}>
            <h3 className="modal-title font-bold">Spoke Navigation</h3>
          </Modal.Header>
          <Modal.Body>
            <div className="form-group">
              <label className="font-bold">Spoke Label</label>
              <input
                className="form-control"
                value={currentSpokeLabel}
                onChange={(e) => setCurrentSpokeLabel(e.target.value)}
              ></input>
            </div>
            <div className="form-group">
              <label className="font-bold">Destination</label>
              <select
                style={{ width: '100%' }}
                value={currentSpokeDestination}
                onChange={(e) => setCurrentSpokeDestination(e.target.value)}
              >
                {Object.keys(screens).map((screenId) => (
                  <option key={screenId} value={screenId}>
                    {screens[screenId]}
                  </option>
                ))}
              </select>
            </div>
          </Modal.Body>
          <Modal.Footer>
            <button onClick={onSave} className="btn btn-primary">
              Save
            </button>
          </Modal.Footer>
        </AdvancedAuthoringModal>
      )}
    </div>
  );
};

const optionTemplate = (count: number) => ({
  spokeLabel: `Spoke ${count}`,
  scoreValue: 0,
  targetScreen: '',
  destinationActivityId: '',
  IsCompleted: false,
});
