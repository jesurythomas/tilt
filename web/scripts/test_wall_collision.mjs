import puppeteer from 'puppeteer';
import path from 'path';

async function testCollision() {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 1200, height: 800 });
  await page.goto('http://localhost:5173', { waitUntil: 'networkidle0' });

  // Select Gauntlet mode and launch
  await page.click('.menu-mode-card[data-mode="gauntlet"]');
  await new Promise(r => setTimeout(r, 200));
  await page.click('#btn-menu-launch');
  await new Promise(r => setTimeout(r, 300));

  // Skip cinematic
  const skipBtn = await page.$('.tilt-cinematic-skip');
  if (skipBtn) await skipBtn.click();
  await new Promise(r => setTimeout(r, 600));

  // In the page, reposition player right beneath a descending wall (not in the gap)
  // and attempt to steer upward into the wall.
  const collisionResult = await page.evaluate(async () => {
    const game = window.__TILT_GAME__;
    if (!game) return { error: 'No game' };

    // Find first row that has positive Y
    let targetRow = game.gauntletMaze.rows.find(r => r.y > 50 && r.y < 300);
    if (!targetRow) {
      // Create a test row right in front of the player
      game.player.x = 400;
      game.player.y = 350;
      game.player.vx = 0;
      game.player.vy = -200; // Moving up fast into the wall
      // The row's left wall segment will be at x: 0..300, gap at 500..600
      targetRow = game.gauntletMaze.rows[0];
      targetRow.y = 320; // 30px above player
      targetRow.gapX = 600; // Far away, so player at 400 hits solid wall
      targetRow.segments = [
        { x: 0, y: 320, width: 550, height: 22 }
      ];
    } else {
      // Place player right below solid segment
      const solidSeg = targetRow.segments[0];
      game.player.x = solidSeg.x + solidSeg.width / 2;
      game.player.y = targetRow.y + 35;
      game.player.vx = 0;
      game.player.vy = -150; // Trying to move upwards into wall
    }

    const startPlayerY = game.player.y;
    const initialWallY = targetRow.y;

    // Simulate 3 fixed updates pushing up into wall
    const dt = 1 / 60;
    for (let f = 0; f < 30; f++) {
      // Player tries to move up with upward velocity
      game.player.vy = -150;
      game.player.y += game.player.vy * dt;
      // Maze update
      game.gauntletMaze.update(
        dt,
        { width: 1200, height: 800 },
        game.player,
        game.scores.stats.score,
        game.scores.stats.survivalTime,
        game.particles,
        () => { game.player.isDead = true; }
      );
    }

    const endPlayerY = game.player.y;
    const endWallY = targetRow.y;

    return {
      startPlayerY,
      endPlayerY,
      initialWallY,
      endWallY,
      isBlocked: endPlayerY >= endWallY + 18, // Player was kept below the wall bottom/pushed down
      playerAlive: !game.player.isDead // Walls block and push, DO NOT kill!
    };
  });

  console.log('Collision Test Result:', JSON.stringify(collisionResult, null, 2));

  if (!collisionResult.isBlocked) {
    throw new Error('FAILED: Wall did not block or push player downward!');
  }
  if (!collisionResult.playerAlive) {
    throw new Error('FAILED: Wall killed player on contact (walls must BLOCK, not kill)!');
  }

  console.log('PASS: Descending walls successfully BLOCK and PUSH the player downwards without killing!');
  await browser.close();
}

testCollision().catch(err => {
  console.error('Test error:', err);
  process.exit(1);
});
