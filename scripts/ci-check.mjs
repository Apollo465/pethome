#!/usr/bin/env node
/**
 * 爪心（PetHome）静态检查。
 *
 * 为什么不是「跑一次 assembleHap」：HarmonyOS（非 OpenHarmony）的 SDK 与 hvigor
 * 工具链随 DevEco Studio 分发，需要华为账号登录才能下载，GitHub 托管的 runner
 * 上拿不到，因此公开仓库里无法做真实构建。这里做的是不需要 SDK、但能挡住大部分
 * 低级错误与合规回退的检查：
 *
 *   1. 所有 .json / .json5 能解析；
 *   2. app.json5 / module.json5 的必填字段与 $string/$media/$color/$profile 引用可解析；
 *   3. main_pages.json 里的页面、form_config.json 里的卡片页、ability 的 srcEntry 都存在；
 *   4. .ets 里所有 $r('app.xxx.yyy') 都能在模块资源里找到；
 *   5. 多语言 element/string.json 的键与 base 一致；
 *   6. 合规红线不回退：未声明网络权限、未残留已移除的云端 AI 字段；
 *   7. 防泄漏：已提交的文件里不含签名材料与私钥。
 *
 * 用法：node scripts/ci-check.mjs
 */

import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { dirname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const SKIP_DIRS = new Set([
  '.git', '.hvigor', '.idea', '.appanalyzer', '.preview', '.test', '.cxx',
  'node_modules', 'oh_modules', 'build',
]);

const errors = [];
const warnings = [];
const fail = (msg) => errors.push(msg);
const warn = (msg) => warnings.push(msg);
const ok = (msg) => console.log(`  ✔ ${msg}`);
const rel = (p) => relative(ROOT, p).split(sep).join('/');

function walk(dir, out = []) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      if (SKIP_DIRS.has(entry.name)) continue;
      walk(join(dir, entry.name), out);
    } else {
      out.push(join(dir, entry.name));
    }
  }
  return out;
}

/** 去掉 JSON5 的注释与尾逗号，剩下的按标准 JSON 解析（本项目没有用到未加引号的键）。 */
function stripJson5(text) {
  let out = '';
  let i = 0;
  while (i < text.length) {
    const c = text[i];
    if (c === '"' || c === "'") {
      out += c;
      i++;
      while (i < text.length) {
        const ch = text[i];
        out += ch;
        if (ch === '\\') {
          out += text[i + 1] ?? '';
          i += 2;
          continue;
        }
        i++;
        if (ch === c) break;
      }
      continue;
    }
    if (c === '/' && text[i + 1] === '/') {
      while (i < text.length && text[i] !== '\n') i++;
      continue;
    }
    if (c === '/' && text[i + 1] === '*') {
      i += 2;
      while (i < text.length && !(text[i] === '*' && text[i + 1] === '/')) i++;
      i += 2;
      continue;
    }
    out += c;
    i++;
  }
  return out.replace(/,(\s*[}\]])/g, '$1');
}

function readJson(file) {
  const text = readFileSync(file, 'utf8');
  try {
    return JSON.parse(file.endsWith('.json5') ? stripJson5(text) : text);
  } catch (e) {
    fail(`${rel(file)} 解析失败：${e.message}`);
    return null;
  }
}

/** 收集一个 resources 目录下 base 里的资源名，用于校验引用。 */
function resourceIndex(resRoot) {
  const index = { string: new Set(), color: new Set(), float: new Set(), media: new Set(), profile: new Set() };
  for (const [type, file] of [['string', 'string.json'], ['color', 'color.json'], ['float', 'float.json']]) {
    const p = join(resRoot, 'base', 'element', file);
    if (!existsSync(p)) continue;
    const parsed = readJson(p);
    for (const item of parsed?.[type] ?? []) index[type].add(item.name);
  }
  for (const sub of ['media', 'profile']) {
    const dir = join(resRoot, 'base', sub);
    if (!existsSync(dir)) continue;
    for (const f of readdirSync(dir)) index[sub].add(f.replace(/\.[^.]+$/, ''));
  }
  return index;
}

function checkRef(ref, index, where) {
  const [type, name] = ref.split(':');
  const set = index[type];
  if (!set) {
    fail(`${where}：未知资源类型 ${ref}`);
    return;
  }
  if (!set.has(name)) fail(`${where}：找不到资源 ${ref}`);
}

