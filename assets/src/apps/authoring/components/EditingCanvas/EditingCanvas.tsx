import React from 'react';
import { useDispatch } from 'react-redux';
import { setPanelState, setVisible } from '../../store/app/slice';

const EditingCanvas: React.FC<any> = (props) => {
  const dispatch = useDispatch();

  return (
    <section className="aa-stage">
      <div className="aa-stage-inner">
        <h1>Main Content Stage</h1>
        <div className="btn-group" role="group">
          <button
            onClick={() =>
              dispatch(
                setPanelState({
                  right: false,
                  left: false,
                  top: false,
                }),
              )
            }
            type="button"
            className="btn btn-secondary"
          >
            hide all
          </button>
          <button
            onClick={() =>
              dispatch(
                setPanelState({
                  right: true,
                  left: true,
                  top: true,
                }),
              )
            }
            type="button"
            className="btn btn-secondary"
          >
            show all
          </button>
          <button
            onClick={() => dispatch(setVisible({ visible: false }))}
            type="button"
            className="btn btn-secondary"
          >
            quit
          </button>
        </div>
      </div>
    </section>
  );
};

export default EditingCanvas;
