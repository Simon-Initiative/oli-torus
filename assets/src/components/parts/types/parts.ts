export interface CustomProperties {
  $schema?: string;
  [key: string]: any;
}
export interface JanusCustomCssActivity extends CustomProperties {
  customCssClass?: string;
}

export interface JanusAbsolutePositioned extends CustomProperties {
  x?: number;
  y?: number;
  z?: number;
  width?: number;
  height?: number;
}