import React, { useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import { StemDeliveryConnected } from 'components/activities/common/stem/delivery/StemDelivery';
import { GradedPointsConnected } from 'components/activities/common/delivery/graded_points/GradedPointsConnected';
import { ResetButtonConnected } from 'components/activities/common/delivery/reset_button/ResetButtonConnected';
import { HintsDeliveryConnected } from 'components/activities/common/hints/delivery/HintsDeliveryConnected';
import { EvaluationConnected } from 'components/activities/common/delivery/evaluation/EvaluationConnected';
import { Provider, useDispatch, useSelector } from 'react-redux';
import {
  ActivityDeliveryState,
  isEvaluated,
  isSubmitted,
  activityDeliverySlice,
  initializeState,
  resetAction,
  savePart,
  submitFiles,
} from 'data/activities/DeliveryState';
import { SubmitButton } from 'components/activities/common/delivery/submit_button/SubmitButton';
import { safelySelectFiles } from 'data/activities/utils';
import { ActivityState, StudentResponse } from 'components/activities/types';
import { configureStore } from 'state/store';
import { DeliveryElement, DeliveryElementProps } from 'components/activities/DeliveryElement';
import { DeliveryElementProvider, useDeliveryElementContext } from '../DeliveryElementProvider';
import { Manifest } from 'components/activities/types';
import { FileSpec, FileUploadSchema } from 'components/activities/file_upload/schema';
import { DEFAULT_PART_ID } from 'components/activities/common/utils';
import { getReadableFileSizeString, fileName } from './utils';
import { RemoveButton } from '../common/authoring/removeButton/RemoveButton';
import { uploadActivityFile } from 'data/persistence/state/intrinsic';
import { defaultMaxFileSize } from './utils';

function onUploadClick(id: string) {
  (window as any).$('#' + id).trigger('click');
}

const getFiles = (state: ActivityDeliveryState) => {
  return state.partState[DEFAULT_PART_ID].studentInput === undefined
    ? []
    : (state.partState[DEFAULT_PART_ID].studentInput as any as FileMetaData[]);
};

type FileMetaData = {
  url: string;
  creationTime: number;
  fileSize: number;
};

const Preview: React.FC<{ file: FileMetaData; fileSpec: FileSpec }> = ({ file }) => {
  let preview = null;

  const ext = file.url.substring(file.url.lastIndexOf('.') + 1).toLowerCase();

  if (ext === 'jpg' || ext === 'png' || ext === 'gif' || ext === 'jpeg') {
    preview = (
      <img
        src={file.url}
        height="150"
        width="200"
        onClick={(e) => (e.target as any).requestFullscreen()}
      />
    );
  } else if (ext === 'mp3' || ext === 'wav') {
    preview = <audio src={file.url} />;
  } else if (ext === 'mp4') {
    preview = (
      <video
        src={file.url}
        height="150"
        width="200"
        onClick={(e) => (e.target as any).requestFullscreen()}
      />
    );
  }

  return preview;
};
const SubmittedFile: React.FC<{
  editMode: boolean;
  file: FileMetaData;
  onRemove: () => void;
  fileSpec: FileSpec;
}> = ({ file, editMode, onRemove, fileSpec }) => {
  return (
    <a className="list-group-item list-group-item-action">
      <div className="d-flex w-100 justify-content-between">
        <h5 className="mb-1">
          <a href={file.url}>{fileName(file.url)}</a>
        </h5>
        <small>
          <RemoveButton
            editMode={editMode}
            onClick={() => {
              onRemove();
            }}
          />
        </small>
      </div>
      <div className="d-flex w-100 justify-content-between">
        <small>{getReadableFileSizeString(file.fileSize)}</small>
        <Preview file={file} fileSpec={fileSpec} />
      </div>
    </a>
  );
};

const FileSubmission: React.FC<{
  sectionSlug: string;
  model: FileUploadSchema;
  state: ActivityState;
  onSavePart: (attemptGuid: string, partAttemptGuid: string, response: StudentResponse) => void;
}> = ({ sectionSlug, model, state, onSavePart }) => {
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const [error, setError] = useState('');

  const maxSizeInBytes =
    model.fileSpec.maxSizeInBytes === undefined
      ? defaultMaxFileSize
      : model.fileSpec.maxSizeInBytes;

  const upload = (files: FileList) => {
    if (files[0].size > maxSizeInBytes) {
      setError('This file exceeds the maximum allowed file size');
    } else {
      uploadActivityFile(sectionSlug, state.attemptGuid, state.parts[0].attemptGuid, files[0]).then(
        (result) => {
          if (result.result === 'success') {
            setError('');
            const newFiles = [
              ...getFiles(uiState),
              { url: result.url, creationDate: result.creationDate, fileSize: result.fileSize },
            ];
            onSavePart(state.attemptGuid, state.parts[0].attemptGuid, {
              files: newFiles,
              input: '',
            });
          } else {
            setError('There was a problem encountered while uploading this file');
          }
        },
      );
    }
  };

  const files = getFiles(uiState).map((file: FileMetaData) => {
    const onRemove = () => {
      const newFiles = getFiles(uiState).filter((f: FileMetaData) => f.url !== file.url);
      onSavePart(state.attemptGuid, state.parts[0].attemptGuid, { files: newFiles, input: '' });
    };
    return (
      <SubmittedFile
        key={file.url}
        editMode={!isSubmitted(uiState) && !isEvaluated(uiState)}
        file={file}
        onRemove={onRemove}
        fileSpec={model.fileSpec}
      />
    );
  });

  const allSubmitted =
    files.length > 0 ? (
      <div>
        <div className="list-group">{files}</div>
      </div>
    ) : null;

  const uploadAnother =
    files.length >= model.fileSpec.maxCount ||
    isSubmitted(uiState) ||
    isEvaluated(uiState) ? null : (
      <div>
        <input
          id={`upload-${uiState.attemptState.attemptGuid}`}
          style={{ display: 'none' }}
          accept={model.fileSpec.accept}
          onChange={({ target: { files } }) => upload(files as FileList)}
          type="file"
        />
        <div className="d-flex w-100 justify-content-between mt-3">
          <p>
            You can upload at most {model.fileSpec.maxCount - files.length} more file
            {model.fileSpec.maxCount - files.length === 1 ? '' : 's'}
          </p>
          <div>
            <button
              className="btn btn-primary media-toolbar-item upload"
              onClick={() => onUploadClick(`upload-${uiState.attemptState.attemptGuid}`)}
            >
              <i className="fa fa-upload" /> Upload
            </button>
            <div>
              <small className="text-muted">
                Max of {getReadableFileSizeString(maxSizeInBytes)}
              </small>
            </div>
          </div>
        </div>
        {error !== '' ? (
          <div className="alert alert-danger" role="alert">
            {error}
          </div>
        ) : null}
      </div>
    );

  return (
    <div>
      <h4>Your Submission</h4>
      {allSubmitted}
      {uploadAnother}
    </div>
  );
};

export const FileUploadComponent: React.FC = () => {
  const { model, state, onResetActivity, onSubmitActivity, onSavePart, sectionSlug, graded } =
    useDeliveryElementContext<FileUploadSchema>();

  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const dispatch = useDispatch();

  useEffect(() => {
    dispatch(
      initializeState(
        state,
        // Short answers only have one input, but the selection is modeled
        // as an array just to make it consistent with the other activity types
        safelySelectFiles(state).caseOf({
          just: (input) => input,
          nothing: () => ({
            [DEFAULT_PART_ID]: [],
          }),
        }),
      ),
    );
  }, []);

  // First render initializes state
  if (!uiState.partState) {
    return null;
  }

  return (
    <div className="activity cata-activity">
      <div className="activity-content">
        <StemDeliveryConnected />
        <GradedPointsConnected />

        <FileSubmission
          sectionSlug={sectionSlug as any}
          model={model}
          state={state}
          onSavePart={(a, p, s) => dispatch(savePart(DEFAULT_PART_ID, s, onSavePart))}
        />

        <ResetButtonConnected
          onReset={() => dispatch(resetAction(onResetActivity, { [DEFAULT_PART_ID]: [] }))}
        />
        <SubmitButton
          shouldShow={!isEvaluated(uiState) && !isSubmitted(uiState) && !graded}
          disabled={getFiles(uiState).length === 0}
          onClick={() => dispatch(submitFiles(onSubmitActivity, getFiles(uiState)))}
        />
        <HintsDeliveryConnected partId={DEFAULT_PART_ID} />
        <EvaluationConnected />
      </div>
    </div>
  );
};

// Defines the web component, a simple wrapper over our React component above
export class FileUploadDelivery extends DeliveryElement<FileUploadSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<FileUploadSchema>) {
    const store = configureStore({}, activityDeliverySlice.reducer);
    ReactDOM.render(
      <Provider store={store}>
        <DeliveryElementProvider {...props}>
          <FileUploadComponent />
        </DeliveryElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}

// Register the web component:
// eslint-disable-next-line
const manifest = require('./manifest.json') as Manifest;
window.customElements.define(manifest.delivery.element, FileUploadDelivery);
