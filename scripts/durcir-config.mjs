// Fusionne config/durcissement.json dans ~/.automaton/automaton.json.
// Sans automaton.json (avant --setup), ne fait rien.
import fs from "node:fs";
import path from "node:path";

const here = path.dirname(new URL(import.meta.url).pathname);
const hardeningPath = process.env.CASHQC_DURCISSEMENT
  || path.join(here, "durcissement.json");
const configPath = path.join(process.env.HOME || "/root", ".automaton", "automaton.json");

if (!fs.existsSync(configPath)) {
  console.log("[cashqc] Pas encore d'automaton.json : rien à durcir pour l'instant.");
  process.exit(0);
}

const hardening = JSON.parse(fs.readFileSync(hardeningPath, "utf-8"));
const config = JSON.parse(fs.readFileSync(configPath, "utf-8"));

const merged = {
  ...config,
  ...hardening,
  treasuryPolicy: { ...(config.treasuryPolicy ?? {}), ...(hardening.treasuryPolicy ?? {}) },
};

fs.writeFileSync(configPath, JSON.stringify(merged, null, 2), { mode: 0o600 });
fs.chmodSync(configPath, 0o600);
console.log(`[cashqc] Durcissement appliqué à ${configPath}`);
