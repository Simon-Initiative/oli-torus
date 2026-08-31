import React, { Fragment, ReactNode, useCallback, useRef, useState } from 'react';
import { Badge, OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { selectReadOnly, setShowDiagnosticsWindow } from 'apps/authoring/store/app/slice';
import { setCurrentActivityFromSequence } from 'apps/authoring/store/groups/layouts/deck/actions/setCurrentActivityFromSequence';
import {
  countAccessibilityFindings,
  validateAccessibility,
} from 'apps/authoring/store/groups/layouts/deck/actions/accessibilityAudit';
import {
  DiagnosticError,
  validatePartIds,
  validateVariables,
} from 'apps/authoring/store/groups/layouts/deck/actions/validate';
import { setCurrentSelection } from 'apps/authoring/store/parts/slice';
import { IAdaptiveRule, selectAllActivities } from 'apps/delivery/store/features/activities/slice';
import {
  setConfigureRequest,
  setCurrentRule,
  setRightPanelActiveTab,
} from '../../store/app/slice';
import { AdvancedAuthoringModal } from '../AdvancedAuthoringModal';
import { RightPanelTabs } from '../RightMenu/RightPanelTabs';
import { DiagnosticsOverlayProvider } from './DiagnosticsOverlayContext';
import DiagnosticMessage from './diagnostics/DiagnosticMessage';
import { DiagnosticSolution } from './diagnostics/DiagnosticSolution';
import { DiagnosticRuleTypes, DiagnosticTypes } from './diagnostics/DiagnosticTypes';
import { createUpdater } from './diagnostics/actions';
import {
  getProblemKey,
  problemExistsInErrors,
  removeProblemFromErrors,
} from './diagnostics/problemKey';
import { useDiagnosticsCounts } from './useDiagnosticsCounts';

type AuditTab = 'accessibility' | 'validation' | 'variables';

const ActivityPartError: React.FC<{
  error: any;
  onApplyFix: (problem: any) => Promise<void>;
  variant?: 'accessibility' | 'validation';
}> = ({ error, onApplyFix, variant = 'validation' }) => {
  const dispatch = useDispatch();
  const isReadOnlyMode = useSelector(selectReadOnly);
  const currentActivities = useSelector(selectAllActivities);

  const handleClickScreen = (sequenceId: string) => {
    dispatch(setCurrentActivityFromSequence(sequenceId));
  };

  const getOwnerName = (dupe: any) => {
    const screen = error.activity;
    if (dupe.owner.custom.sequenceId === screen.custom.sequenceId) {
      return 'self';
    }
    if (dupe.owner.custom.sequenceId === screen.custom.layerRef) {
      return `${dupe.owner.custom.sequenceName} (Parent)`;
    }
    return dupe.owner.custom.sequenceName;
  };

  const handleProblemFix = async (fixed: string, problem: any) => {
    await dispatch(setCurrentSelection({ selection: '' }));
    const updater = createUpdater(problem.type)(problem, fixed, currentActivities);
    const result = await dispatch(updater);

    const ruleId =
      problem.type === DiagnosticTypes.INVALID_TARGET_MUTATE
        ? problem.item.id
        : problem.type === DiagnosticTypes.INVALID_TARGET_COND
        ? problem.item.rule.id
        : problem.type === DiagnosticTypes.INVALID_VALUE
        ? problem.item.rule.id
        : problem.type === DiagnosticTypes.INVALID_EXPRESSION_VALUE
        ? problem.item.rule.id
        : 'initState';

    const activity = result.meta.arg.activity;
    if (activity) {
      const rule = activity.authoring.rules.find((rule: IAdaptiveRule) => rule.id === ruleId);
      dispatch(setCurrentRule({ currentRule: rule }));
    }
    await onApplyFix(problem);
  };

  const handleProblemClick = async (problem: any) => {
    await dispatch(setCurrentActivityFromSequence(error.activity.custom.sequenceId));
    setTimeout(() => {
      switch (problem.type) {
        case DiagnosticTypes.ACCESSIBILITY: {
          const item = problem.item;
          const selectionId = item.parentPopupId || item.id;
          dispatch(setCurrentSelection({ selection: selectionId }));
          dispatch(setRightPanelActiveTab({ rightPanelActiveTab: RightPanelTabs.COMPONENT }));
          if (item.parentPopupId) {
            dispatch(
              setConfigureRequest({
                partId: item.parentPopupId,
                nestedPartId: item.id,
              }),
            );
          }
          break;
        }
        case DiagnosticTypes.INVALID_TARGET_INIT:
          dispatch(setCurrentRule({ currentRule: 'initState' }));
          break;
        case DiagnosticTypes.INVALID_TARGET_COND:
        case DiagnosticTypes.INVALID_VALUE:
          dispatch(setCurrentRule({ currentRule: problem.item.rule }));
          break;
        case DiagnosticTypes.INVALID_TARGET_MUTATE:
          dispatch(setCurrentRule({ currentRule: problem.item }));
          break;
      }
    }, 100);
  };

  const isRuleItem = (type: DiagnosticTypes) => DiagnosticRuleTypes.indexOf(type) > -1;
  const isClickableItem = (type: DiagnosticTypes) =>
    isRuleItem(type) || type === DiagnosticTypes.ACCESSIBILITY;

  const issueCount = error.problems.length;
  const issueCountClass =
    issueCount >= 3 ? 'diagnostics-hub__screen-issue-count--error' : 'diagnostics-hub__screen-issue-count--warning';

  return (
    <div className="diagnostics-hub__screen-card">
      <div
        className="diagnostics-hub__screen-header"
        onClick={() => handleClickScreen(error.activity.custom.sequenceId)}
        role="button"
        tabIndex={0}
        onKeyDown={(e) => {
          if (e.key === 'Enter' || e.key === ' ') {
            handleClickScreen(error.activity.custom.sequenceId);
          }
        }}
      >
        <div className="diagnostics-hub__screen-header-info">
          <i className="fa fa-desktop" aria-hidden="true" />
          <span className="font-weight-bold">{error.activity.custom.sequenceName}</span>
        </div>
        <span className={`diagnostics-hub__screen-issue-count ${issueCountClass}`}>
          {issueCount} {issueCount === 1 ? 'Issue' : 'Issues'}
        </span>
      </div>
      <div className="diagnostics-hub__issues-list">
        {error.problems.map((problem: any, index: number) => {
          const clickable = isClickableItem(problem.type);
          const showFix =
            !isReadOnlyMode && problem.type !== DiagnosticTypes.ACCESSIBILITY;
          const iconClass =
            variant === 'accessibility'
              ? 'diagnostics-hub__issue-icon--warning'
              : 'diagnostics-hub__issue-icon--error';

          return (
            <div
              key={`${problem.owner.resourceId}-${problem.type}-${problem.item?.id || index}-${
                problem.item?.issue || index
              }`}
              className={`diagnostics-hub__issue-row${clickable ? ' diagnostics-hub__issue-row--clickable' : ''}${showFix ? ' diagnostics-hub__issue-row--has-fix' : ''}`}
              onClick={clickable ? () => handleProblemClick(problem) : undefined}
              role={clickable ? 'button' : undefined}
              tabIndex={clickable ? 0 : undefined}
              onKeyDown={
                clickable
                  ? (e) => {
                      if (e.key === 'Enter' || e.key === ' ') {
                        handleProblemClick(problem);
                      }
                    }
                  : undefined
              }
            >
              <div className="diagnostics-hub__issue-content">
                <div className={`diagnostics-hub__issue-icon ${iconClass}`}>
                  <i
                    className={`fa ${variant === 'accessibility' ? 'fa-exclamation-circle' : 'fa-exclamation-triangle'}`}
                    aria-hidden="true"
                  />
                </div>
                <div className="diagnostics-hub__issue-body">
                  <DiagnosticMessage problem={problem} />
                  {problem.type === DiagnosticTypes.DUPLICATE && (
                    <span
                      className="diagnostics-hub__duplicate-owner ml-2"
                      onClick={(e) => {
                        e.stopPropagation();
                        handleClickScreen(problem.owner.custom.sequenceId);
                      }}
                      role="button"
                      tabIndex={0}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter' || e.key === ' ') {
                          e.stopPropagation();
                          handleClickScreen(problem.owner.custom.sequenceId);
                        }
                      }}
                    >
                      Owner: {getOwnerName(problem)}
                    </span>
                  )}
                  {showFix && (
                    <div
                      className="diagnostics-hub__issue-fix"
                      onClick={(e) => e.stopPropagation()}
                    >
                      <DiagnosticSolution
                        type={problem.type}
                        suggestion={problem.suggestedFix}
                        onClick={(val: any) => handleProblemFix(val, problem)}
                      />
                    </div>
                  )}
                </div>
              </div>
              {clickable && (
                <span className="diagnostics-hub__focus-hint">
                  Focus Canvas <i className="fa fa-arrow-right" aria-hidden="true" />
                </span>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
};

export const PageError: React.FC<{ error: any }> = ({ error }) => {
  const variableNames = error.map((err: any) => err.id).join(', ');

  return (
    <div className="diagnostics-hub__variable-card">
      <div className="diagnostics-hub__variable-icon">
        <i className="fa fa-bug" aria-hidden="true" />
      </div>
      <div className="diagnostics-hub__variable-content">
        <div className="font-weight-bold mb-1">Variable Evaluation Failure</div>
        <p className="mb-0">
          Variable(s) <code>{variableNames}</code> failed to evaluate.
        </p>
      </div>
    </div>
  );
};

interface AuditPanelConfig {
  tab: AuditTab;
  title: string;
  description: string;
  prescanTitle: string;
  prescanDescription: string;
  icon: string;
  executeClass: string;
}

const TAB_LABELS: Record<AuditTab, string> = {
  accessibility: 'Accessibility Audit',
  validation: 'Validate Lesson',
  variables: 'Validate Variables',
};

const AUDIT_PANELS: Record<AuditTab, AuditPanelConfig> = {
  accessibility: {
    tab: 'accessibility',
    title: 'Accessibility Audit',
    description: 'Scan lesson screens for missing ARIA labels and alt text.',
    prescanTitle: 'Ready to audit accessibility',
    prescanDescription:
      'Click the Execute Audit button above to scan all screens and components for accessibility compliance.',
    icon: 'fa-universal-access',
    executeClass: 'diagnostics-hub__execute-btn--accessibility',
  },
  validation: {
    tab: 'validation',
    title: 'Validate Lesson Rules',
    description: 'Inspect rule condition targets and resolve mismatch errors.',
    prescanTitle: 'Ready to validate lesson rules',
    prescanDescription:
      'Click the Execute Audit button above to check item matching and conditional rule targets.',
    icon: 'fa-exclamation-circle',
    executeClass: 'diagnostics-hub__execute-btn--validation',
  },
  variables: {
    tab: 'variables',
    title: 'Validate Variables',
    description: 'Check for uninitialized or corrupted variable evaluations.',
    prescanTitle: 'Ready to validate variables',
    prescanDescription:
      'Click the Execute Audit button above to scan state dependencies and variable bindings.',
    icon: 'fa-code',
    executeClass: 'diagnostics-hub__execute-btn--variables',
  },
};

interface DiagnosticsWindowProps {
  onClose?: () => void;
}

const DiagnosticsWindow: React.FC<DiagnosticsWindowProps> = ({ onClose }) => {
  const dispatch = useDispatch();
  const hubRef = useRef<HTMLDivElement>(null);
  const [overlayContainer, setOverlayContainer] = useState<HTMLElement | null>(null);

  const [activeTab, setActiveTab] = useState<AuditTab>('accessibility');
  const [accessibilityResults, setAccessibilityResults] = useState<ReactNode | null>(null);
  const [validationErrors, setValidationErrors] = useState<DiagnosticError[]>([]);
  const [variablesResults, setVariablesResults] = useState<ReactNode | null>(null);
  const [hasRunAccessibility, setHasRunAccessibility] = useState(false);
  const [hasRunValidation, setHasRunValidation] = useState(false);
  const [hasRunVariables, setHasRunVariables] = useState(false);
  const [accessibilityIssueCount, setAccessibilityIssueCount] = useState(0);
  const [accessibilityScreenCount, setAccessibilityScreenCount] = useState(0);
  const [validationScreenCount, setValidationScreenCount] = useState(0);

  const { lessonResultsCount, variableResultsCount, accessibilityResultsCount, refreshCounts, setLessonResultsCount } =
    useDiagnosticsCounts();

  const setHubRef = useCallback((node: HTMLDivElement | null) => {
    hubRef.current = node;
    setOverlayContainer(node?.closest('.modal-content') as HTMLElement | null ?? node);
  }, []);

  const handleClose = () => {
    if (onClose) {
      onClose();
    }
    dispatch(setShowDiagnosticsWindow({ show: false }));
  };

  const handleValidationApplyFix = useCallback(
    async (problem: any, activityResourceId: string) => {
      const result = await dispatch(validatePartIds({}));
      if ((result as any).meta.requestStatus !== 'fulfilled') {
        return;
      }

      const freshErrors = (result as any).payload.errors as DiagnosticError[];
      const problemKey = getProblemKey(problem, activityResourceId);

      if (!problemExistsInErrors(freshErrors, problemKey, activityResourceId)) {
        setValidationErrors((prev) => {
          const next = removeProblemFromErrors(prev, problemKey, activityResourceId);
          setValidationScreenCount(next.length);
          setLessonResultsCount(next.length);
          return next;
        });
      }
    },
    [dispatch, setLessonResultsCount],
  );

  const handleValidateClick = async () => {
    const result = await dispatch(validatePartIds({}));
    if ((result as any).meta.requestStatus === 'fulfilled') {
      setHasRunValidation(true);
      const errors = (result as any).payload.errors as DiagnosticError[];
      setValidationErrors(errors);
      setValidationScreenCount(errors.length);
      setLessonResultsCount(errors.length);
      refreshCounts();
    }
  };

  const handleValidateVariablesClick = async () => {
    const result = await dispatch(validateVariables({}));
    if ((result as any).meta.requestStatus === 'fulfilled') {
      setHasRunVariables(true);
      const errors = (result as any).payload.errors;
      if (errors.length > 0) {
        setVariablesResults(<PageError key={errors[0].owner.title} error={errors} />);
      } else {
        setVariablesResults(
          <p className="diagnostics-hub__empty-message">No errors found.</p>,
        );
      }
      refreshCounts();
    }
  };

  const handleAccessibilityClick = async () => {
    const result = await dispatch(validateAccessibility({}));
    if ((result as any).meta.requestStatus === 'fulfilled') {
      setHasRunAccessibility(true);
      const errors = (result as any).payload.errors;
      setAccessibilityIssueCount(countAccessibilityFindings(errors));
      setAccessibilityScreenCount(errors.length);
      if (errors.length > 0) {
        const errorList = errors.map((item: any) => (
          <ActivityPartError
            key={item.activity.resourceId}
            error={item}
            variant="accessibility"
            onApplyFix={async () => {
              setAccessibilityResults(null);
            }}
          />
        ));
        setAccessibilityResults(errorList);
      } else {
        setAccessibilityResults(
          <p className="diagnostics-hub__empty-message">No accessibility issues found.</p>,
        );
      }
      refreshCounts();
    }
  };

  const handleExecuteAll = async () => {
    await handleAccessibilityClick();
    await handleValidateClick();
    await handleValidateVariablesClick();
  };

  const tabExecuteHandlers: Record<AuditTab, () => Promise<void>> = {
    accessibility: handleAccessibilityClick,
    validation: handleValidateClick,
    variables: handleValidateVariablesClick,
  };

  const tabHasRun: Record<AuditTab, boolean> = {
    accessibility: hasRunAccessibility,
    validation: hasRunValidation,
    variables: hasRunVariables,
  };

  const tabResults: Record<AuditTab, ReactNode | null> = {
    accessibility: accessibilityResults,
    validation: null,
    variables: variablesResults,
  };

  const renderValidationResults = () => {
    if (validationErrors.length === 0) {
      return <p className="diagnostics-hub__empty-message">No errors found.</p>;
    }

    return validationErrors.map((item: DiagnosticError) => (
      <ActivityPartError
        key={(item.activity as any).resourceId}
        error={item}
        variant="validation"
        onApplyFix={(problem) =>
          handleValidationApplyFix(problem, (item.activity as any).resourceId)
        }
      />
    ));
  };

  const tabBadges: Record<AuditTab, number> = {
    accessibility: accessibilityResultsCount,
    validation: lessonResultsCount,
    variables: variableResultsCount,
  };

  const renderSummaryBanner = (tab: AuditTab) => {
    if (tab === 'accessibility' && hasRunAccessibility && accessibilityIssueCount > 0) {
      return (
        <div className="diagnostics-hub__summary-banner diagnostics-hub__summary-banner--accessibility">
          <i className="fa fa-exclamation-triangle text-warning" aria-hidden="true" />
          {accessibilityIssueCount} Issues Across {accessibilityScreenCount} Screens
        </div>
      );
    }
    if (tab === 'validation' && hasRunValidation && validationScreenCount > 0) {
      return (
        <div className="diagnostics-hub__summary-banner diagnostics-hub__summary-banner--validation">
          <i className="fa fa-exclamation-circle" aria-hidden="true" />
          {validationScreenCount} Screens With Issues
        </div>
      );
    }
    if (tab === 'variables' && hasRunVariables && variableResultsCount > 0) {
      return (
        <div className="diagnostics-hub__summary-banner diagnostics-hub__summary-banner--variables">
          <i className="fa fa-bug" aria-hidden="true" />
          {variableResultsCount} Variable(s) Failed
        </div>
      );
    }
    return null;
  };

  const renderAuditPanel = (tab: AuditTab) => {
    const config = AUDIT_PANELS[tab];
    const hasRun = tabHasRun[tab];
    const results = tabResults[tab];

    return (
      <div className={`diagnostics-hub__panel-content${activeTab === tab ? '' : ' d-none'}`}>
        <div className="diagnostics-hub__panel-header">
          <div>
            <h3>{config.title}</h3>
            <p>{config.description}</p>
          </div>
          <button
            type="button"
            className={`diagnostics-hub__execute-btn ${config.executeClass}`}
            onClick={tabExecuteHandlers[tab]}
          >
            <i className={`fa ${hasRun ? 'fa-rotate-right' : 'fa-play'}`} aria-hidden="true" />
            {hasRun ? 'Re-scan' : 'Execute Audit'}
          </button>
        </div>

        {!hasRun && (
          <div className="diagnostics-hub__prescan">
            <div className={`diagnostics-hub__prescan-icon diagnostics-hub__prescan-icon--${tab}`}>
              <i className={`fa ${config.icon}`} aria-hidden="true" />
            </div>
            <h4>{config.prescanTitle}</h4>
            <p>{config.prescanDescription}</p>
          </div>
        )}

        {hasRun && (
          <div className="diagnostics-hub__results">
            {renderSummaryBanner(tab)}
            <div className="mt-3">
              {tab === 'validation' ? renderValidationResults() : results}
            </div>
          </div>
        )}
      </div>
    );
  };

  return (
    <Fragment>
      <AdvancedAuthoringModal
        show={true}
        size="xl"
        onHide={handleClose}
        dialogClassName="diagnostic-modal"
      >
        <DiagnosticsOverlayProvider overlayContainer={overlayContainer}>
          <div className="diagnostics-hub" ref={setHubRef}>
            <div className="diagnostics-hub__header">
              <div className="d-flex align-items-center">
                <div className="diagnostics-hub__header-icon">
                  <i className="fa fa-stethoscope" aria-hidden="true" />
                </div>
                <div className="diagnostics-hub__header-text">
                  <h2>Lesson Diagnostics Hub</h2>
                  <p>Unified audit, inline correction, and interactive canvas navigation</p>
                </div>
              </div>
              <button
                type="button"
                className="diagnostics-hub__close-btn"
                onClick={handleClose}
                aria-label="Close diagnostics"
              >
                <i className="fa fa-times" aria-hidden="true" />
              </button>
            </div>

            <div className="diagnostics-hub__body">
              <nav className="diagnostics-hub__sidebar" aria-label="Audit categories">
                <span className="diagnostics-hub__sidebar-label">Audit Categories</span>

                {(['accessibility', 'validation', 'variables'] as AuditTab[]).map((tab) => {
                  const config = AUDIT_PANELS[tab];
                  const isActive = activeTab === tab;
                  return (
                    <button
                      key={tab}
                      type="button"
                      className={`diagnostics-hub__tab-btn diagnostics-hub__tab-btn--${tab}${
                        isActive ? ' diagnostics-hub__tab-btn--active' : ''
                      }`}
                      onClick={() => setActiveTab(tab)}
                    >
                      <span className="diagnostics-hub__tab-btn-label">
                        <i className={`fa ${config.icon}`} aria-hidden="true" />
                        <span>{TAB_LABELS[tab]}</span>
                      </span>
                      <span
                        className={`diagnostics-hub__tab-badge diagnostics-hub__tab-badge--${tab}`}
                      >
                        {tabBadges[tab]}
                      </span>
                    </button>
                  );
                })}

                <div className="diagnostics-hub__tip">
                  <div className="diagnostics-hub__tip-title">
                    <i className="fa-regular fa-lightbulb" aria-hidden="true" />
                    Tip
                  </div>
                  <p className="mb-0">
                    Click any category above to run or review its individual check.
                  </p>
                </div>
              </nav>

              <div className="diagnostics-hub__panel">
                {renderAuditPanel('accessibility')}
                {renderAuditPanel('validation')}
                {renderAuditPanel('variables')}
              </div>
            </div>

            <div className="diagnostics-hub__footer">
              <span>Panel ready. Select a category to run audit.</span>
              <div className="diagnostics-hub__footer-actions">
                <button
                  type="button"
                  className="diagnostics-hub__footer-btn diagnostics-hub__footer-btn--close"
                  onClick={handleClose}
                >
                  Close
                </button>
                <button
                  type="button"
                  className="diagnostics-hub__footer-btn diagnostics-hub__footer-btn--execute-all"
                  onClick={handleExecuteAll}
                >
                  <i className="fa fa-play" aria-hidden="true" />
                  Execute All Audits
                </button>
              </div>
            </div>
          </div>
        </DiagnosticsOverlayProvider>
      </AdvancedAuthoringModal>
    </Fragment>
  );
};

interface DiagnosticsTriggerProps {
  onClick?: () => void;
}

export const DiagnosticsTrigger: React.FC<DiagnosticsTriggerProps> = ({ onClick }) => {
  const { totalCount } = useDiagnosticsCounts();

  return (
    <OverlayTrigger
      placement="bottom"
      delay={{ show: 150, hide: 150 }}
      overlay={
        <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
          Diagnostics
        </Tooltip>
      }
    >
      <span>
        <button className="px-2 btn btn-link" onClick={onClick} style={{ position: 'relative' }}>
          <i
            className="fa fa-wrench"
            style={{
              fontSize: 24,
              color: '#333',
              verticalAlign: 'text-bottom',
              paddingBottom: '4px',
            }}
          />
          {totalCount > 0 && (
            <Badge
              pill
              variant="danger"
              style={{ right: '0px', position: 'absolute', fontSize: '0.9rem' }}
            >
              {totalCount}
            </Badge>
          )}
        </button>
      </span>
    </OverlayTrigger>
  );
};

export default DiagnosticsWindow;
