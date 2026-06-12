let CELL_WIDTH = 192;
let CELL_HEIGHT = 208;
let ATLAS_COLUMNS = 8;
let ATLAS_ROWS = 9;
let ATLAS_WIDTH = CELL_WIDTH * ATLAS_COLUMNS;
let ATLAS_HEIGHT = CELL_HEIGHT * ATLAS_ROWS;
let VISIBLE_ALPHA_THRESHOLD = 16;
const CHROMA_KEY = { r: 0, g: 255, b: 0, threshold: 96 };
const CONTRACT_URL = "../../docs/pet-animation-contract.json";
const REQUIRED_MANIFEST_FILENAME = "pet.json";
const REQUIRED_SPRITESHEET_FILENAME = "spritesheet.webp";

let animationRows = [];
let rowByState = new Map();

const sprite = document.querySelector("#sprite");
const petName = document.querySelector("#petName");
const petDescription = document.querySelector("#petDescription");
const frameStatus = document.querySelector("#frameStatus");
const firstFrame = document.querySelector("#firstFrame");
const prevFrame = document.querySelector("#prevFrame");
const playPause = document.querySelector("#playPause");
const nextFrame = document.querySelector("#nextFrame");
const lastFrame = document.querySelector("#lastFrame");
const loopPlayback = document.querySelector("#loopPlayback");
const speedInput = document.querySelector("#speed");
const scaleInput = document.querySelector("#scale");
const stateButtons = document.querySelector("#stateButtons");
const manifestForm = document.querySelector("#manifestForm");
const manifestUrl = document.querySelector("#manifestUrl");
const manifestJson = document.querySelector("#manifestJson");
const atlasImage = document.querySelector("#atlasImage");
const atlasMeta = document.querySelector("#atlasMeta");
const qaStatus = document.querySelector("#qaStatus");
const qaSummary = document.querySelector("#qaSummary");
const overrideState = document.querySelector("#overrideState");
const rowStripFile = document.querySelector("#rowStripFile");
const clearOverride = document.querySelector("#clearOverride");
const overrideStatus = document.querySelector("#overrideStatus");
const rowReview = document.querySelector("#rowReview");
const rowReviewMeta = document.querySelector("#rowReviewMeta");

let activeRow = null;
let frameIndex = 0;
let timer = 0;
let playing = !window.matchMedia("(prefers-reduced-motion: reduce)").matches;
let scale = Number(scaleInput.value);
let speed = Number(speedInput.value);
let activeSheetUrl = "";
let originalSheetUrl = "";
let overrideObjectUrl = "";
let rendering = "pixelated";
let currentAtlasCanvas = null;
let baseAtlasCanvas = null;
let qaData = null;

function validatePetPackageSurface(manifest, manifestPath) {
  const manifestUrlObject = new URL(manifestPath, window.location.href);
  const manifestFilename = manifestUrlObject.pathname.split("/").pop();
  if (manifestFilename !== REQUIRED_MANIFEST_FILENAME) {
    throw new Error("Pet manifest path must be named pet.json.");
  }
  if (manifest.spritesheetPath !== REQUIRED_SPRITESHEET_FILENAME) {
    throw new Error("pet.json must set spritesheetPath to spritesheet.webp.");
  }
  return new URL(REQUIRED_SPRITESHEET_FILENAME, manifestUrlObject).href;
}

async function loadAnimationContract() {
  const response = await fetch(CONTRACT_URL, { cache: "no-cache" });
  if (!response.ok) {
    throw new Error(`Could not load animation contract: ${response.status}`);
  }
  const contract = await response.json();
  applyAnimationContract(contract);
}

function applyAnimationContract(contract) {
  const atlas = contract.atlas;
  if (!atlas || !Array.isArray(contract.states) || contract.states.length === 0) {
    throw new Error("Animation contract is missing atlas or states.");
  }

  CELL_WIDTH = atlas.cellWidth;
  CELL_HEIGHT = atlas.cellHeight;
  ATLAS_COLUMNS = atlas.columns;
  ATLAS_ROWS = atlas.rows;
  ATLAS_WIDTH = CELL_WIDTH * ATLAS_COLUMNS;
  ATLAS_HEIGHT = CELL_HEIGHT * ATLAS_ROWS;
  VISIBLE_ALPHA_THRESHOLD = atlas.visibleAlphaThreshold ?? VISIBLE_ALPHA_THRESHOLD;

  animationRows = contract.states.map((state) => {
    if (!Array.isArray(state.durationsMs) || state.durationsMs.length !== state.frames) {
      throw new Error(`${state.state} must have one duration per frame.`);
    }
    return {
      state: state.state,
      row: state.row,
      frames: state.frames,
      durations: state.durationsMs,
      purpose: state.purpose || state.state,
      mouseMapping: state.mouseMapping || "",
      authoringNotes: state.authoringNotes || [],
    };
  });
  rowByState = new Map(animationRows.map((row) => [row.state, row]));
  activeRow = animationRows[0];
}

