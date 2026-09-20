import fs from 'fs';
import path from 'path';
import puppeteer from 'puppeteer';

const publicDir = path.resolve('public');
if (!fs.existsSync(publicDir)) {
  fs.mkdirSync(publicDir, { recursive: true });
}

const svgContent = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <defs>
    <!-- Background Gradient -->
    <radialGradient id="bgGrad" cx="50%" cy="45%" r="65%">
      <stop offset="0%" stop-color="#181534"/>
      <stop offset="60%" stop-color="#0b0a1a"/>
      <stop offset="100%" stop-color="#04030a"/>
    </radialGradient>

    <!-- Border Glow Gradient -->
    <linearGradient id="borderGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#00ffff" stop-opacity="0.9"/>
      <stop offset="50%" stop-color="#0066ff" stop-opacity="0.4"/>
      <stop offset="100%" stop-color="#ff0055" stop-opacity="0.8"/>
    </linearGradient>

    <!-- Hull Gradient -->
    <linearGradient id="hullGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#ffffff"/>
      <stop offset="70%" stop-color="#f0f8ff"/>
      <stop offset="100%" stop-color="#d4ebf8"/>
    </linearGradient>

    <!-- Canopy Gradient -->
    <linearGradient id="canopyGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#70ffff"/>
      <stop offset="100%" stop-color="#00b4d8"/>
    </linearGradient>

    <!-- Thruster Flame Gradient -->
    <linearGradient id="flameGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#ffffff"/>
      <stop offset="30%" stop-color="#00ffff"/>
      <stop offset="70%" stop-color="#0077ff"/>
      <stop offset="100%" stop-color="#002288" stop-opacity="0"/>
    </linearGradient>

    <!-- Red Dot Gradients -->
    <radialGradient id="redDot1" cx="38%" cy="35%" r="65%">
      <stop offset="0%" stop-color="#ff99bb"/>
      <stop offset="35%" stop-color="#ff1155"/>
      <stop offset="85%" stop-color="#cc0033"/>
      <stop offset="100%" stop-color="#77001e"/>
    </radialGradient>
    <radialGradient id="redDot2" cx="38%" cy="35%" r="65%">
      <stop offset="0%" stop-color="#ffb3c6"/>
      <stop offset="40%" stop-color="#ff2266"/>
      <stop offset="85%" stop-color="#d90429"/>
      <stop offset="100%" stop-color="#600014"/>
    </radialGradient>

    <!-- Neon Glow Filter -->
    <filter id="cyanGlow" x="-30%" y="-30%" width="160%" height="160%">
      <feGaussianBlur stdDeviation="8" result="blur"/>
      <feMerge>
        <feMergeNode in="blur"/>
        <feMergeNode in="blur"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>

    <filter id="shipOuterGlow" x="-50%" y="-50%" width="200%" height="200%">
      <feGaussianBlur in="SourceGraphic" stdDeviation="14" result="blur1"/>
      <feGaussianBlur in="SourceGraphic" stdDeviation="6" result="blur2"/>
      <feMerge>
        <feMergeNode in="blur1"/>
        <feMergeNode in="blur2"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>

    <filter id="redGlow" x="-50%" y="-50%" width="200%" height="200%">
      <feGaussianBlur in="SourceGraphic" stdDeviation="10" result="blur"/>
      <feMerge>
        <feMergeNode in="blur"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>

  <!-- Squircle Base with Neon Border -->
  <rect x="8" y="8" width="496" height="496" rx="116" fill="url(#bgGrad)"/>
  <rect x="8" y="8" width="496" height="496" rx="116" fill="none" stroke="url(#borderGrad)" stroke-width="12" opacity="0.85"/>

  <!-- Radar / Vector Grid Accents -->
  <circle cx="256" cy="256" r="200" fill="none" stroke="#00ffff" stroke-width="2" stroke-opacity="0.12" stroke-dasharray="8 8"/>
  <circle cx="256" cy="256" r="130" fill="none" stroke="#00ffff" stroke-width="1.5" stroke-opacity="0.16"/>
  <line x1="56" y1="256" x2="456" y2="256" stroke="#00ffff" stroke-width="1.5" stroke-opacity="0.08"/>
  <line x1="256" y1="56" x2="256" y2="456" stroke="#00ffff" stroke-width="1.5" stroke-opacity="0.08"/>

  <!-- Iconic Red Dot Swarm Enemies (Dodging Vibe) -->
  <!-- Dot 1: Top-Left Aggressor -->
  <g filter="url(#redGlow)">
    <circle cx="108" cy="132" r="28" fill="url(#redDot1)"/>
    <circle cx="108" cy="132" r="33" fill="none" stroke="#ff0055" stroke-width="3" opacity="0.6"/>
  </g>
  <!-- Dot 2: Right Ambush Dot -->
  <g filter="url(#redGlow)">
    <circle cx="414" cy="176" r="22" fill="url(#redDot2)"/>
    <circle cx="414" cy="176" r="26" fill="none" stroke="#ff0055" stroke-width="2.5" opacity="0.6"/>
  </g>
  <!-- Dot 3: Bottom-Left Threat -->
  <g filter="url(#redGlow)">
    <circle cx="132" cy="388" r="24" fill="url(#redDot1)"/>
    <circle cx="132" cy="388" r="28" fill="none" stroke="#ff0055" stroke-width="2.5" opacity="0.6"/>
  </g>
  <!-- Dot 4: Bottom-Right Menace -->
  <g filter="url(#redGlow)">
    <circle cx="388" cy="380" r="32" fill="url(#redDot2)"/>
    <circle cx="388" cy="380" r="38" fill="none" stroke="#ff0055" stroke-width="3.5" opacity="0.7"/>
  </g>

  <!-- Main Hero: Tilt to Live Arrow Ship (Angled dynamically at 32 degrees toward top-right) -->
  <g transform="translate(252, 256) rotate(34)" filter="url(#shipOuterGlow)">
    <!-- Plasma Thruster Trail -->
    <path d="M -30 92 L 0 195 L 30 92 L 0 115 Z" fill="url(#flameGrad)" opacity="0.95"/>
    <ellipse cx="0" cy="100" rx="18" ry="8" fill="#00ffff" opacity="0.8"/>
    <circle cx="0" cy="130" r="7" fill="#ffffff" opacity="0.9"/>
    <circle cx="0" cy="165" r="4.5" fill="#00ffff" opacity="0.75"/>

    <!-- Arrow Ship Hull Back Shadow / Glow Outline -->
    <path d="M 0 -148 L 116 96 L 0 54 L -116 96 Z"
          fill="none" stroke="#00ffff" stroke-width="22" stroke-linejoin="round" stroke-linecap="round" opacity="0.7"/>

    <!-- Primary Arrow Ship Hull -->
    <path d="M 0 -148 L 116 96 L 0 54 L -116 96 Z"
          fill="url(#hullGrad)" stroke="#00ddff" stroke-width="12" stroke-linejoin="round" stroke-linecap="round"/>

    <!-- Wing Wingtip Insets -->
    <polygon points="78,72 108,90 88,48" fill="#00c8e6"/>
    <polygon points="-78,72 -108,90 -88,48" fill="#00c8e6"/>

    <!-- Inner Spine Accent Line -->
    <line x1="0" y1="-120" x2="0" y2="44" stroke="#c0f0ff" stroke-width="4" stroke-linecap="round"/>

    <!-- Glowing Cockpit / Neon Core -->
    <path d="M 0 -38 L 26 14 L 0 32 L -26 14 Z"
          fill="url(#canopyGrad)" stroke="#ffffff" stroke-width="5" stroke-linejoin="round"/>
    <circle cx="0" cy="6" r="4.5" fill="#ffffff"/>
  </g>
