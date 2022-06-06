import React from 'react';

import { FileSpec as FileSpecType } from './schema';
import { defaultMaxFileSize } from './utils';
import { TextInput } from 'components/common/TextInput';
import { Select } from 'components/common/Selection';
import { getReadableFileSizeString } from './utils';

const sizes = [
  1024 * 100,
  1024 * 500,
  1024 * 1024 * 5,
  1024 * 1024 * 10,
  1024 * 1024 * 50,
  1024 * 1024 * 100,
];

export type FileSpecConfigurationProps = {
  editMode: boolean;
  fileSpec: FileSpecType;
  onEdit: (fileSpec: FileSpecType) => void;
};

const commonAccepts = [
  { label: 'Any', value: '' },
  { label: 'Audio', value: 'audio/*' },
  { label: 'Video', value: 'video/*' },
  { label: 'Image', value: 'image/*' },
  { label: 'PDF', value: '.pdf' },
  { label: 'PDF or image', value: 'image/*,.pdf' },
  { label: 'Microsoft Word', value: '.doc,.docx,application/msword' },
  { label: 'Microsoft Excel', value: '.xls,.xlsx,application/msexcel' },
  { label: 'Microsoft PowerPoint', value: '.ppt,.pptx,application/mspowerpoint' },
  {
    label: 'ZIP file',
    value:
      'zip,application/octet-stream,application/zip,application/x-zip,application/x-zip-compressed',
  },
];

export const FileSpecConfiguration = (props: FileSpecConfigurationProps) => {
  const maxSizeInBytes =
    props.fileSpec.maxSizeInBytes === undefined
      ? defaultMaxFileSize
      : props.fileSpec.maxSizeInBytes;

  return (
    <div>
      <label>Maximum number of files student can upload</label>
      <TextInput
        editMode={props.editMode}
        label=""
        width="100px"
        value={props.fileSpec.maxCount + ''}
        type="number"
        onEdit={(maxCount) => {
          props.onEdit(Object.assign({}, props.fileSpec, { maxCount }));
        }}
      />

      <label className="mt-4">Maximum size of any file</label>
      <Select
        editMode={props.editMode}
        value={maxSizeInBytes.toString()}
        onChange={(maxSizeInBytes) =>
          props.onEdit(
            Object.assign({}, props.fileSpec, { maxSizeInBytes: parseInt(maxSizeInBytes) }),
          )
        }
      >
        {sizes.map((s) => (
          <option key={s} value={s}>
            {getReadableFileSizeString(s)}
          </option>
        ))}
      </Select>

      <label className="mt-4">Enter allowable file extension types (comma separated)</label>
      <TextInput
        editMode={props.editMode}
        label=""
        value={props.fileSpec.accept}
        type="text"
        onEdit={(accept) => {
          props.onEdit(Object.assign({}, props.fileSpec, { accept }));
        }}
      />

      <div className="btn-group btn-group-sm mt-3" role="group">
        {commonAccepts.map((ca) => {
          return (
            <button
              key={ca.value}
              type="button"
              className="btn btn-outline-secondary"
              onClick={() => props.onEdit(Object.assign({}, props.fileSpec, { accept: ca.value }))}
            >
              {ca.label}
            </button>
          );
        })}
      </div>
      <small className="mt-3 text-muted">Common file extension choices</small>
    </div>
  );
};
