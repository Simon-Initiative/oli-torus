import React from 'react';

export interface AdaptivityEditorProps {
  content?: any;
}

export const AdaptivityEditor: React.FC<AdaptivityEditorProps> = (props: AdaptivityEditorProps) => {
  return (
    <div className="aa-adaptivity-editor">
      {/* No Conditions */}
      {/* <div className="text-center border rounded">
          <div className="card-body">
            <button className="btn btn-sm btn-primary">
              <i className="fa fa-plus" /> Add rule
            </button>
          </div>
        </div> */}

      {/* Has Conditions */}
      <div className="aa-conditions d-flex w-100">
        <button className="aa-add-button btn btn-primary btn-sm mr-3">
          <i className="fa fa-plus" />
        </button>
        <div className="d-flex flex-column w-100">
          <div className="aa-condition border rounded p-2 mt-4">
            <div className="aa-condition-header d-flex justify-content-between align-items-center">
              <div>CONDITIONS</div>
              <div>
                <button className="btn btn-link p-0">
                  <i className="fa fa-trash-alt" />
                </button>
                <button className="btn btn-link p-0 ml-1">
                  <i className="fa fa-plus" />
                </button>
                {/* TODO: implement collapse / expand for rule groups */}
                {/* <button className="btn btn-link p-0 ml-1">
                  <i className="fa fa-angle-down" />
                  {!panelState['bottom'] && <i className="fa fa-angle-right" />}
                </button> */}
              </div>
            </div>
            <div className="d-flex align-items-center">
              <span className="mr-2">If</span>
              <div className="form-check form-check-inline mr-1">
                <input
                  className="form-check-input"
                  type="radio"
                  name="anyAllToggle"
                  id="anyCondition"
                  value="any"
                />
                <label className="form-check-label" htmlFor="anyCondition">
                  ANY
                </label>
              </div>
              <div className="form-check form-check-inline mr-2">
                <input
                  className="form-check-input"
                  type="radio"
                  name="anyAllToggle"
                  id="allCondition"
                  value="all"
                />
                <label className="form-check-label" htmlFor="allCondition">
                  ALL
                </label>
              </div>
              of the following conditions are met
            </div>
            <div className="d-flex mt-1">
              <label className="sr-only" htmlFor="target">
                target
              </label>
              <select
                className="custom-select mr-2 form-control form-control-sm flex-grow-1 mw-25"
                id="target"
                defaultValue="0"
              >
                <option value="0">Choose...</option>
                <option value="1">One</option>
                <option value="2">Two</option>
                <option value="3">Three</option>
              </select>
              <label className="sr-only" htmlFor="type">
                type
              </label>
              <select
                className="custom-select mr-2 form-control form-control-sm flex-grow-1 mw-25"
                id="type"
                defaultValue="0"
              >
                <option value="0">Choose...</option>
                <option value="1">One</option>
                <option value="2">Two</option>
                <option value="3">Three</option>
              </select>
              <label className="sr-only" htmlFor="operator">
                operator
              </label>
              <select
                className="custom-select mr-2 form-control form-control-sm flex-grow-1 mw-25"
                id="operator"
                defaultValue="0"
              >
                <option value="0">
                  Choose with a really long name that might stretch out the labeel?...
                </option>
                <option value="1">One</option>
                <option value="2">Two</option>
                <option value="3">Three</option>
              </select>
              <label className="sr-only">value</label>
              <input
                type="email"
                className="form-control form-control-sm flex-grow-1 mw-25"
                id="value"
              />
            </div>
          </div>
        </div>
      </div>
      <p className="mt-3 mb-0">Perform the following actions:</p>
      <div className="aa-actions pt-3 mt-2 d-flex w-100">
        <button className="aa-add-button btn btn-primary btn-sm mr-3">
          <i className="fa fa-plus" />
        </button>
        <div className="d-flex flex-column w-100">
          <div className="aa-action d-flex mb-2">
            <label className="sr-only" htmlFor="operator">
              operator
            </label>
            <select
              className="custom-select mr-2 form-control form-control-sm w-25"
              id="operator"
              defaultValue="0"
            >
              <option value="0">Choose...</option>
              <option value="1">One</option>
              <option value="2">Two</option>
              <option value="3">Three</option>
            </select>
            <label className="sr-only">value</label>
            <input type="email" className="form-control form-control-sm w-75" id="value" />
          </div>
        </div>
      </div>
    </div>
  );
};