</svg>`;

const svgPath = path.join(publicDir, 'favicon.svg');
fs.writeFileSync(svgPath, svgContent.trim(), 'utf-8');
console.log('Saved favicon.svg');

async function renderIcons() {
  const browser = await puppeteer.launch({ headless: true });
  const page = await browser.newPage();

  const htmlContent = `<!DOCTYPE html>
<html>
<head>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; overflow: hidden; background: transparent; }
    svg { width: 100%; height: 100%; display: block; }
  </style>
</head>
<body>
  ${svgContent}
</body>
</html>`;

  await page.setContent(htmlContent, { waitUntil: 'domcontentloaded' });

  async function capture(width, height, outputPath, omitBg = true) {
    await page.setViewport({ width, height, deviceScaleFactor: 1 });
    await page.screenshot({ path: outputPath, omitBackground: omitBg });
  }

  await capture(512, 512, path.join(publicDir, 'icon-512.png'), true);
  console.log('Saved icon-512.png');

  await capture(192, 192, path.join(publicDir, 'icon-192.png'), true);
  console.log('Saved icon-192.png');

  await capture(180, 180, path.join(publicDir, 'apple-touch-icon.png'), true);
  console.log('Saved apple-touch-icon.png');

  await capture(32, 32, path.join(publicDir, 'favicon-32x32.png'), true);
  console.log('Saved favicon-32x32.png');

  await capture(16, 16, path.join(publicDir, 'favicon-16x16.png'), true);
  console.log('Saved favicon-16x16.png');

  await capture(512, 512, path.resolve('favicon-preview.png'), false);
  console.log('Saved favicon-preview.png');

  // Build multi-size favicon.ico (16x16 and 32x32 PNG entries)
  const png16 = fs.readFileSync(path.join(publicDir, 'favicon-16x16.png'));
  const png32 = fs.readFileSync(path.join(publicDir, 'favicon-32x32.png'));

  const header = Buffer.alloc(6);
  header.writeUInt16LE(0, 0);
  header.writeUInt16LE(1, 2); // ICO type
  header.writeUInt16LE(2, 4); // 2 images

  const entry1 = Buffer.alloc(16);
  entry1.writeUInt8(16, 0); // width
  entry1.writeUInt8(16, 1); // height
  entry1.writeUInt8(0, 2);
  entry1.writeUInt8(0, 3);
  entry1.writeUInt16LE(1, 4);
  entry1.writeUInt16LE(32, 6);
  entry1.writeUInt32LE(png16.length, 8);
  entry1.writeUInt32LE(6 + 16 * 2, 12); // offset: 38

  const entry2 = Buffer.alloc(16);
  entry2.writeUInt8(32, 0); // width
  entry2.writeUInt8(32, 1); // height
  entry2.writeUInt8(0, 2);
  entry2.writeUInt8(0, 3);
  entry2.writeUInt16LE(1, 4);
  entry2.writeUInt16LE(32, 6);
  entry2.writeUInt32LE(png32.length, 8);
  entry2.writeUInt32LE(6 + 16 * 2 + png16.length, 12); // offset: 38 + png16.length

  const icoBuffer = Buffer.concat([header, entry1, entry2, png16, png32]);
  fs.writeFileSync(path.join(publicDir, 'favicon.ico'), icoBuffer);
  console.log('Saved favicon.ico, size:', icoBuffer.length);

  await browser.close();
}

renderIcons().catch(err => {
  console.error(err);
  process.exit(1);
});
