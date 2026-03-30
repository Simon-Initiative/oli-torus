import React from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { AuthoringElement, AuthoringElementProps } from 'components/activities/AuthoringElement';
import { OliEmbeddedActions } from 'components/activities/oli_embedded/actions';
import { OliEmbeddedModelSchema } from 'components/activities/oli_embedded/schema';
import {
  analyzeEmbeddedXml,
  buildRuntimeAssetBase,
  buildUploadDirectory,
  buildUploadLocation,
  isBundleResourceBase,
  lastPart,
  suggestAssetName,
} from 'components/activities/oli_embedded/utils';
import * as ActivityTypes from 'components/activities/types';
import { ScoringStrategy } from 'components/activities/types';
import { uploadSuperActivityFiles } from 'components/media/manager/upload';
import { CloseButton } from 'components/misc/CloseButton';
import { Modal } from 'components/modal/Modal';
import {
  exportSuperActivityPackage,
  importSuperActivityPackage,
  verifySuperActivityMedia,
} from 'data/persistence/media';
import { configureStore } from 'state/store';
import guid from 'utils/guid';
import { prettyPrintXml } from 'utils/xmlPretty';
import { AuthoringElementProvider, useAuthoringElementContext } from '../AuthoringElementProvider';
import { WrappedMonaco } from '../common/variables/WrappedMonaco';

const store = configureStore();

