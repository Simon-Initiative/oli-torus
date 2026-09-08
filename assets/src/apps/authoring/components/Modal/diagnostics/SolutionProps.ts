import { AccessibilityFindingItem } from 'apps/authoring/store/groups/layouts/deck/actions/accessibilityAudit';

export interface SolutionProps {
  type?: string;
  suggestion: string;
  onClick: (val: string) => Promise<void>;
  item?: AccessibilityFindingItem | Record<string, unknown>;
  onMarkDecorative?: () => Promise<void>;
}