function loadImage(src) {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.decoding = "async";
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error(`Could not load image: ${src}`));
    image.src = src;
  });
}

function imageToCanvas(image) {
  const canvas = document.createElement("canvas");
  canvas.width = image.naturalWidth;
  canvas.height = image.naturalHeight;
  const context = canvas.getContext("2d", { willReadFrequently: true });
  context.drawImage(image, 0, 0);
  return canvas;
}

function cloneCanvas(source) {
  const canvas = document.createElement("canvas");
  canvas.width = source.width;
  canvas.height = source.height;
  canvas.getContext("2d", { willReadFrequently: true }).drawImage(source, 0, 0);
  return canvas;
}

function canvasToObjectUrl(canvas) {
  return new Promise((resolve) => {
    canvas.toBlob((blob) => {
      if (overrideObjectUrl) {
        URL.revokeObjectURL(overrideObjectUrl);
      }
      overrideObjectUrl = URL.createObjectURL(blob);
      resolve(overrideObjectUrl);
    }, "image/png");
  });
}

async function setPetPackage(manifest, manifestPath) {
  rendering = manifest.rendering === "smooth" ? "smooth" : "pixelated";
  sprite.classList.toggle("smooth", rendering === "smooth");
  atlasImage.classList.toggle("smooth", rendering === "smooth");

  originalSheetUrl = validatePetPackageSurface(manifest, manifestPath);
  activeSheetUrl = originalSheetUrl;
  const image = await loadImage(activeSheetUrl);
  baseAtlasCanvas = imageToCanvas(image);
  currentAtlasCanvas = cloneCanvas(baseAtlasCanvas);

  petName.textContent = manifest.displayName || manifest.id || "LightPet";
  petDescription.textContent = manifest.description || "";
  manifestJson.textContent = JSON.stringify(manifest, null, 2);
  atlasImage.src = activeSheetUrl;
  rowStripFile.value = "";
  overrideStatus.textContent = "Preview one generated strip only. Use hatch-pet for generation, repair, QA, and package promotion.";

  refreshAtlasState();
}

async function loadManifest(path) {
  clearTimeout(timer);
  frameStatus.textContent = "Loading";
  qaStatus.textContent = "Waiting";
  qaSummary.textContent = "";
  const response = await fetch(path, { cache: "no-cache" });
  if (!response.ok) {
    throw new Error(`Could not load manifest: ${response.status}`);
  }
  const manifest = await response.json();
  await setPetPackage(manifest, path);
}

function refreshAtlasState() {
  qaData = validateAtlas(currentAtlasCanvas);
  atlasMeta.textContent = `${currentAtlasCanvas.width}x${currentAtlasCanvas.height}, ${ATLAS_COLUMNS}x${ATLAS_ROWS}, ${CELL_WIDTH}x${CELL_HEIGHT}px cells`;
  renderFrame();
  renderQa();
  renderRowReview();
  scheduleNextFrame();
}

function validateAtlas(canvas) {
  const result = {
    ok: true,
    width: canvas?.width || 0,
    height: canvas?.height || 0,
    errors: [],
    warnings: [],
    cells: [],
    usedCells: 0,
    emptyUsedCells: 0,
    nontransparentUnusedCells: 0,
  };

  if (!canvas) {
    result.ok = false;
    result.errors.push("No spritesheet loaded.");
    return result;
  }

  if (canvas.width !== ATLAS_WIDTH || canvas.height !== ATLAS_HEIGHT) {
    result.ok = false;
    result.errors.push(`Expected ${ATLAS_WIDTH}x${ATLAS_HEIGHT}, got ${canvas.width}x${canvas.height}.`);
    return result;
  }

  const context = canvas.getContext("2d", { willReadFrequently: true });
  for (const row of animationRows) {
    for (let column = 0; column < ATLAS_COLUMNS; column += 1) {
      const used = column < row.frames;
      const imageData = context.getImageData(
        column * CELL_WIDTH,
        row.row * CELL_HEIGHT,
        CELL_WIDTH,
        CELL_HEIGHT,
      );
      const visiblePixels = countVisiblePixels(imageData.data);
      const nonzeroAlphaPixels = countNonzeroAlphaPixels(imageData.data);
      const cell = { state: row.state, row: row.row, column, used, visiblePixels, nonzeroAlphaPixels, ok: true };

      if (used) {
        result.usedCells += 1;
        if (visiblePixels <= 50) {
          cell.ok = false;
          result.emptyUsedCells += 1;
          result.errors.push(`${row.state} frame ${column + 1} is empty or too sparse.`);
        }
      } else if (nonzeroAlphaPixels > 0) {
        cell.ok = false;
        result.nontransparentUnusedCells += 1;
        result.errors.push(`${row.state} unused cell ${column + 1} is not fully transparent.`);
      }

      result.cells.push(cell);
    }
  }

  result.ok = result.errors.length === 0;
  return result;
}