const Embedded = (props: AuthoringElementProps<OliEmbeddedModelSchema>) => {
  const { dispatch, model, editMode, onEdit, onCustomEvent, activityId } =
    useAuthoringElementContext<OliEmbeddedModelSchema>();
  const [processingAction, setProcessingAction] = React.useState<
    'upload' | 'import' | 'export' | null
  >(null);
  const [copyNotice, setCopyNotice] = React.useState<string | null>(null);
  const [verificationError, setVerificationError] = React.useState<string | null>(null);
  const [isVerifyingStorage, setIsVerifyingStorage] = React.useState(false);
  const [showManifestDiagnostics, setShowManifestDiagnostics] = React.useState(false);
  const [showParts, setShowParts] = React.useState(false);
  const [showPartsGuidance, setShowPartsGuidance] = React.useState(false);
  const [showBundleRuntime, setShowBundleRuntime] = React.useState(false);
  const [showSupportingFiles, setShowSupportingFiles] = React.useState(false);
  const copyNoticeTimeout = React.useRef<number | null>(null);
  const mutedTextClass = 'text-muted dark:!text-gray-300';
  const secondaryButtonClass =
    'btn btn-outline-secondary dark:!border-gray-500 dark:!text-gray-100 dark:hover:!bg-gray-700 dark:hover:!border-gray-400';
  const secondarySmallButtonClass =
    'btn btn-sm btn-outline-secondary dark:!border-gray-500 dark:!text-gray-100 dark:hover:!bg-gray-700 dark:hover:!border-gray-400';
  const infoAlertClass =
    'alert alert-info dark:!bg-slate-800 dark:!border-slate-600 dark:!text-gray-100';

  const display = (c: any, id: string) => {
    let element = document.querySelector('#' + id);
    if (!element) {
      element = document.createElement('div');
      element.id = id;
      document.body.appendChild(element);
    }
    ReactDOM.render(c, element);
  };

  React.useEffect(() => {
    return () => {
      if (copyNoticeTimeout.current !== null) {
        window.clearTimeout(copyNoticeTimeout.current);
      }
    };
  }, []);

  const onFileUpload = (files: FileList) => {
    if (processingAction !== null) {
      return;
    }

    const fileList: File[] = [];
    for (let i = 0; i < files.length; i = i + 1) {
      const file = files[i];
      fileList.push(file);
    }

    if (fileList.length === 0) {
      return;
    }

    const directory = buildUploadDirectory(model.resourceBase);
    setProcessingAction('upload');
    uploadSuperActivityFiles(directory, fileList)
      .then((result: any) => {
        result.forEach((i: any) => {
          dispatch(OliEmbeddedActions.addResourceURL(i.url));
        });
      })
      .catch((reason: any) => {
        const id = 'upload_error';
        display(errorModal(reason.message, id), id);
      })
      .finally(() => {
        setProcessingAction(null);
      });
  };

  const showCopyNotice = (message: string) => {
    setCopyNotice(message);

    if (copyNoticeTimeout.current !== null) {
      window.clearTimeout(copyNoticeTimeout.current);
    }

    copyNoticeTimeout.current = window.setTimeout(() => {
      setCopyNotice(null);
      copyNoticeTimeout.current = null;
    }, 2000);
  };

  const copyText = async (text: string, label: string) => {
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        await navigator.clipboard.writeText(text);
      } else {
        const textarea = document.createElement('textarea');
        textarea.value = text;
        textarea.style.position = 'fixed';
        textarea.style.left = '-9999px';
        document.body.appendChild(textarea);
        textarea.focus();
        textarea.select();
        document.execCommand('copy');
        document.body.removeChild(textarea);
      }

      showCopyNotice(`${label} copied`);
    } catch (error: any) {
      const id = 'clipboard_error';
      display(errorModal(error?.message || 'Unable to copy text', id), id);
    }
  };

  const onUploadClick = (id: string) => {
    if (processingAction !== null) {
      return;
    }

    (window as any).$('#' + id).trigger('click');
  };

  const onPackageImportClick = (id: string) => {
    if (processingAction !== null) {
      return;
    }

    (window as any).$('#' + id).trigger('click');
  };

  const onPackageImport = (files: FileList) => {
    if (processingAction !== null) {
      return;
    }

    const file = files.item(0);

    if (!file) {
      return;
    }

    setProcessingAction('import');
    importSuperActivityPackage(file, model.resourceBase)
      .then((result: any) => {
        onEdit(result.model as OliEmbeddedModelSchema);
        if (onCustomEvent && activityId !== undefined) {
          window.setTimeout(() => {
            void onCustomEvent('refreshActivity', { activityId });
          }, 0);
        }
      })
      .catch((reason: any) => {
        const id = 'package_import_error';
        display(errorModal(formatPackageImportError(reason), id), id);
      })
      .finally(() => {
        setProcessingAction(null);
      });
  };

  const exportPackage = () => {
    if (processingAction !== null) {
      return;
    }

    setProcessingAction('export');
    exportSuperActivityPackage(model)
      .then((result: any) => {
        const url = window.URL.createObjectURL(result.blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = result.filename || 'embedded_activity_package.zip';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        window.URL.revokeObjectURL(url);
      })
      .catch((reason: any) => {
        const id = 'package_export_error';
        display(errorModal(reason.message, id), id);
      })
      .finally(() => {
        setProcessingAction(null);
      });
  };

  const handleScoringChange = (partId: string, key: string) => {
    // eslint-disable-next-line @typescript-eslint/ban-ts-comment
    // @ts-ignore
    const scoring: ScoringStrategy = ScoringStrategy[key];
    dispatch(OliEmbeddedActions.updatePartScoringStrategy(partId, scoring));
  };

  const removePart = (partId: string) => {
    if (model.authoring.parts.length <= 1) {
      return;
    }

    dispatch(OliEmbeddedActions.removePart(partId));
  };

  const addNewPart = () => {
    dispatch(OliEmbeddedActions.addNewPart());
  };

  const id = guid();
  const packageImportId = guid();
  const manifestDiagnosticsPanelId = `oli-embedded-manifest-diagnostics-${activityId ?? 'new'}`;
  const bundleRuntimePanelId = `oli-embedded-bundle-runtime-${activityId ?? 'new'}`;
  const supportingFilesPanelId = `oli-embedded-supporting-files-${activityId ?? 'new'}`;
  const partsPanelId = `oli-embedded-parts-${activityId ?? 'new'}`;
  const partsGuidancePanelId = `oli-embedded-parts-guidance-${activityId ?? 'new'}`;
  const uploadedResources = model.resourceURLs.map((url) => ({
    url,
    relativePath: lastPart(model.resourceBase, url),
  }));
  const diagnostics = analyzeEmbeddedXml(
    model.modelXml,
    uploadedResources.map((resource) => resource.relativePath),
  );
  const verificationStatuses = model.resourceVerification || {};
  const verificationTargets = Array.from(
    new Set([
      ...diagnostics.references,
      ...uploadedResources.map((resource) => resource.relativePath),
    ]),
  ).sort();
  const verifiedReferenceSet = new Set(
    verificationTargets.filter((path) => verificationStatuses[path] === 'verified'),
  );
  const missingReferenceSet = new Set(
    verificationTargets.filter((path) => verificationStatuses[path] === 'missing'),
  );
  const unusedUploadSet = new Set(diagnostics.unusedUploads);
  const bundleBacked = isBundleResourceBase(model.resourceBase);
  const uploadLocation = buildUploadLocation(model.resourceBase);
  const runtimeAssetBase = buildRuntimeAssetBase(model.resourceBase);
  const verifiedXmlReferences = diagnostics.references.filter(
    (reference) => verificationStatuses[reference] === 'verified',
  );
  const missingXmlReferences = diagnostics.references.filter(
    (reference) => verificationStatuses[reference] === 'missing',
  );
  const verificationPending =
    verificationTargets.length > 0 &&
    verificationTargets.some((path) => verificationStatuses[path] === undefined);
  const actionsDisabled = !editMode || processingAction !== null;

  React.useEffect(() => {
    if (verificationTargets.length === 0) {
      if (Object.keys(verificationStatuses).length > 0) {
        dispatch(OliEmbeddedActions.replaceResourceVerification({}));
      }

      setVerificationError(null);
      setIsVerifyingStorage(false);
      return;
    }

    const currentVerification = Object.fromEntries(
      verificationTargets
        .filter((path) => verificationStatuses[path] !== undefined)
        .map((path) => [path, verificationStatuses[path]]),
    ) as Record<string, 'verified' | 'missing'>;

    let cancelled = false;
    setVerificationError(null);

    const timeoutId = window.setTimeout(() => {
      setIsVerifyingStorage(true);

      verifySuperActivityMedia(buildUploadDirectory(model.resourceBase), verificationTargets)
        .then((result: any) => {
          if (cancelled) {
            return;
          }

          const statuses = result.statuses || {};
          setIsVerifyingStorage(false);

          if (JSON.stringify(statuses) !== JSON.stringify(currentVerification)) {
            dispatch(OliEmbeddedActions.replaceResourceVerification(statuses));
          }
        })
        .catch((reason: any) => {
          if (cancelled) {
            return;
          }

          setIsVerifyingStorage(false);
          setVerificationError(reason?.message || 'Unable to verify supporting files.');
        });
    }, 350);

    return () => {
      cancelled = true;
      window.clearTimeout(timeoutId);
    };
  }, [dispatch, model.resourceBase, verificationTargets.join('|')]);

  const dismiss = (id: string) => {
    const element = document.querySelector('#' + id);
    if (element) {
      ReactDOM.unmountComponentAtNode(element);
    }
  };

  const errorModal = (error: string, id: string) => {
    const footer = (
      <>
        <button
          type="button"
          className="btn btn-primary"
          onClick={() => {
            dismiss(id);
          }}
        >
          Ok
        </button>
      </>
    );

    return (
      <Modal
        title="File Upload"
        footer={footer}
        onCancel={() => {
          dismiss(id);
        }}
      >
        <div className="alert alert-warning" style={{ whiteSpace: 'pre-line' }}>
          {error}
        </div>
      </Modal>
    );
  };

  const formatPackageImportError = (reason: any) => {
    const message = reason?.message || 'Unable to import embedded activity package.';
    const details = reason?.details || {};

    switch (reason?.code) {
      case 'missing_referenced_files': {
        const missingFiles: string[] = Array.isArray(details.missing_files)
          ? details.missing_files
          : [];
        return missingFiles.length > 0
          ? `${message}\n\nMissing files:\n${missingFiles.map((file) => `- ${file}`).join('\n')}`
          : message;
      }

      case 'archive_file_count_exceeded':
        return `${message}\n\nFiles in archive: ${details.actual_file_count}\nAllowed maximum: ${details.max_file_count}`;

      case 'archive_entry_too_large':
        return `${message}\n\nFile: ${details.path}\nSize: ${details.actual_bytes} bytes\nAllowed maximum: ${details.max_bytes} bytes`;

      case 'archive_uncompressed_size_exceeded':
        return `${message}\n\nUncompressed size: ${details.actual_bytes} bytes\nAllowed maximum: ${details.max_bytes} bytes`;

      default:
        return message;
    }
  };

  return (
    <>
      <div className="card mb-3">
        <div className="card-body">
          <div className="d-flex flex-wrap justify-content-between align-items-start gap-2">
            <div>
              <div className="card-title mb-1">Manifest XML</div>
              <div className={`${mutedTextClass} small`}>
                Manifest XML is the launch manifest for your embedded activity. It should list all
                supporting files the runtime needs to load and tell the runtime how to initialize.
              </div>
            </div>
            <div className="d-flex flex-wrap gap-2">
              <button
                type="button"
                className={secondaryButtonClass}
                disabled={!editMode}
                onClick={() =>
                  dispatch(
                    OliEmbeddedActions.editActivityXml(
                      prettyPrintXml(model.modelXml, { indent: 2, inlineTextMax: 80 }),
                    ),
                  )
                }
              >
                Format XML
              </button>
              <button
                type="button"
                className="btn btn-primary media-toolbar-item upload"
                disabled={actionsDisabled}
                onClick={() => onUploadClick(id)}
              >
                {processingAction === 'upload' ? (
                  <>
                    <i className="fa fa-spinner fa-spin" /> Uploading...
                  </>
                ) : (
                  <>
                    <i className="fa fa-upload" /> Upload File
                  </>
                )}
              </button>
              <button
                type="button"
                className={secondaryButtonClass}
                disabled={actionsDisabled}
                onClick={() => onPackageImportClick(packageImportId)}
              >
                {processingAction === 'import' ? (
                  <>
                    <i className="fa fa-spinner fa-spin" /> Importing...
                  </>
                ) : (
                  'Import ZIP'
                )}
              </button>
              <button
                type="button"
                className={secondaryButtonClass}
                disabled={actionsDisabled}
                onClick={() => exportPackage()}
              >
                {processingAction === 'export' ? (
                  <>
                    <i className="fa fa-spinner fa-spin" /> Exporting...
                  </>
                ) : (
                  'Export ZIP'
                )}
              </button>
            </div>
          </div>
          {copyNotice ? (
            <div
              className={`${infoAlertClass} mt-3 mb-0 py-2`}
              role="status"
              aria-live="polite"
              aria-atomic="true"
            >
              {copyNotice}
            </div>
          ) : null}
        </div>
      </div>

      <WrappedMonaco
        model={prettyPrintXml(model.modelXml, { indent: 2, inlineTextMax: 80 })}
        editMode={editMode}
        language="XML"
        onEdit={(s: string) => dispatch(OliEmbeddedActions.editActivityXml(s))}
      />

      <input
        id={id}
        style={{ display: 'none' }}
        disabled={actionsDisabled}
        multiple
        onChange={({ target: { files } }) => onFileUpload(files as FileList)}
        type="file"
      />

      <input
        id={packageImportId}
        style={{ display: 'none' }}
        disabled={actionsDisabled}
        onChange={({ target: { files } }) => onPackageImport(files as FileList)}
        type="file"
        accept=".zip,application/zip"
      />

      <div className="card mt-3">
        <div className="card-body">
          <div className="d-flex flex-wrap justify-content-between align-items-start gap-2">
            <div>
              <div className="card-title mb-1">Manifest Diagnostics</div>
              <div className={`${mutedTextClass} small d-flex flex-wrap gap-3`}>
                <span>{diagnostics.isWellFormed ? 'well-formed XML' : 'XML parse error'}</span>
                <span>{diagnostics.references.length} references</span>
                <span>{verifiedXmlReferences.length} present</span>
                <span>{missingXmlReferences.length} missing</span>
              </div>
            </div>
            <button
              type="button"
              className={secondarySmallButtonClass}
              aria-expanded={showManifestDiagnostics}
              aria-controls={manifestDiagnosticsPanelId}
              onClick={() => setShowManifestDiagnostics((value) => !value)}
            >
              {showManifestDiagnostics ? 'Hide Diagnostics' : 'Show Diagnostics'}
            </button>
          </div>

          <div id={manifestDiagnosticsPanelId} hidden={!showManifestDiagnostics}>
            {showManifestDiagnostics ? (
              <>
                <div
                  className={`alert mt-3 ${
                    diagnostics.isWellFormed ? 'alert-success' : 'alert-danger'
                  }`}
                >
                  {diagnostics.isWellFormed ? (
                    <>XML is well-formed.</>
                  ) : (
                    <>
                      <div className="fw-bold">XML parse error</div>
                      <div>{diagnostics.parseError}</div>
                    </>
                  )}
                </div>

                <div className="row">
                  <div className="col-md-4 mb-2">
                    <div className={`small ${mutedTextClass}`}>Detected references</div>
                    <div className="fw-bold">{diagnostics.references.length}</div>
                  </div>
                  <div className="col-md-4 mb-2">
                    <div className={`small ${mutedTextClass}`}>Verified in storage</div>
                    <div className="fw-bold">{verifiedXmlReferences.length}</div>
                  </div>
                  <div className="col-md-4 mb-2">
                    <div className={`small ${mutedTextClass}`}>Missing in storage</div>
                    <div className="fw-bold">{missingXmlReferences.length}</div>
                  </div>
                </div>

                {verificationError ? (
                  <div className="alert alert-warning mt-3">{verificationError}</div>
                ) : null}

                {verificationPending || isVerifyingStorage ? (
                  <div className={`${infoAlertClass} mt-3`}>
                    Checking supporting files in storage relative to{' '}
                    <code>{model.resourceBase}</code>.
                  </div>
                ) : null}

                {missingXmlReferences.length > 0 ? (
                  <div className="alert alert-warning mt-3">
                    Some XML references are missing from storage for this activity instance.
                  </div>
                ) : null}

                {diagnostics.unusedUploads.length > 0 ? (
                  <div className="alert alert-secondary mt-3">
                    Some supporting files are not referenced by the current Manifest XML.
                  </div>
                ) : null}

                {diagnostics.references.length > 0 ? (
                  <ul className="list-group mt-3">
                    {diagnostics.references.map((reference) => (
                      <li
                        className="list-group-item d-flex flex-wrap justify-content-between align-items-center gap-2"
                        key={reference}
                      >
                        <code>{reference}</code>
                        <div className="d-flex flex-wrap gap-2">
                          <span
                            className={`badge ${
                              missingReferenceSet.has(reference)
                                ? 'bg-warning text-dark'
                                : verifiedReferenceSet.has(reference)
                                ? 'bg-success'
                                : 'bg-secondary'
                            }`}
                          >
                            {missingReferenceSet.has(reference)
                              ? 'missing in storage'
                              : verifiedReferenceSet.has(reference)
                              ? 'present in storage'
                              : 'verification pending'}
                          </span>
                        </div>
                      </li>
                    ))}
                  </ul>
                ) : null}
              </>
            ) : null}
          </div>
        </div>
      </div>

      <div className="card mt-3">
        <div className="card-body">
          <div className="d-flex flex-wrap justify-content-between align-items-start gap-2">
            <div className="card-title mb-0">Bundle Runtime</div>
            <button
              type="button"
              className={secondarySmallButtonClass}
              aria-expanded={showBundleRuntime}
              aria-controls={bundleRuntimePanelId}
              onClick={() => setShowBundleRuntime((value) => !value)}
            >
              {showBundleRuntime ? 'Hide Details' : 'Show Details'}
            </button>
          </div>
          <div id={bundleRuntimePanelId} hidden={!showBundleRuntime}>
            {showBundleRuntime ? (
              <>
                <div
                  className={`alert ${bundleBacked ? 'alert-success' : 'alert-warning'} mb-0 mt-3`}
                >
                  {bundleBacked ? (
                    <>
                      Uploads are bundle-scoped and will resolve relative to this activity instance.
                    </>
                  ) : (
                    <>
                      This activity is not bundle-backed. Uploaded files go to shared media storage,
                      so XML references need extra care.
                    </>
                  )}
                </div>
                <div className="row mt-3">
                  <div className="col-md-6 mb-2">
                    <div className={`small ${mutedTextClass}`}>Iframe base</div>
                    <code>{model.base}</code>
                  </div>
                  <div className="col-md-6 mb-2">
                    <div className={`small ${mutedTextClass}`}>Iframe source page</div>
                    <code>{model.src}</code>
                  </div>
                  <div className="col-md-6 mb-2">
                    <div className={`small ${mutedTextClass}`}>resourceBase</div>
                    <code>{model.resourceBase}</code>
                  </div>
                  <div className="col-md-6 mb-2">
                    <div className={`small ${mutedTextClass}`}>Upload destination</div>
                    <code>{uploadLocation}</code>
                  </div>
                  <div className="col-md-12 mb-2">
                    <div className={`small ${mutedTextClass}`}>Runtime asset base</div>
                    <code>{runtimeAssetBase}</code>
                  </div>
                </div>
              </>
            ) : null}
          </div>
        </div>
      </div>

      <div className="card mt-3">
        <div className="card-body">
          <div className="d-flex flex-wrap justify-content-between align-items-start gap-2">
            <div>
              <div className="card-title mb-1">Supporting Files</div>
              <div className={`${mutedTextClass} small d-flex flex-wrap gap-3`}>
                <span>{uploadedResources.length} tracked</span>
                <span>{verifiedXmlReferences.length} referenced and present</span>
                <span>{missingXmlReferences.length} missing</span>
              </div>
            </div>
            <button
              type="button"
              className={secondarySmallButtonClass}
              aria-expanded={showSupportingFiles}
              aria-controls={supportingFilesPanelId}
              onClick={() => setShowSupportingFiles((value) => !value)}
            >
              {showSupportingFiles ? 'Hide Files' : 'Show Files'}
            </button>
          </div>
          <div id={supportingFilesPanelId} hidden={!showSupportingFiles}>
            {showSupportingFiles ? (
              uploadedResources.length === 0 ? (
                <div className={`${mutedTextClass} mt-3`}>No supporting files uploaded yet.</div>
              ) : (
                <ul className="list-group mt-3">
                  {uploadedResources.map((resource) => {
                    const assetTag = `<asset name="${suggestAssetName(resource.relativePath)}">${
                      resource.relativePath
                    }</asset>`;
                    const sourceTag = `<source>${resource.relativePath}</source>`;
                    const isUnused = unusedUploadSet.has(resource.relativePath);
                    const storageStatus = verificationStatuses[resource.relativePath];

                    return (
                      <li className="list-group-item" key={resource.url}>
                        <div className="d-flex flex-wrap justify-content-between align-items-start gap-2">
                          <div>
                            <div>
                              <code>{resource.relativePath}</code>
                            </div>
                            <div className={`small ${mutedTextClass}`}>{resource.url}</div>
                          </div>
                          <div className="d-flex flex-wrap gap-2">
                            <span
                              className={`badge ${
                                storageStatus === 'missing'
                                  ? 'bg-warning text-dark'
                                  : storageStatus === 'verified'
                                  ? 'bg-success'
                                  : 'bg-secondary'
                              }`}
                            >
                              {storageStatus === 'missing'
                                ? 'missing in storage'
                                : storageStatus === 'verified'
                                ? 'present in storage'
                                : 'verification pending'}
                            </span>
                            <span
                              className={`badge ${
                                isUnused ? 'bg-warning text-dark' : 'bg-success'
                              }`}
                            >
                              {isUnused
                                ? 'not referenced in Manifest XML'
                                : 'referenced in Manifest XML'}
                            </span>
                            <button
                              type="button"
                              className={secondarySmallButtonClass}
                              onClick={() => copyText(resource.relativePath, 'Path')}
                            >
                              Copy Path
                            </button>
                            <button
                              type="button"
                              className={secondarySmallButtonClass}
                              onClick={() => copyText(assetTag, 'Asset tag')}
                            >
                              Copy Asset Tag
                            </button>
                            <button
                              type="button"
                              className={secondarySmallButtonClass}
                              onClick={() => copyText(sourceTag, 'Source tag')}
                            >
                              Copy Source Tag
                            </button>
                            <button
                              type="button"
                              className={secondarySmallButtonClass}
                              onClick={() => copyText(resource.url, 'URL')}
                            >
                              Copy URL
                            </button>
                            <CloseButton
                              className="pl-3 pr-1"
                              editMode={props.editMode}
                              onClick={() =>
                                dispatch(OliEmbeddedActions.removeResourceURL(resource.url))
                              }
                            />
                          </div>
                        </div>
                      </li>
                    );
                  })}
                </ul>
              )
            ) : null}
          </div>
        </div>
      </div>

      <div className="card mt-3">
        <div className="card-body">
          <div className="d-flex flex-wrap justify-content-between align-items-start gap-2">
            <div>
              <div className="card-title mb-1">Parts</div>
              <div className={`${mutedTextClass} small d-flex flex-wrap gap-3`}>
                <span>{model.authoring.parts.length} defined</span>
                <span>
                  Copy part ids into your embedded runtime to connect scoring, state, and saved
                  responses to the correct Torus part.
                </span>
              </div>
            </div>
            <button
              type="button"
              className={secondarySmallButtonClass}
              aria-expanded={showParts}
              aria-controls={partsPanelId}
              onClick={() => setShowParts((value) => !value)}
            >
              {showParts ? 'Hide Parts' : 'Show Parts'}
            </button>
          </div>

          <div id={partsPanelId} hidden={!showParts}>
            {showParts ? (
              <>
                <div className="d-flex flex-wrap justify-content-end gap-2 mt-3">
                  <button
                    type="button"
                    className={secondarySmallButtonClass}
                    aria-expanded={showPartsGuidance}
                    aria-controls={partsGuidancePanelId}
                    onClick={() => setShowPartsGuidance((value) => !value)}
                  >
                    {showPartsGuidance ? 'Hide Integration Help' : 'Show Integration Help'}
                  </button>
                </div>

                <div id={partsGuidancePanelId} hidden={!showPartsGuidance}>
                  {showPartsGuidance ? (
                    <>
                      <div className={`${infoAlertClass} mt-3`}>
                        <div className="fw-bold mb-1">
                          Use part ids as your superactivity integration hooks
                        </div>
                        <div>
                          `oli_embedded` is interaction-agnostic. Your custom activity can tag any
                          answerable input or scored interaction with one of the part ids below,
                          then use the legacy superactivity APIs to save responses and state, submit
                          scores and outcomes, emit logs, and manage attempt lifecycle.
                        </div>
                        <div className="mt-2">
                          This can represent multiple choice, multi-select, true/false, dropdowns,
                          short or long text, numeric or math inputs, fill in the blank, drag and
                          drop, ordering, matching, categorization, hotspot, image labeling,
                          drawing, graphing, sliders, matrices, Likert scales, audio or video
                          response, file upload, code editors, simulations, and other custom
                          interactions.
                        </div>
                      </div>

                      <div className="row mb-3">
                        <div className="col-md-4 mb-2">
                          <div className={`small ${mutedTextClass}`}>What To Tag</div>
                          <div className="small">
                            Use a part id wherever your manifest XML or bootstrap runtime identifies
                            a user input, scored interaction, or submit target.
                          </div>
                        </div>
                        <div className="col-md-4 mb-2">
                          <div className={`small ${mutedTextClass}`}>What The APIs Afford</div>
                          <div className="small">
                            Save and restore work, store user responses, submit scores, emit logs,
                            and close out attempts through the matching part id.
                          </div>
                        </div>
                        <div className="col-md-4 mb-2">
                          <div className={`small ${mutedTextClass}`}>Authoring Workflow</div>
                          <div className="small">
                            Create parts here, copy the ids below, and wire those ids into your
                            embedded runtime so each custom input reports to the intended Torus
                            part.
                          </div>
                        </div>
                      </div>
                    </>
                  ) : null}
                </div>

                <div className="container">
                  {model.authoring.parts.map((part, i) => (
                    <div className="row mb-2" key={i}>
                      <div className="col sm:col-span-2">Part {i + 1}</div>
                      <div className="col lg:col-span-3">
                        <div>
                          <code>{part.id}</code>
                        </div>
                        <div className={`small mt-1 ${mutedTextClass}`}>
                          Use this id to tag the custom input or interaction that should store
                          state, score, and log as this part.
                        </div>
                      </div>
                      <div className="col lg:col-span-2">
                        <select
                          value={part.scoringStrategy}
                          onChange={(e) => handleScoringChange(part.id, e.target.value)}
                          className="custom-select custom-select-sm"
                        >
                          {Object.keys(ScoringStrategy).map((key: string) => (
                            <option key={key} value={key}>
                              {
                                // eslint-disable-next-line @typescript-eslint/ban-ts-comment
                                // @ts-ignore
                                ScoringStrategy[key]
                              }
                            </option>
                          ))}
                        </select>
                      </div>
                      <div className="col-md-auto d-flex align-items-start">
                        <button
                          type="button"
                          className={secondarySmallButtonClass}
                          onClick={() => copyText(part.id, `Part ${i + 1} id`)}
                        >
                          Copy Part ID
                        </button>
                      </div>
                      <div className="col-md-auto">
                        {model.authoring.parts.length > 1 ? (
                          <button
                            onClick={() => removePart(part.id)}
                            type="button"
                            className="close"
                            data-dismiss="alert"
                            aria-label="Remove part"
                          >
                            <i className="fa-solid fa-xmark fa-xl"></i>
                          </button>
                        ) : null}
                      </div>
                    </div>
                  ))}
                </div>
                <button className="btn btn-primary" onClick={() => addNewPart()}>
                  Add Part
                </button>
              </>
            ) : null}
          </div>
        </div>
      </div>
    </>
  );
};

export class OliEmbeddedAuthoring extends AuthoringElement<OliEmbeddedModelSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<OliEmbeddedModelSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <Embedded {...props} />
        </AuthoringElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}

// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, OliEmbeddedAuthoring);
