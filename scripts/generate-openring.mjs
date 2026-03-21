import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");

const openringDir = path.join(repoRoot, "openring");
const feedsPath = path.join(openringDir, "feeds.txt");
const templatePath = path.join(openringDir, "template.html");
const outPath = path.join(openringDir, "out.html");

const fallbackHtml = `<section class="space-y-2">
  <h2 class="text-2xl font-bold">Around the web</h2>
  <p class="text-sm text-muted-foreground">Install <code>openring</code> and run <code>bun run openring:generate</code> to render this section.</p>
</section>
`;

await mkdir(openringDir, { recursive: true });

try {
  const template = await readFile(templatePath, "utf8");

  const result = spawnSync("openring", ["-S", feedsPath], {
    input: template,
    encoding: "utf8",
    maxBuffer: 10 * 1024 * 1024,
  });

  if (result.error) {
    if (result.error.code === "ENOENT") {
      console.warn("[openring] binary not found; writing fallback HTML.");
      await writeFile(outPath, fallbackHtml, "utf8");
      process.exit(0);
    }
    throw result.error;
  }

  if (result.status !== 0) {
    console.warn(`[openring] command failed (exit ${result.status}); writing fallback HTML.`);
    if (result.stderr) {
      console.warn(result.stderr.trim());
    }
    await writeFile(outPath, fallbackHtml, "utf8");
    process.exit(0);
  }

  await writeFile(outPath, result.stdout, "utf8");
  console.log("[openring] generated openring/out.html");
} catch (error) {
  console.warn("[openring] unexpected error; writing fallback HTML.");
  console.warn(error instanceof Error ? error.message : String(error));
  await writeFile(outPath, fallbackHtml, "utf8");
}
