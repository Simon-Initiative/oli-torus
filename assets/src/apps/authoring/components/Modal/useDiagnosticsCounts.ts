import { useCallback, useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { selectShowDiagnosticsWindow } from 'apps/authoring/store/app/slice';
import {
  countAccessibilityFindings,
  validateAccessibility,
} from 'apps/authoring/store/groups/layouts/deck/actions/accessibilityAudit';
import {
  validatePartIds,
  validateVariables,
} from 'apps/authoring/store/groups/layouts/deck/actions/validate';
import { selectSequence } from 'apps/delivery/store/features/groups/selectors/deck';

export interface DiagnosticsCounts {
  lessonResultsCount: number;
  variableResultsCount: number;
  accessibilityResultsCount: number;
  totalCount: number;
  refreshCounts: () => Promise<void>;
  setLessonResultsCount: (count: number) => void;
}

export const useDiagnosticsCounts = (): DiagnosticsCounts => {
  const dispatch = useDispatch();
  const showDiagnosticsWindow = useSelector(selectShowDiagnosticsWindow);
  const sequence = useSelector(selectSequence);

  const [lessonResultsCount, setLessonResultsCount] = useState(0);
  const [variableResultsCount, setVariableResultsCount] = useState(0);
  const [accessibilityResultsCount, setAccessibilityResultsCount] = useState(0);

  const refreshCounts = useCallback(async () => {
    const lessonResult = await dispatch(validatePartIds({}));
    if ((lessonResult as any).meta.requestStatus === 'fulfilled') {
      setLessonResultsCount((lessonResult as any).payload.errors.length);
    }

    const variablesResult = await dispatch(validateVariables({}));
    if ((variablesResult as any).meta.requestStatus === 'fulfilled') {
      setVariableResultsCount((variablesResult as any).payload.errors.length);
    }

    const accessibilityResult = await dispatch(validateAccessibility({}));
    if ((accessibilityResult as any).meta.requestStatus === 'fulfilled') {
      setAccessibilityResultsCount(
        countAccessibilityFindings((accessibilityResult as any).payload.errors),
      );
    }
  }, [dispatch]);

  useEffect(() => {
    if (sequence) {
      refreshCounts();
    }
  }, [sequence, refreshCounts]);

  useEffect(() => {
    if (!showDiagnosticsWindow) {
      refreshCounts();
    }
  }, [showDiagnosticsWindow, refreshCounts]);

  return {
    lessonResultsCount,
    variableResultsCount,
    accessibilityResultsCount,
    totalCount: lessonResultsCount + variableResultsCount + accessibilityResultsCount,
    refreshCounts,
    setLessonResultsCount,
  };
};
