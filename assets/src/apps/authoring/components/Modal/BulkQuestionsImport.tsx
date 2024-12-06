import React, { useState } from 'react';
import { Button, Modal } from 'react-bootstrap';
import { useDropzone } from 'react-dropzone';
import Papa from 'papaparse';
import { CreationData } from 'components/activities';

interface Props {
  onCancel: () => void;
  onUpload: (bulkImportData: CreationData[]) => void;
  title?: string;
  show: boolean;
}

const requiredHeaders = [
  'type',
  'title',
  'objectives',
  'tags',
  'stem',
  'choiceA',
  'choiceB',
  'choiceC',
  'choiceD',
  'choiceE',
  'choiceF',
  'answer',
  'correct_feedback',
  'incorrect_feedback',
  'hint1',
  'hint2',
  'hint3',
  'explanation',
];

const maxQuestionsPerImport = 200;

export const BulkQuestionsImport: React.FC<Props> = ({ onCancel, onUpload, title, show }) => {
  const [file, setFile] = useState<File | null>(null);
  const [bulkImportData, setBulkImportData] = useState<CreationData[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  const onDrop = (acceptedFiles: File[]) => {
    if (acceptedFiles.length > 0) {
      handleRemoveFile();
      setFile(acceptedFiles[0]);
      Papa.parse<CreationData>(acceptedFiles[0], {
        header: true,
        download: true,
        skipEmptyLines: true,
        dynamicTyping: true,
        complete: function (results) {
          if (!results.meta.fields) {
            setError('No headers found in the CSV file');
            return;
          }
          const missingHeaders: string[] = validateHeaders(results.meta.fields);
          if (missingHeaders.length > 0) {
            setError(
              `Missing required headers, please consult the sample CSV file: ${missingHeaders.join(
                ', ',
              )}`,
            );
            return;
          }
          const data: CreationData[] = results.data;

          if (data.length > maxQuestionsPerImport) {
            setError('Maximum 200 questions can be imported at a time');
            return;
          }
          if (data.length == 0) {
            setError('A file with no questions cannot be uploaded');
            return;
          }
          if (results.errors.length) {
            setError(`Errors while parsing: ${results.errors}`);
            return;
          }
          data.forEach((question, index) => {
            if (!question.title || question.title.trim() === '') {
              setError(`Title is required for question ${index + 1}`);
              return;
            }
          });

          setBulkImportData(data);
        },
      });
    }
  };

  const { getRootProps, getInputProps } = useDropzone({
    onDrop,
    multiple: false,
    accept: { 'text/csv': ['.csv'] },
  });

  const validateHeaders = (headers: string[]): string[] => {
    const missingHeaders: string[] = [];
    for (const header of requiredHeaders) {
      if (!headers.includes(header)) {
        missingHeaders.push(header);
      }
    }
    return missingHeaders;
  };

  const handleUpload = () => {
    onUpload(bulkImportData as CreationData[]);
  };

  const handleRemoveFile = () => {
    setFile(null);
    setBulkImportData(null);
    setError(null);
  };

  return (
    <Modal show={show} size={'xl'} onHide={onCancel} centered>
      <Modal.Header closeButton={true}>
        <h3 className="modal-title">{title}</h3>
      </Modal.Header>
      <Modal.Body>
        <div className="grid grid-cols-2 gap-6">
          <div className="min-h-[150px] bg-sky-50 dark:bg-sky-900 rounded-lg p-2">
            <div className="font-bold mb-2">Prepare the CSV</div>
            <div className="text-sm pl-8">
              <ul className="list-disc">
                <li>Use heading names supported in the sample CSV file</li>
                <li>Follow the same order of columns as suggested</li>
                <li>Import a maximum of 200 question rows at a time</li>
              </ul>
            </div>
            <div className="mt-4">
              <a
                href="https://docs.google.com/spreadsheets/d/1C9rrY3dHToxG19d8b6Lvwob5PojshV62osO9LrqyWUI/edit?usp=sharing"
                target="_blank"
              >
                Download Sample CSV
              </a>
            </div>
          </div>
          <div className="grid grid-cols-1 min-h-[150px] rounded-lg p-4 bg-slate-50 dark:bg-slate-700 ">
            <div className="grid grid-cols-1 place-self-stretch rounded-lg border-dashed border-slate-200 border-2 p-2 items-center justify-center">
              <div
                className="flex place-self-stretch items-center justify-center"
                {...getRootProps()}
              >
                <input {...getInputProps()} />
                <p>
                  <span>Drag and drop the CSV file here, or </span>
                  <span className="text-primary">Browses</span>
                </p>
              </div>
            </div>
          </div>
        </div>
        <div className="mt-10">
          <div>File Selected</div>
          <div className="flex justify-between rounded-xl border-solid border-slate-200 border-2 min-h-[50px] items-center">
            <div className="px-2">{file?.name}</div>
            <div>
              {file && (
                <Button variant="link" onClick={() => handleRemoveFile()}>
                  Remove
                </Button>
              )}
            </div>
          </div>
        </div>
        <div>{error}</div>
      </Modal.Body>
      <Modal.Footer>
        <Button type="button" variant="secondary" onClick={onCancel}>
          Cancel
        </Button>
        <Button
          type="button"
          variant="primary"
          disabled={bulkImportData === null}
          onClick={handleUpload.bind(this)}
        >
          Upload CSV
        </Button>
      </Modal.Footer>
    </Modal>
  );
};

BulkQuestionsImport.defaultProps = {
  title: 'Bulk Import Questions',
};