function checkRefsIn(value, index, where, key = '') {
  if (typeof value === 'string') {
    const m = /^\$([a-z]+):(.+)$/.exec(value);
    if (m) checkRef(`${m[1]}:${m[2]}`, index, `${where}${key ? ` (${key})` : ''}`);
    return;
  }
  if (Array.isArray(value)) {
    value.forEach((v, i) => checkRefsIn(v, index, `${where}[${i}]`));
    return;
  }
  if (value && typeof value === 'object') {
    for (const [k, v] of Object.entries(value)) checkRefsIn(v, index, where, k);
  }
}

const files = walk(ROOT);
const byExt = (ext) => files.filter((f) => f.endsWith(ext));

console.log('爪心（PetHome）静态检查\n');

// 1. 全部 JSON / JSON5 可解析
const jsonFiles = files.filter((f) => /\.json5?$/.test(f));
for (const f of jsonFiles) readJson(f);
if (!errors.length) ok(`${jsonFiles.length} 个 .json/.json5 文件全部解析通过`);

// 2. app.json5（应用级资源在 AppScope/resources）
const appFile = join(ROOT, 'AppScope', 'app.json5');
const appIndex = resourceIndex(join(ROOT, 'AppScope', 'resources'));
if (existsSync(appFile)) {
  const app = readJson(appFile)?.app;
  if (app) {
    for (const key of ['bundleName', 'versionCode', 'versionName', 'icon', 'label']) {
      if (app[key] === undefined) fail(`AppScope/app.json5 缺少 app.${key}`);
    }
    checkRefsIn(app, appIndex, 'AppScope/app.json5');
    ok(`AppScope/app.json5：${app.bundleName} ${app.versionName}(${app.versionCode})，图标与名称引用可解析`);
  }
}

