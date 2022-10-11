import React, { useEffect, useMemo } from 'react';
import { MessageEditorComponent } from '../command_button/commandButtonTypes';

const startEndCueRegex = /startcuepoint=([0-9]+).([0-9]+);endcuepoint=([0-9]+).([0-9]+)/;
const startCueRegex = /startcuepoint=([0-9]+).([0-9]+)/;

// This is the editor for the command that gets sent from the command button to the video player.
export const VideoCommandEditor: MessageEditorComponent = ({ onChange, value }) => {
  const [startSec, setStartSec] = React.useState(0);
  const [startSubSec, setStartSubSec] = React.useState(0);
  const [endSec, setEndSec] = React.useState(0);
  const [endSubSec, setEndSubSec] = React.useState(0);

  useEffect(() => {
    // Support either a message with start & end, or just start
    if (startEndCueRegex.test(value)) {
      const matches = value.match(startEndCueRegex);
      if (matches) {
        setStartSec(parseInt(matches[1]));
        setStartSubSec(parseInt(matches[2]));
        setEndSec(parseInt(matches[3]));
        setEndSubSec(parseInt(matches[4]));
      }
    } else if (startCueRegex.test(value)) {
      const matches = value.match(startCueRegex);
      if (matches) {
        setStartSec(parseInt(matches[1]));
        setStartSubSec(parseInt(matches[2]));
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const outputCommand = useMemo(
    () =>
      endSec == 0 || endSec < startSec
        ? `startcuepoint=${startSec}.${startSubSec}`
        : `startcuepoint=${startSec}.${startSubSec};endcuepoint=${endSec}.${endSubSec}`,
    [startSec, startSubSec, endSec, endSubSec],
  );

  useEffect(() => {
    if (value != outputCommand) {
      onChange(outputCommand);
    }
  }, [value, outputCommand, onChange]);

  return (
    <div>
      <div className="form-group">
        <label>Start Time</label>
        <div className="container">
          <div className="row">
            <input
              onChange={(e) => setStartSec(parseInt(e.target.value))}
              type="number"
              value={startSec}
              min={0}
              className="col form-control"
              id="startSeconds"
            />
            <span>:</span>
            <input
              onChange={(e) => setStartSubSec(parseInt(e.target.value))}
              value={startSubSec}
              type="number"
              min={0}
              max={99}
              className="col form-control"
              id="startSubSeconds"
            />
          </div>
        </div>
        <small className="form-text text-muted">(seconds : hundreths of a second)</small>
      </div>

      <div className="form-group">
        <label>End Time</label>
        <div className="container">
          <div className="row">
            <input
              type="number"
              onChange={(e) => setEndSec(parseInt(e.target.value))}
              value={endSec}
              min={0}
              className="col form-control"
            />
            <span>:</span>
            <input
              onChange={(e) => setEndSubSec(parseInt(e.target.value))}
              type="number"
              value={endSubSec}
              min={0}
              max={99}
              className="col form-control"
            />
          </div>
        </div>
        <small className="form-text text-muted">
          (seconds : hundreths of a second, set to 0 for no end time)
        </small>
      </div>
      <small className="form-text text-muted">Command to send: {outputCommand}</small>
    </div>
  );
};
VideoCommandEditor.label = 'Video Cue Point';
