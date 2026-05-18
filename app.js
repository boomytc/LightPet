const CELL_WIDTH = 192;
const CELL_HEIGHT = 208;
const ATLAS_COLUMNS = 8;
const ATLAS_ROWS = 9;

const ROWS = [
  { state: "idle", row: 0, frames: 6, durations: [280, 110, 110, 140, 140, 320] },
  { state: "running-right", row: 1, frames: 8, durations: [120, 120, 120, 120, 120, 120, 120, 220] },
  { state: "running-left", row: 2, frames: 8, durations: [120, 120, 120, 120, 120, 120, 120, 220] },
  { state: "waving", row: 3, frames: 4, durations: [140, 140, 140, 280] },
  { state: "jumping", row: 4, frames: 5, durations: [140, 140, 140, 140, 280] },
  { state: "failed", row: 5, frames: 8, durations: [140, 140, 140, 140, 140, 140, 140, 240] },
  { state: "waiting", row: 6, frames: 6, durations: [150, 150, 150, 150, 150, 260] },
  { state: "running", row: 7, frames: 6, durations: [120, 120, 120, 120, 120, 220] },
  { state: "review", row: 8, frames: 6, durations: [150, 150, 150, 150, 150, 280] },
];

const sprite = document.querySelector("#sprite");
const petName = document.querySelector("#petName");
const petDescription = document.querySelector("#petDescription");
const frameStatus = document.querySelector("#frameStatus");
const playPause = document.querySelector("#playPause");
const nextFrame = document.querySelector("#nextFrame");
const scaleInput = document.querySelector("#scale");
const stateButtons = document.querySelector("#stateButtons");
const manifestForm = document.querySelector("#manifestForm");
const manifestUrl = document.querySelector("#manifestUrl");
const manifestJson = document.querySelector("#manifestJson");
const atlasImage = document.querySelector("#atlasImage");
const atlasMeta = document.querySelector("#atlasMeta");

let activeRow = ROWS[0];
let frameIndex = 0;
let timer = 0;
let playing = !window.matchMedia("(prefers-reduced-motion: reduce)").matches;
let scale = Number(scaleInput.value);
let activeSheetUrl = "";

function resolveAssetUrl(assetPath, manifestPath) {
  return new URL(assetPath, new URL(manifestPath, window.location.href)).href;
}

function setPetPackage(manifest, manifestPath) {
  const spritesheetPath = manifest.spritesheetPath || "spritesheet.webp";
  activeSheetUrl = resolveAssetUrl(spritesheetPath, manifestPath);

  petName.textContent = manifest.displayName || manifest.id || "LightPet";
  petDescription.textContent = manifest.description || "";
  manifestJson.textContent = JSON.stringify(manifest, null, 2);
  atlasImage.src = activeSheetUrl;
  atlasMeta.textContent = `${ATLAS_COLUMNS}x${ATLAS_ROWS}, ${CELL_WIDTH}x${CELL_HEIGHT}px cells`;
  renderFrame();
  scheduleNextFrame();
}

async function loadManifest(path) {
  clearTimeout(timer);
  frameStatus.textContent = "Loading";
  const response = await fetch(path, { cache: "no-cache" });
  if (!response.ok) {
    throw new Error(`Could not load manifest: ${response.status}`);
  }
  const manifest = await response.json();
  setPetPackage(manifest, path);
}

function renderStateButtons() {
  stateButtons.replaceChildren(
    ...ROWS.map((row) => {
      const button = document.createElement("button");
      button.type = "button";
      button.textContent = row.state;
      button.dataset.state = row.state;
      button.addEventListener("click", () => {
        activeRow = row;
        frameIndex = 0;
        renderFrame();
        scheduleNextFrame();
      });
      return button;
    }),
  );
}

function renderFrame() {
  const width = CELL_WIDTH * scale;
  const height = CELL_HEIGHT * scale;
  const sheetWidth = CELL_WIDTH * ATLAS_COLUMNS * scale;
  const sheetHeight = CELL_HEIGHT * ATLAS_ROWS * scale;
  const x = frameIndex * CELL_WIDTH * scale;
  const y = activeRow.row * CELL_HEIGHT * scale;

  sprite.style.width = `${width}px`;
  sprite.style.height = `${height}px`;
  sprite.style.backgroundImage = `url("${activeSheetUrl}")`;
  sprite.style.backgroundSize = `${sheetWidth}px ${sheetHeight}px`;
  sprite.style.backgroundPosition = `-${x}px -${y}px`;

  frameStatus.textContent = `${activeRow.state} ${frameIndex + 1}/${activeRow.frames}`;
  playPause.textContent = playing ? "Pause" : "Play";

  for (const button of stateButtons.querySelectorAll("button")) {
    button.classList.toggle("active", button.dataset.state === activeRow.state);
  }
}

function scheduleNextFrame() {
  clearTimeout(timer);
  if (!playing) {
    return;
  }
  const delay = activeRow.durations[frameIndex] ?? 140;
  timer = window.setTimeout(() => {
    frameIndex = (frameIndex + 1) % activeRow.frames;
    renderFrame();
    scheduleNextFrame();
  }, delay);
}

playPause.addEventListener("click", () => {
  playing = !playing;
  renderFrame();
  scheduleNextFrame();
});

nextFrame.addEventListener("click", () => {
  playing = false;
  frameIndex = (frameIndex + 1) % activeRow.frames;
  renderFrame();
  scheduleNextFrame();
});

scaleInput.addEventListener("input", () => {
  scale = Number(scaleInput.value);
  renderFrame();
});

manifestForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  try {
    await loadManifest(manifestUrl.value.trim());
  } catch (error) {
    frameStatus.textContent = "Load failed";
    manifestJson.textContent = error instanceof Error ? error.message : String(error);
  }
});

renderStateButtons();
loadManifest(manifestUrl.value).catch((error) => {
  frameStatus.textContent = "Load failed";
  manifestJson.textContent = error instanceof Error ? error.message : String(error);
});
