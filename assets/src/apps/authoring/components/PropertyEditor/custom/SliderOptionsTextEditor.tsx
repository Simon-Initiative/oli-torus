import React, { useCallback, useState } from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch } from 'react-redux';
import { setCurrentPartPropertyFocus } from 'apps/authoring/store/parts/slice';
import { ScreenDeleteIcon } from '../../Flowchart/chart-components/ScreenDeleteIcon';

interface Props {
  id: string;
  value: string[];
  onChange: (value: string[]) => void;
  onBlur: (id: string, value: string[]) => void;
}

export const SliderOptionsTextEditor: React.FC<Props> = ({ id, value, onChange, onBlur }) => {
  const editEntry = useCallback(
    (index) => (modified: string) => {
      const newValue = value.map((v, i) => (i === index ? modified : v));
      onChange(newValue);
      console.log({ editEntry: newValue });
    },
    [id, onBlur, onChange, value],
  );

  const deleteEntry = useCallback(
    (index) => () => {
      const newValue = value.filter((v, i) => i !== index);
      console.log({ Delete: newValue });
      onChange(newValue);
      setTimeout(() => onBlur(id, newValue), 0);
    },
    [id, onBlur, onChange, value],
  );

  const onAddOption = useCallback(() => {
    const newValue = [...value, 'Option-' + value.length + 1];
    onChange(newValue);
    setTimeout(() => onBlur(id, newValue), 0);
  }, [id, onBlur, onChange, value]);

  return (
    <div>
      <label className="form-label">Text for slider options</label>
      <div className="form-group">
        {value.map((option, index) => (
          <OptionsEditor
            key={index}
            sliderText={option}
            onChange={editEntry(index)}
            onDelete={deleteEntry(index)}
            options={value}
          />
        ))}
      </div>

      <button className="btn btn-primary" disabled={value.length >= 5} onClick={onAddOption}>
        <OverlayTrigger
          placement="bottom"
          delay={{ show: 150, hide: 150 }}
          overlay={
            <Tooltip placement="top" id="button-tooltip" style={{ fontSize: '12px' }}>
              {value?.length >= 5 ? (
                <div>Maximum 5 options are allowed</div>
              ) : (
                <div>Add Option</div>
              )}
            </Tooltip>
          }
        >
          <div>+ Add Option</div>
        </OverlayTrigger>
      </button>
    </div>
  );
};

const OptionsEditor: React.FC<{
  sliderText: string;
  onChange: (v: string) => void;
  onDelete: () => void;
  options: string[];
}> = ({ sliderText, onChange, onDelete, options }) => {
  const dispatch = useDispatch();
  const [currentOptionLabel, setCurrentOptionLabel] = useState(sliderText);
  return (
    <div className="flex mb-2">
      <div className="flex-1">
        <input
          type="text"
          className="form-control"
          value={currentOptionLabel}
          onChange={(e) => {
            setCurrentOptionLabel(e.target.value);
            onChange(e.target.value);
          }}
          onBlur={() => {
            dispatch(setCurrentPartPropertyFocus({ focus: true }));
          }}
          onFocus={() => {
            dispatch(setCurrentPartPropertyFocus({ focus: false }));
          }}
        ></input>
      </div>
      <div className="flex-none">
        <button disabled={options?.length <= 2} className="btn btn-link p-0" onClick={onDelete}>
          <OverlayTrigger
            placement="bottom"
            delay={{ show: 150, hide: 150 }}
            overlay={
              <Tooltip placement="top" id="button-tooltip" style={{ fontSize: '12px' }}>
                {options?.length <= 2 ? (
                  <div>Minimum 2 options are required</div>
                ) : (
                  <div>Delete the option</div>
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
    </div>
  );
};
