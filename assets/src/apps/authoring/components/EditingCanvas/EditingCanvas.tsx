import React from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { selectBottomPanel, setPanelState, setVisible } from '../../store/app/slice';
import FabricCanvas from './FabricCanvas';

const EditingCanvas: React.FC<any> = (props) => {
  const dispatch = useDispatch();
  const bottomPanelState = useSelector(selectBottomPanel);

  return (
    <React.Fragment>
      <section className="aa-stage">
        <div
          className="aa-stage-inner"
          style={{ marginBottom: bottomPanelState ? 'calc(40vh + 64px)' : 'calc(64px + 39px)' }}
        >
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
                      bottom: false,
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
                      bottom: true,
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
          <FabricCanvas items={[]} />
        </div>
      </section>
    </React.Fragment>
  );
};

export default EditingCanvas;
