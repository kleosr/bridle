#!/usr/bin/env node
// Deterministic shape check for AI-written code. Not a substitute for the repo's
// own tests: it catches generic naming, hard reloads, and data-layer slop.
// Usage: node quality-gate.mjs [paths...]   (no paths = files changed in git)
import { execSync } from 'node:child_process';
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { basename, extname, join } from 'node:path';

const SOURCE_EXTENSIONS = new Set(['.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs', '.sql', '.vue', '.svelte']);
const IGNORED_DIRS = new Set(['node_modules', '.git', '.next', 'dist', 'build', 'coverage', '.turbo', 'migrations', 'generated']);
const MAX_HANDWRITTEN_LINES = 300;

const GENERIC_FILE_NAMES = /^(utils?|helpers?|common|misc|lib|stuff|functions|service|manager|handler|component|main|new[-_]?\w*|temp|test\d*|my[-_]?\w+|\w+(2|final|new|copy|old))\.(t|j)sx?$/i;
const FRAMEWORK_ENTRY_FILES = /^(page|layout|route|loading|error|not-found|template|middleware|index|main)\.(t|j)sx?$/i;

const LINE_RULES = [
  { id: 'hard-reload', severity: 'error', pattern: /\b(window\.)?location\.reload\s*\(/, hint: 'Invalida el cache/query o revalida el tag del command (skill live-ui-sync).' },
  { id: 'hard-navigation', severity: 'error', pattern: /\b(window\.)?location\.(href|assign|replace)\s*[=(]\s*['"`]\//, hint: 'Usa el router del framework (<Link>, router.push) para rutas internas.' },
  { id: 'remount-key', severity: 'error', pattern: /key=\{\s*(Math\.random|Date\.now)\(/, hint: 'Una key aleatoria remonta el árbol en cada render; usa un id estable.' },
  { id: 'ts-any', severity: 'error', pattern: /(:\s*any\b|as\s+any\b|<any>)/, hint: 'Estrecha unknown con el schema en vez de any.' },
  { id: 'sql-concat', severity: 'error', pattern: /((?<![\w.)\]])`\s*(SELECT|INSERT|UPDATE|DELETE)\b[^`]*\$\{)|(['"]\s*(SELECT|INSERT|UPDATE|DELETE)\b[^'"]*['"]\s*\+)/i, hint: 'SQL parametrizado (tagged template sql`` o placeholders $1); nunca interpolar en un string plano.' },
  { id: 'select-star', severity: 'warn', pattern: /SELECT\s+\*\s+FROM/i, hint: 'Selecciona columnas explícitas: el DTO no debe cambiar si cambia la tabla.' },
  { id: 'redis-set-no-ttl', severity: 'warn', pattern: /\.set\(\s*[^)]*\)(?![^;]*\b(ex|px|EX|PX|exat|pxat|keepTtl)\b)/, requires: /redis|upstash/i, hint: 'Toda clave de cache necesita TTL (ex) salvo que sea fuente de verdad declarada.' },
  { id: 'force-dynamic', severity: 'warn', pattern: /export\s+const\s+dynamic\s*=\s*['"]force-dynamic['"]/, hint: 'force-dynamic como parche esconde una invalidación faltante; justifícalo.' },
  { id: 'ownerless-todo', severity: 'warn', pattern: /\/\/\s*(TODO|FIXME|HACK)(?!\s*\()/, hint: 'TODO(dueño): qué y por qué, o resuélvelo ahora.' },
  { id: 'console-log', severity: 'warn', pattern: /\bconsole\.log\(/, hint: 'Quita la instrumentación temporal o usa el logger de platform/.' },
  { id: 'generic-handler', severity: 'warn', pattern: /\b(const|function)\s+(handleClick|handleSubmit|handleChange|onClick|doSomething|processData|getData|fetchData|updateData)\b/, hint: 'El nombre debe decir el objeto: archiveModule, submitModuleRename…' },
  { id: 'generic-variable', severity: 'warn', pattern: /\b(const|let)\s+(data|result|res|item|obj|temp|tmp|val|stuff|info)\s*[=:]/, hint: 'Nombra por dominio: moduleRows, renameOutcome…' },
];

function runGit(command) {
  return execSync(command, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).split('\n').filter(Boolean);
}

function changedFilesFromGit() {
  try {
    runGit('git rev-parse --is-inside-work-tree');
  } catch {
    console.error('quality-gate: no es un repo git; pasa rutas explícitas.');
    process.exit(2);
  }
  let trackedChanges;
  try {
    trackedChanges = runGit('git diff --name-only --diff-filter=ACMR HEAD');
  } catch {
    trackedChanges = runGit('git diff --name-only --cached --diff-filter=ACMR'); // repo sin commits
  }
  return [...new Set([...trackedChanges, ...runGit('git ls-files --others --exclude-standard')])];
}

function expandPath(targetPath) {
  if (!existsSync(targetPath)) return [];
  if (!statSync(targetPath).isDirectory()) return [targetPath];
  return readdirSync(targetPath).flatMap((entry) =>
    IGNORED_DIRS.has(entry) ? [] : expandPath(join(targetPath, entry)),
  );
}

function isInspectable(filePath) {
  const segments = filePath.split(/[\\/]/);
  if (segments.some((segment) => IGNORED_DIRS.has(segment))) return false;
  return SOURCE_EXTENSIONS.has(extname(filePath)) && !/\.(d|gen|generated)\.ts$/.test(filePath);
}

function inspectFile(filePath) {
  const findings = [];
  const fileName = basename(filePath);
  if (GENERIC_FILE_NAMES.test(fileName) && !FRAMEWORK_ENTRY_FILES.test(fileName)) {
    findings.push({ line: 0, id: 'generic-file-name', severity: 'error', hint: 'Renombra con dominio + rol: parse-invoice-csv.ts, workspace-sidebar.tsx.' });
  }
  if (/^App\.(t|j)sx$/.test(fileName)) {
    findings.push({ line: 0, id: 'app-entry', severity: 'warn', hint: 'App.tsx solo si el framework lo exige y no existe otra entrada.' });
  }

  const source = readFileSync(filePath, 'utf8');
  const lines = source.split('\n');
  if (lines.length > MAX_HANDWRITTEN_LINES) {
    findings.push({ line: 0, id: 'file-too-long', severity: 'warn', hint: `${lines.length} líneas; divide por trabajo (máx ${MAX_HANDWRITTEN_LINES}).` });
  }
  lines.forEach((lineText, index) => {
    if (/quality-gate:\s*allow/.test(lineText)) return;
    for (const rule of LINE_RULES) {
      if (rule.requires && !rule.requires.test(source)) continue;
      if (rule.pattern.test(lineText)) findings.push({ line: index + 1, id: rule.id, severity: rule.severity, hint: rule.hint });
    }
  });
  return findings;
}

const requestedPaths = process.argv.slice(2);
const candidateFiles = (requestedPaths.length ? requestedPaths.flatMap(expandPath) : changedFilesFromGit())
  .filter((filePath) => existsSync(filePath) && isInspectable(filePath));

let errorCount = 0;
let warningCount = 0;
for (const filePath of candidateFiles) {
  for (const finding of inspectFile(filePath)) {
    if (finding.severity === 'error') errorCount += 1; else warningCount += 1;
    const location = finding.line ? `${filePath}:${finding.line}` : filePath;
    console.log(`${finding.severity.toUpperCase().padEnd(5)} ${finding.id.padEnd(18)} ${location}\n      → ${finding.hint}`);
  }
}

console.log(`\nquality-gate: ${candidateFiles.length} archivos, ${errorCount} errores, ${warningCount} advertencias.`);
process.exit(errorCount > 0 ? 1 : 0);