function countVisiblePixels(data) {
  let count = 0;
  for (let index = 3; index < data.length; index += 4) {
    if (data[index] > VISIBLE_ALPHA_THRESHOLD) {
      count += 1;
    }
  }
  return count;
}

function countNonzeroAlphaPixels(data) {
  let count = 0;
  for (let index = 3; index < data.length; index += 4) {
    if (data[index] !== 0) {
      count += 1;
    }
  }
  return count;
}

function renderQa() {
  if (!qaData) {
    qaStatus.textContent = "Waiting";
    qaStatus.className = "qa-status";
    qaSummary.textContent = "";
    return;
  }

  qaStatus.textContent = qaData.ok ? "Pass" : "Fail";
  qaStatus.className = `qa-status ${qaData.ok ? "pass" : "fail"}`;
  const items = [
    { label: "Atlas", value: `${qaData.width}x${qaData.height}`, state: qaData.width === ATLAS_WIDTH && qaData.height === ATLAS_HEIGHT ? "pass" : "fail" },
    { label: "Used cells", value: `${qaData.usedCells}`, state: qaData.emptyUsedCells === 0 ? "pass" : "fail" },
    { label: "Empty used", value: `${qaData.emptyUsedCells}`, state: qaData.emptyUsedCells === 0 ? "pass" : "fail" },
    { label: "Dirty unused", value: `${qaData.nontransparentUnusedCells}`, state: qaData.nontransparentUnusedCells === 0 ? "pass" : "fail" },
  ];

  qaSummary.replaceChildren(
    ...items.map((item) => {
      const chip = document.createElement("div");
      chip.className = `qa-chip ${item.state}`;
      chip.innerHTML = `<span>${item.label}</span><strong>${item.value}</strong>`;
      return chip;
    }),
  );
}

function renderStateButtons() {
  stateButtons.replaceChildren(
    ...animationRows.map((row) => {
      const button = document.createElement("button");
      button.type = "button";
      button.textContent = row.state;
      button.dataset.state = row.state;
      button.title = row.purpose;
      button.addEventListener("click", () => {
        selectState(row.state);
      });
      return button;
    }),
  );

  overrideState.replaceChildren(
    ...animationRows.map((row) => {
      const option = document.createElement("option");
      option.value = row.state;
      option.textContent = row.state;
      return option;
    }),
  );
}

function renderRowReview() {
  if (!activeSheetUrl || !qaData) {
    rowReview.textContent = "";
    rowReviewMeta.textContent = "";
    return;
  }

  if (qaData.cells.length !== animationRows.length * ATLAS_COLUMNS) {
    rowReview.textContent = "";
    rowReviewMeta.textContent = "row review unavailable until atlas dimensions match";
    return;
  }

  rowReviewMeta.textContent = "click a frame to inspect it";
  rowReview.replaceChildren(
    ...animationRows.map((row) => {
      const card = document.createElement("article");
      const rowCells = qaData.cells.filter((cell) => cell.state === row.state);
      const hasError = rowCells.some((cell) => !cell.ok);
      card.className = `row-card ${activeRow.state === row.state ? "active" : ""} ${hasError ? "has-error" : ""}`;

      const title = document.createElement("button");
      title.className = "row-title";
      title.type = "button";
      title.innerHTML = `<strong>${row.state}</strong><span>${row.frames} frames · ${row.purpose}</span>`;
      title.addEventListener("click", () => selectState(row.state));
      card.append(title);

      const frames = document.createElement("div");
      frames.className = "frame-strip";
      for (let column = 0; column < ATLAS_COLUMNS; column += 1) {
        const cell = rowCells[column];
        const tile = document.createElement("button");
        tile.className = `frame-tile ${cell.used ? "used" : "unused"} ${cell.ok ? "" : "bad"} ${activeRow.state === row.state && frameIndex === column ? "selected" : ""}`;
        tile.type = "button";
        tile.disabled = !cell.used;
        tile.title = cell.used
          ? `${row.state} frame ${column + 1}: ${cell.visiblePixels} visible pixels`
          : `${row.state} unused cell ${column + 1}: ${cell.nonzeroAlphaPixels} nonzero alpha pixels`;

        const thumb = document.createElement("span");
        thumb.className = `frame-thumb ${rendering === "smooth" ? "smooth" : ""}`;
        thumb.style.backgroundImage = `url("${activeSheetUrl}")`;
        thumb.style.backgroundSize = `${ATLAS_WIDTH * 0.45}px ${ATLAS_HEIGHT * 0.45}px`;
        thumb.style.backgroundPosition = `-${column * CELL_WIDTH * 0.45}px -${row.row * CELL_HEIGHT * 0.45}px`;

        const label = document.createElement("span");
        label.className = "frame-label";
        label.textContent = column + 1;

        tile.append(thumb, label);
        tile.addEventListener("click", () => {
          activeRow = row;
          frameIndex = column;
          playing = false;
          renderFrame();
          renderRowReview();
        });
        frames.append(tile);
      }
      card.append(frames);
      return card;
    }),
  );
}

