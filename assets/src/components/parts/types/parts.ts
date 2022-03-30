export interface CustomProperties {
  $schema?: string;
  [key: string]: any;
}
export interface JanusCustomCss extends CustomProperties {
  customCssClass?: string;
}

export interface JanusAbsolutePositioned extends CustomProperties {
  x?: number;
  y?: number;
  z?: number;
  width?: number;
  height?: number;
}

export interface AnyPartModel extends JanusCustomCss, JanusAbsolutePositioned {
  [key: string]: any;
}

export interface AnyPartComponent {
  id: string;
  type: string;
  custom: AnyPartModel;
}

export interface CapiVariable {
  id: string;
  key: string;
  type: number;
  value: any;
}

export interface PartComponentProps<T extends CustomProperties> {
  id: string;
  type: string;
  model: T;
  state: any;
  notify?: any;
  className?: string;
  onInit: (payload: any) => Promise<any>;
  onReady: (payload: any) => Promise<any>;
  onSave: (payload: any) => Promise<any>;
  onSubmit: (payload: any) => Promise<any>;
  onResize: (payload: any) => Promise<any>;
  onGetData?: (payload: any) => Promise<any>;
  onSetData?: (payload: any) => Promise<any>;
}

export interface AuthorPartComponentProps<T extends CustomProperties>
  extends PartComponentProps<T> {
  editMode: boolean;
  configuremode: boolean; // TODO fix case in custom element wrapper
  portal: string;
  onClick: (payload: any) => void;
  onConfigure: (payload: any) => Promise<any>; // part wants to initiate configuration
  onSaveConfigure: (payload: any) => Promise<any>;
  onCancelConfigure: (payload: any) => Promise<any>;
}

export interface CreationContext {
  transform?: {
    x: number;
    y: number;
    z: number;
    width: number;
    height: number;
  };
  [key: string]: any;
}

export interface ColorPalette {
  useHtmlProps: boolean;
  backgroundColor: string;
  borderColor: string;
  borderRadius: number | string;
  borderStyle: string;
  borderWidth: number | string;
  fillColor?: number;
  fillAlpha?: number;
  lineColor?: number;
  lineAlpha?: number;
  lineStyle?: number;
  lineThickness?: number;
}

export const defaultCapabilities = {
  move: true,
  copy: true,
  resize: true,
  rotate: false,
  select: true,
  delete: true,
  duplicate: true,
  configure: false,
};

export interface Expression {
  item?: unknown;
  part?: unknown;
  suggestedFix?: string;
  owner: any[]; // TODO
  formattedExpression: boolean;
  key?: string;
  message?: string;
}
