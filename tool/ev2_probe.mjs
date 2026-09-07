import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const wasmPath = path.join(__dirname, 'ev2-decrypt.wasm');

function i64Pair(value) {
  const big = BigInt(value);
  return [Number(big & 0xffffffffn), Number(big >> 32n)];
}

class WasmBuffer {
  constructor(memory) {
    this.memory = memory;
    this.view = () => new Uint8Array(memory.buffer);
  }

  getBuffer(ptr, len) {
    return this.view().slice(ptr, ptr + len);
  }
}

class Ev2Wasm {
  constructor(memory) {
    this.memory = memory;
    this.buffer = new WasmBuffer(memory);
    this.instance = null;
  }

  async load() {
    const wasm = fs.readFileSync(wasmPath);
    const imports = {
      env: {
        emscripten_memcpy_js: (dst, src, len) => {
          const view = this.view();
          view.copyWithin(dst >>> 0, src >>> 0, (src >>> 0) + (len >>> 0));
        },
      },
    };
    const { instance } = await WebAssembly.instantiate(wasm, imports);
    this.instance = instance;
    this.exports = instance.exports;
  }

  view() {
    return new Uint8Array(this.memory.buffer);
  }

  call(name, args) {
    const fn = this.exports[name];
    if (!fn) throw new Error(`missing export ${name}`);
    return fn(...args);
  }

  malloc(size) {
    return this.call('malloc_buffer', [size]);
  }

  free(ptr) {
    this.call('free_buffer', [ptr]);
  }

  copyIn(data, ptr) {
    this.view().set(data, ptr);
  }

  init(fileSize, tail112) {
    const ptr = this.malloc(tail112.length);
    this.copyIn(tail112, ptr);
    this.call('init', [...i64Pair(fileSize), ptr, tail112.length]);
    this.free(ptr);
    if (ret < 0) throw new Error(`init failed: ${ret}`);
  }

  decryptChunk(data, offset) {
    const ptr = this.malloc(data.length);
    this.copyIn(data, ptr);
    this.call('decrypt', [ptr, data.length, ...i64Pair(offset)]);
    if (ret < 0) throw new Error(`decrypt failed: ${ret}`);
    const out = this.buffer.getBuffer(ptr, data.length);
    this.free(ptr);
    return Buffer.from(out);
  }

  destroy() {
    this.call('destroy', []);
  }
}

async function convertEv2(inputPath, outputPath) {
  const file = fs.readFileSync(inputPath);
  const fileSize = file.length;
  if (fileSize < 112) throw new Error('file too small');

  const tail = file.subarray(fileSize - 112);
  const memory = new WebAssembly.Memory({ initial: 100, maximum: 400 });
  const ev2 = new Ev2Wasm(memory);
  await ev2.load();
  ev2.init(fileSize, tail);

  const chunkSize = 1024 * 1024;
  const out = fs.createWriteStream(outputPath);
  for (let offset = 0; offset < fileSize; offset += chunkSize) {
    const end = Math.min(offset + chunkSize, fileSize);
    const chunk = file.subarray(offset, end);
    const plain = ev2.decryptChunk(chunk, offset);
    out.write(plain);
  }
  out.end();
  ev2.destroy();

  const magic = fs.readFileSync(outputPath, { start: 0, end: 4 });
  console.log('output magic', magic.toString('hex'), magic.toString('ascii', 0, 3));
}

const input = process.argv[2];
const output = process.argv[3] ?? input + '.flv';
if (!input) {
  console.error('usage: node ev2_probe.mjs <file.ev2> [out.flv]');
  process.exit(1);
}

convertEv2(input, output).catch((e) => {
  console.error(e);
  process.exit(1);
});
