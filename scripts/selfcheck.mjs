// 补丁状态自检：直接调用插件自己的 patchStatus，口径与面板一致。
import * as core from "../lib/core.js";

const aiBase = process.argv[2];
if (!aiBase) {
  console.log("FAIL patch-status 缺少 aiBase 参数");
  process.exit(2);
}

let status;
try {
  status = await core.patchStatus(aiBase);
} catch (e) {
  console.log(`FAIL patch-status ${e && e.message ? e.message : e}`);
  process.exit(2);
}

const ids = Object.keys(status);
const count = (v) => ids.filter((id) => status[id] === v).length;
const applied = count("applied");
const pending = count("pending");
const skipped = count("skipped");
const missing = count("missing_file");
const notFound = count("not_found");

const rows = core.groupPatchesForDisplay(core.ALL_PATCHES, status, "desktop");
const shown = new Set(rows.flatMap((r) => r.ids));
const hidden = [6, 30, 31].filter((id) => !shown.has(id));

console.log(`${pending === 0 ? "PASS" : "FAIL"} patches applied=${applied} pending=${pending} skipped=${skipped} missing=${missing} not_found=${notFound} defs=${core.ALL_PATCHES.length} rows=${rows.length}`);
console.log(`${hidden.length === 3 ? "PASS" : "FAIL"} windows-inert hidden=${hidden.join(",") || "none"}`);
if (pending > 0) {
  const list = ids.filter((id) => status[id] === "pending");
  console.log(`  pending ids: ${list.join(",")}`);
}
process.exit(pending === 0 && hidden.length === 3 ? 0 : 1);
