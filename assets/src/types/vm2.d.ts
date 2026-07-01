declare module 'vm2' {
  export interface VMOptions {
    allowAsync?: boolean;
    eval?: boolean;
    sandbox?: Record<string, unknown>;
    timeout?: number;
    wasm?: boolean;
  }

  export class VMScript {
    constructor(code: string);
    compile(): VMScript;
  }

  export class VM {
    constructor(options?: VMOptions);
    run(code: string | VMScript): unknown;
  }
}