function renderFrame() {
  if (!activeSheetUrl || !activeRow) {
    return;
  }

  const width = CELL_WIDTH * scale;
  const height = CELL_HEIGHT * scale;
  const sheetWidth = ATLAS_WIDTH * scale;
  const sheetHeight = ATLAS_HEIGHT * scale;
  const x = frameIndex * CELL_WIDTH * scale;
  const y = activeRow.row * CELL_HEIGHT * scale;

  sprite.style.width = `${width}px`;
  sprite.style.height = `${height}px`;
  sprite.style.backgroundImage = `url("${activeSheetUrl}")`;
  sprite.style.backgroundSize = `${sheetWidth}px ${sheetHeight}px`;
  sprite.style.backgroundPosition = `-${x}px -${y}px`;

  const duration = activeRow.durations[frameIndex] ?? 140;
  frameStatus.textContent = `${activeRow.state} ${frameIndex + 1}/${activeRow.frames} · ${duration}ms`;
  playPause.textContent = playing ? "Pause" : "Play";

  for (const button of stateButtons.querySelectorAll("button")) {
    const selected = button.dataset.state === activeRow.state;
    button.classList.toggle("active", selected);
    button.setAttribute("aria-pressed", selected ? "true" : "false");
  }
}

function scheduleNextFrame() {
  clearTimeout(timer);
  if (!playing || !activeSheetUrl || !activeRow) {
    return;
  }
  const delay = (activeRow.durations[frameIndex] ?? 140) / speed;
  timer = window.setTimeout(() => {
    if (!loopPlayback.checked && frameIndex === activeRow.frames - 1) {
      playing = false;
      renderFrame();
      return;
    }
    frameIndex = (frameIndex + 1) % activeRow.frames;
    renderFrame();
    renderRowReview();
    scheduleNextFrame();
  }, delay);
}

function selectState(state) {
  const row = rowByState.get(state);
  if (!row) {
    return;
  }
  activeRow = row;
  frameIndex = 0;
  renderFrame();
  renderRowReview();
  scheduleNextFrame();
}

function stepFrame(delta) {
  if (!activeRow) {
    return;
  }
  playing = false;
  frameIndex = (frameIndex + delta + activeRow.frames) % activeRow.frames;
  renderFrame();
  renderRowReview();
}

async function applyRowOverride(file, state) {
  if (!baseAtlasCanvas) {
    throw new Error("Load a pet package before applying a row override.");
  }
  const row = rowByState.get(state);
  if (!row) {
    throw new Error(`Unknown state: ${state}`);
  }

  const sourceUrl = URL.createObjectURL(file);
  try {
    const stripImage = await loadImage(sourceUrl);
    currentAtlasCanvas = cloneCanvas(baseAtlasCanvas);
    drawStripIntoAtlas(currentAtlasCanvas, stripImage, row);
    activeSheetUrl = await canvasToObjectUrl(currentAtlasCanvas);
    atlasImage.src = activeSheetUrl;
    activeRow = row;
    frameIndex = 0;
    playing = false;
    overrideStatus.textContent = `Previewing ${file.name} as ${state}. Browser-only preview; use hatch-pet to generate, repair, validate, and promote package files.`;
    refreshAtlasState();
  } finally {
    URL.revokeObjectURL(sourceUrl);
  }
}

