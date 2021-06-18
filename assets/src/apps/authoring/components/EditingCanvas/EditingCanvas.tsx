import React from 'react';
import { useDispatch } from 'react-redux';
import { setPanelState, setVisible } from '../../store/app/slice';
import FabricCanvas from './FabricCanvas';

const EditingCanvas: React.FC<any> = (props) => {
  const dispatch = useDispatch();

  return (
    <React.Fragment>
      <section className="aa-stage">
        <div className="aa-stage-inner">
          <div className="aa-canvas-header">
            <h2 style={{ display: 'inline-block' }}>Active Screen Title</h2>
            <div style={{ float: 'right' }} className="btn-group" role="group">
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
          <FabricCanvas />
        </div>
      </section>
    </React.Fragment>
  );
};

export default EditingCanvas;
