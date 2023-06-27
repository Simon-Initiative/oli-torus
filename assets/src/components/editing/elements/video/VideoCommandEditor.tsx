import React, { useEffect, useMemo } from 'react';
import { MessageEditorComponent } from '../command_button/commandButtonTypes';

const startEndCueRegex = /startcuepoint=([0-9.]+);endcuepoint=([0-9.]+)/;
const startCueRegex = /startcuepoint=([0-9.]+)/;

// This is the editor for the command that gets sent from the command button to the video player.
export const VideoCommandEditor: MessageEditorComponent = ({ onChange, value }) => {
  const [startSec, setStartSec] = React.useState('');
  const [startSubSec, setStartSubSec] = React.useState('');
  const [endSec, setEndSec] = React.useState('');
  const [endSubSec, setEndSubSec] = React.useState('');

  useEffect(() => {
    // Support either a message with start & end, or just start
    if (startEndCueRegex.test(value)) {
      const matches = value.match(startEndCueRegex);
      if (matches) {
        const [sec, subsec] = matches[1].split('.');
        setStartSec(sec);
        setStartSubSec(subsec);
        const [endsec, endsubsec] = matches[2].split('.');
        setEndSec(endsec);
        setEndSubSec(endsubsec);
        // setStartSec(matches[1]);
        // setStartSubSec(matches[2]);
        // setEndSec(matches[3]);
        // setEndSubSec(matches[4]);
      }
    } else if (startCueRegex.test(value)) {
      const matches = value.match(startCueRegex);
      if (matches) {
        // setStartSec(matches[1]);
        // setStartSubSec(matches[2]);
        const [sec, subsec] = matches[1].split('.');
        setStartSec(sec);
        setStartSubSec(subsec);
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const outputCommand = useMemo(() => {
    const startTime =
      (startSec ? parseInt(startSec) : 0) + (startSubSec ? parseInt(startSubSec) / 100 : 0);
    const endTime = (endSec ? parseInt(endSec) : 0) + (endSubSec ? parseInt(endSubSec) / 100 : 0);

    return endSec == '' || endTime < startTime
      ? `startcuepoint=${startTime}`
      : `startcuepoint=${startTime};endcuepoint=${endTime}`;
  }, [startSec, startSubSec, endSec, endSubSec]);

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
          <div className="flex flex-row w-72">
            <input
              onChange={(e) => setStartSec(e.target.value)}
              type="number"
              value={startSec}
              min={0}
              className="col form-control w-20"
              id="startSeconds"
            />
            <span>:</span>
            <input
              onChange={(e) => setStartSubSec(e.target.value)}
              value={startSubSec}
              type="number"
              min={0}
              max={99}
              className="col form-control 2-20"
              id="startSubSeconds"
            />
          </div>
        </div>
        <small className="form-text text-muted">(seconds : hundreths of a second)</small>
      </div>

      <div className="form-group">
        <label>End Time</label>
        <div className="container">
          <div className="flex flex-row w-72">
            <input
              type="number"
              onChange={(e) => setEndSec(e.target.value)}
              value={endSec}
              min={0}
              className="col form-control w-20"
            />
            <span>:</span>
            <input
              onChange={(e) => setEndSubSec(e.target.value)}
              type="number"
              value={endSubSec}
              min={0}
              max={99}
              className="col form-control w-20"
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