// 3. entry/src/main/module.json5
const moduleDir = join(ROOT, 'entry', 'src', 'main');
const moduleFile = join(moduleDir, 'module.json5');
const moduleIndex = resourceIndex(join(moduleDir, 'resources'));
let moduleJson = null;
if (existsSync(moduleFile)) {
  moduleJson = readJson(moduleFile)?.module;
  if (moduleJson) {
    checkRefsIn(moduleJson, moduleIndex, 'entry/src/main/module.json5');

    const abilities = [...(moduleJson.abilities ?? []), ...(moduleJson.extensionAbilities ?? [])];
    for (const ability of abilities) {
      const entry = ability.srcEntry?.replace(/^\.\//, '');
      if (!entry) fail(`module.json5：${ability.name} 缺少 srcEntry`);
      else if (!existsSync(join(moduleDir, entry))) fail(`module.json5：${ability.name} 的 srcEntry 不存在 ${entry}`);
    }
    ok(`${abilities.length} 个 ability / extensionAbility 的 srcEntry 都存在`);
  }
}

// 4. 页面与卡片页
const pagesFile = join(moduleDir, 'resources', 'base', 'profile', 'main_pages.json');
if (existsSync(pagesFile)) {
  const pages = readJson(pagesFile)?.src ?? [];
  for (const page of pages) {
    if (!existsSync(join(moduleDir, 'ets', `${page}.ets`))) fail(`main_pages.json：页面文件不存在 ets/${page}.ets`);
  }
  ok(`${pages.length} 个页面都能找到对应的 .ets`);
}
const formFile = join(moduleDir, 'resources', 'base', 'profile', 'form_config.json');
if (existsSync(formFile)) {
  const forms = readJson(formFile)?.forms ?? [];
  for (const form of forms) {
    const src = form.src?.replace(/^\.\//, '');
    if (src && !existsSync(join(moduleDir, src))) fail(`form_config.json：${form.name} 的 src 不存在 ${src}`);
  }
  ok(`${forms.length} 个桌面卡片的 src 都存在`);
}

// 5. .ets 里的 $r('app.xxx.yyy') 引用
let refCount = 0;
for (const file of byExt('.ets')) {
  const text = readFileSync(file, 'utf8');
  for (const m of text.matchAll(/\$r\(\s*['"]([^'"]+)['"]\s*\)/g)) {
    const ref = m[1];
    if (!ref.startsWith('app.')) continue;
    const [, type, name] = ref.split('.');
    refCount++;
    checkRef(`${type}:${name}`, moduleIndex, rel(file));
  }
}
if (refCount) ok(`${refCount} 处 $r('app.*') 资源引用都能在 entry 资源里找到`);

// 6. 多语言资源键与 base 保持一致
const resRoot = join(moduleDir, 'resources');
for (const locale of readdirSync(resRoot, { withFileTypes: true }).filter((e) => e.isDirectory() && e.name !== 'base').map((e) => e.name)) {
  for (const [type, file] of [['string', 'string.json'], ['color', 'color.json'], ['float', 'float.json']]) {
    const basePath = join(resRoot, 'base', 'element', file);
    const localePath = join(resRoot, locale, 'element', file);
    if (!existsSync(basePath) || !existsSync(localePath)) continue;
    const baseKeys = new Set((readJson(basePath)?.[type] ?? []).map((i) => i.name));
    const localeKeys = new Set((readJson(localePath)?.[type] ?? []).map((i) => i.name));
    const missing = [...baseKeys].filter((k) => !localeKeys.has(k));
    if (missing.length) fail(`${locale}/element/${file} 缺少 ${type}：${missing.join(', ')}`);
  }
}
ok('多语言资源键与 base 一致');

// 7. 合规红线
if (moduleJson) {
  const permissions = (moduleJson.requestPermissions ?? []).map((p) => typeof p === 'string' ? p : p.name);
  const net = permissions.find((p) => /INTERNET|GET_NETWORK_INFO|NETWORK/i.test(p ?? ''));
  if (net) fail(`module.json5 声明了网络权限 ${net}，与「不联网的单机应用」定位冲突`);
  else ok(`未声明网络权限（当前权限：${permissions.join(', ') || '无'}）`);
}
const removedAiFields = ['cloudApiKey', 'cloudBaseUrl', 'cloudEnabled', 'AiService'];
for (const file of byExt('.ets')) {
  const text = readFileSync(file, 'utf8');
  for (const field of removedAiFields) {
    if (text.includes(field)) fail(`${rel(file)} 里出现了已在 v1.0.0 移除的云端 AI 字段 ${field}`);
  }
}
ok('entry 源码里没有残留的云端 AI 字段');

// 8. 防泄漏：只看已提交的文件
let tracked = null;
try {
  tracked = execFileSync('git', ['-c', 'core.quotepath=false', 'ls-files'], { cwd: ROOT, encoding: 'utf8' })
    .split('\n').map((s) => s.trim()).filter(Boolean);
} catch {
  warn('没找到 git，跳过「已提交文件」的泄漏检查');
}
if (tracked) {
  const signingExt = /\.(p12|pfx|jks|keystore|bks|key|pem|cer|p7b)$/i;
  for (const f of tracked) {
    if (signingExt.test(f)) fail(`签名材料不应该提交进仓库：${f}`);
    if (f.startsWith('signing/')) fail(`signing/ 目录不应该提交进仓库：${f}`);
  }
  const textExt = /\.(md|txt|json5?|ets|ts|mjs|js|ps1|py|html|csr|properties)$/i;
  for (const f of tracked.filter((f) => textExt.test(f))) {
    const text = readFileSync(join(ROOT, f), 'utf8');
    if (/-----BEGIN [A-Z ]*PRIVATE KEY-----/.test(text)) fail(`${f} 里含私钥内容`);
  }
  for (const cfg of ['build-profile.json5', join('entry', 'build-profile.json5').replace(sep, '/')]) {
    const p = join(ROOT, cfg);
    if (!existsSync(p)) continue;
    const parsed = readJson(p);
    if (parsed?.app?.signingConfigs?.length) fail(`${cfg} 的 signingConfigs 不为空，生产签名配置不应该入库`);
    if (/password/i.test(stripJson5(readFileSync(p, 'utf8')))) fail(`${cfg} 解析后仍含密码字段`);
  }
  ok(`${tracked.length} 个已提交文件里没有签名材料 / 私钥 / 明文密码`);
}

console.log('');
for (const w of warnings) console.log(`  ! ${w}`);
if (errors.length) {
  console.log(`\n检查未通过，共 ${errors.length} 个问题：`);
  for (const e of errors) console.log(`  ✘ ${e}`);
  process.exit(1);
}
console.log('检查全部通过 ✔');
