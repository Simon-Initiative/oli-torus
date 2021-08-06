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
  onInit: (payload: any) => Promise<any>;
  onReady: (payload: any) => Promise<any>;
  onSave: (payload: any) => Promise<any>;
  onSubmit: (payload: any) => Promise<any>;
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
