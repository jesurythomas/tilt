// =========================================================================
// main.ts - Tilt to Live Bootstrap Entry Point
// =========================================================================

import { TiltGame } from './tilt-to-live/TiltGame';

window.addEventListener('DOMContentLoaded', () => {
  const canvas = document.getElementById('tilt-canvas') as HTMLCanvasElement;
  if (!canvas) {
    throw new Error('Canvas #tilt-canvas not found');
  }

  const game = new TiltGame(canvas);

  game.start();

  // Expose for inspection and test automation
  (window as unknown as { __TILT_GAME__: TiltGame }).__TILT_GAME__ = game;
  (window as any).tiltGame = game;
});