function drawStripIntoAtlas(atlasCanvas, stripImage, row) {
  const atlasContext = atlasCanvas.getContext("2d", { willReadFrequently: true });
  atlasContext.clearRect(0, row.row * CELL_HEIGHT, ATLAS_WIDTH, CELL_HEIGHT);

  const sourceSlotWidth = stripImage.naturalWidth / row.frames;
  const sourceSlotHeight = stripImage.naturalHeight;
  for (let column = 0; column < row.frames; column += 1) {
    const frameCanvas = document.createElement("canvas");
    frameCanvas.width = CELL_WIDTH;
    frameCanvas.height = CELL_HEIGHT;
    const frameContext = frameCanvas.getContext("2d", { willReadFrequently: true });
    frameContext.drawImage(
      stripImage,
      column * sourceSlotWidth,
      0,
      sourceSlotWidth,
      sourceSlotHeight,
      0,
      0,
      CELL_WIDTH,
      CELL_HEIGHT,
    );
    removeChromaKey(frameContext);
    atlasContext.drawImage(frameCanvas, column * CELL_WIDTH, row.row * CELL_HEIGHT);
  }
}

function removeChromaKey(context) {
  const imageData = context.getImageData(0, 0, CELL_WIDTH, CELL_HEIGHT);
  const data = imageData.data;
  for (let index = 0; index < data.length; index += 4) {
    const dr = data[index] - CHROMA_KEY.r;
    const dg = data[index + 1] - CHROMA_KEY.g;
    const db = data[index + 2] - CHROMA_KEY.b;
    const distance = Math.sqrt(dr * dr + dg * dg + db * db);
    if (distance <= CHROMA_KEY.threshold || (data[index + 1] > 210 && data[index] < 90 && data[index + 2] < 90)) {
      data[index + 3] = 0;
    }
  }
  context.putImageData(imageData, 0, 0);
}

function clearRowOverridePreview() {
  if (!baseAtlasCanvas) {
    return;
  }
  currentAtlasCanvas = cloneCanvas(baseAtlasCanvas);
  activeSheetUrl = originalSheetUrl;
  if (overrideObjectUrl) {
    URL.revokeObjectURL(overrideObjectUrl);
    overrideObjectUrl = "";
  }
  atlasImage.src = activeSheetUrl;
  rowStripFile.value = "";
  overrideStatus.textContent = "Row override cleared. Showing the original package.";
  refreshAtlasState();
}

playPause.addEventListener("click", () => {
  playing = !playing;
  renderFrame();
  scheduleNextFrame();
});

firstFrame.addEventListener("click", () => {
  playing = false;
  frameIndex = 0;
  renderFrame();
  renderRowReview();
});

prevFrame.addEventListener("click", () => stepFrame(-1));
nextFrame.addEventListener("click", () => stepFrame(1));

lastFrame.addEventListener("click", () => {
  if (!activeRow) {
    return;
  }
  playing = false;
  frameIndex = activeRow.frames - 1;
  renderFrame();
  renderRowReview();
});

speedInput.addEventListener("change", () => {
  speed = Number(speedInput.value);
  scheduleNextFrame();
});

loopPlayback.addEventListener("change", () => {
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
    qaStatus.textContent = "Fail";
    qaStatus.className = "qa-status fail";
    manifestJson.textContent = error instanceof Error ? error.message : String(error);
  }
});

rowStripFile.addEventListener("change", async () => {
  const [file] = rowStripFile.files;
  if (!file) {
    return;
  }
  try {
    await applyRowOverride(file, overrideState.value);
  } catch (error) {
    overrideStatus.textContent = error instanceof Error ? error.message : String(error);
  }
});

clearOverride.addEventListener("click", clearRowOverridePreview);

document.addEventListener("keydown", (event) => {
  const target = event.target;
  if (target instanceof HTMLInputElement || target instanceof HTMLSelectElement || target instanceof HTMLTextAreaElement) {
    return;
  }
  if (event.key === " ") {
    event.preventDefault();
    playPause.click();
  } else if (event.key === "ArrowRight") {
    stepFrame(1);
  } else if (event.key === "ArrowLeft") {
    stepFrame(-1);
  } else if (/^[1-9]$/.test(event.key)) {
    const row = animationRows[Number(event.key) - 1];
    if (row) {
      selectState(row.state);
    }
  }
});

async function initialize() {
  await loadAnimationContract();
  renderStateButtons();
  await loadManifest(manifestUrl.value);
}

initialize().catch((error) => {
  frameStatus.textContent = "Load failed";
  qaStatus.textContent = "Fail";
  qaStatus.className = "qa-status fail";
  manifestJson.textContent = error instanceof Error ? error.message : String(error);
});
