// Types for the one export the page uses (src/lamp/header.ts).
export interface PullCordOptions { on?: boolean; warmth?: number; cord?: number; light?: number; label?: string; cordOnly?: boolean }
export class PullCord {
  constructor(host: HTMLElement, opts?: PullCordOptions);
  readonly root: HTMLElement;
  readonly checked: boolean;
  pull(): this;
  set(on: boolean, opts?: { instant?: boolean }): this;
  destroy(): void;
}
export default PullCord;
