export interface SolutionProps {
  type?: string;
  suggestion: string;
  onClick: (val: string) => Promise<void>;
  item?: {
    id: string;
    type: string;
    issue: string;
    parentPopupId?: string;
  };
  onMarkDecorative?: () => Promise<void>;
}
