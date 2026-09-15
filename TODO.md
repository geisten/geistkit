# geistkit – Plan und TODO

**Ziel:** Die geisten-Bausteine reproduzierbar bauen und gegen feste Vorgaben
verifizieren. Danach neue Programme daraus zusammensetzen.

**Prinzip:**
- `make fetch` ist der einzige Schritt mit Netz: Klone zu SHAs aus `versions.mk`.
- `make verify` baut und testet offline (`make ci` im Container mit `--network none`).
- Jeder Konsument holt seine Engine aus `build/deps/geistlib`, nie aus dem Internet.
- Ergebnis ist ein Vergleich der Messwerte mit `acceptance.tsv`.

**Befehle:**
- `make ci`: alles von null
- `make fetch-<projekt>`, `make test-<projekt>`: einzelnes Projekt
- `make selftest`: Selbsttest des Vergleichs

---

## Entscheidungen (15.09.2026)

| Thema | Entscheidung |
|---|---|
| Referenz-Engine | geistlib **v0.11.0** (`6781d42`). Abweichungen je Konsument in `ENGINE_*`, bis sie behoben sind |
| Pins | **SHA**, keine neuen Tags für geistshell und geist-memory. Vorhandene Tags werden gegen den SHA geprüft |
| Bekannte Fehler | **Gate bleibt rot, bis behoben.** Keine Ausnahmen in `acceptance.tsv` |
| C++-Header-Check | **Behalten und vereinheitlichen:** jede Bibliothek bekommt dasselbe `check-headers` (F5) |
| Reparaturen | **Per Pull Request in den Original-Repos.** geistkit trägt keine Patches |
| Testmodelle | **Qwen3.5-0.8B** (Q8_0, 780 MB) und **BitNet b1.58 2B-4T** (i2_s, ≈ 1,1 GB) |
| Nächtliche Tests | GitHub-hosted `ubuntu-24.04` unter geisten |
| CI für geistkit | GitHub Actions auf GitHub-hosted Runnern **und** eigenen Runnern: x86 = `amd-desktop`, Pi 5 (erst ab Freitag, 18.09., erreichbar) |
| Plattformen | **Linux x86_64 (primär)**, dazu Linux arm64 / Raspberry Pi 5 und **macOS: arm64 und Intel, Apple clang und brew llvm@19** |
| Engine nach den Fixes | Wenn F1 und F4 gemergt sind: neuer geistlib-Tag **v0.11.1**, der Lock wandert dorthin |
| C++-Macro | Ansatz in AGENT.md §1 akzeptiert. In geistshell **nur die öffentlichen Header** |
| PRs | Claude öffnet PRs mit `gh` unter dem Konto `geisten`. Review und Merge macht der User |
| Repo | **öffentlich** als `geisten/geistkit`, Apache-2.0 |

---

## Stand (15.09.2026)

**Letzter `make ci`:**
- Alle Builds und Tests liefen.
- Mit den neuen Vorgaben ist `verify` **rot**. Das ist beabsichtigt.

**Rot machen heute:**

| Vorgabe | Wert | Fix |
|---|---|---|
| `geistlib.asan.exit` | 2 (ASan-Build bricht ab) | F1 |
| `geistlib.asan.failed`, `.error` | fehlen | F1 |
| `geist-diktat.audit.exit` | 2 | F2 |

**Grün, aber mit Abweichung vom Lock:**
- geistshell baut mit Engine v0.10.1 (F3).
- geist-memory baut mit Engine `b78df97` plus Patch (F4).

---

## F-Plan – Fixes per Pull Request

Reihenfolge nach Aufwand und Nutzen. Jede Zeile „Nachweis“ wurde lokal im Toolchain-Container geprüft.

### F1 – geistlib: ASan auf x86 grün (Repo geistlib)

- [ ] **F1a** `tests/test_q8w_gemv_unit.c`: Rückgaben von `malloc` prüfen, per AGENT.md §3 über `src/base/heap.h`.
  - Ursache: gcc-14 meldet unter `-fsanitize` `-Werror=stringop-overread/overflow`, weil ungeprüfte Zeiger auf den Kernel-Aufruf treffen.
  - **Nachweis:** Mit Null-Prüfung vor den Aufrufen läuft der ASan-Build durch.
- [ ] **F1b** `test_x86_kernel_no_alloc_unit` meldet unter ASan „Q6_K: kernel did not write its whole output row“. Im Release-Build ist der Test grün.
  - **Nachweis:** Nach F1a der einzige verbleibende Fehler (39 bestanden, 24 übersprungen, 1 fehlgeschlagen).
  - Ursache offen, zuerst klären (Test oder Kernel?).
- [ ] **F1c** 16-MiB-Leck in `test_backend_cross_ref_unit` beheben (im Test selbst). Danach ASan ohne `detect_leaks=0`.
- [ ] **F1d** CI-Job „ASan x86_64, gcc-14“ in `geistlib/.github/workflows/ci.yml`. Heute läuft ASan nur auf arm64.
- **geistkit danach:** SHA des Merge-Commits prüfen, `ASAN_OPTIONS=detect_leaks=0` entfernen.
- **Hinweis:** Die neue Engine-Revision ist dann nicht mehr v0.11.0. Siehe offene Frage 4.

### F2 – geist-diktat: Audit grün (Repo geist-diktat)

- [ ] `tests/test_core.py:25`: denselben Feature-Macro wie das Makefile setzen (`-D_GNU_SOURCE`, das Makefile übernimmt ihn aus `geistlib/mk/target-linux.mk:87`).
  - Heute wird `core_stub.c` mit reinem `-std=c2x` gebaut, deshalb ist `strnlen` nicht deklariert (`src/diktat.c:85`).
  - **Nachweis:** `CC="gcc-14 -D_GNU_SOURCE"` ergibt 53 Tests OK, 3 übersprungen.
- [ ] Denselben Weg auf macOS prüfen (dort ist `_GNU_SOURCE` wirkungslos, `strnlen` ist vorhanden)
- **geistkit danach:** `SHA_geist-diktat` auf den Merge-Commit setzen.

### F3 – geistshell auf geistlib v0.11.0 (Repo geistshell)

- [ ] `src/model/model_adapter.c:326` und `:733`: `geist_session_peek_logits(&n_vocab, adapter->session)`. Die Argumentreihenfolge hat sich in v0.11.0 geändert.
- [ ] Verwaisten Gitlink `deps/geist` aus dem Index entfernen (`git rm --cached deps/geist`)
- [ ] `Makefile`: `GEIST_REF` auf den v0.11.0-SHA setzen. `sync-engine` soll den Ref bei jedem Lauf prüfen, wie `geist-diktat/scripts/sync-engine.sh`, statt „already present“ zu melden
- [ ] Race unter `make -j` beheben: Objekte kompilieren, bevor die Engine geklont ist (`geist.h` fehlt)
- [ ] Pin in `README.md` angleichen (steht auf v0.9.0)
- **Nachweis:** Nach Tausch der Argumente und Entfernen des Gitlinks gegen v0.11.0: Build ok, 61 bestanden, 1 übersprungen, 0 Host-Skips, Journal-Baseline ok (43 s).
- **geistkit danach:** `ENGINE_geistshell := $(SHA_geistlib)`.

### F4 – geist-memory an die Engine angleichen (Repos geistlib und geist-memory)

- [ ] Patch `patches/geistlib-compat.patch` (229 Zeilen) als **einzelne** PRs in geistlib, je einer pro Fix:
  - DOTPROD-Guard
  - Weight-Buffer 16/24
  - Leak (LSan auf dem Pi 5)
  - Clang-Warnung auf Intel-macOS
  - `geist_model_load_with_opts`
  - Tokenverlust bei OOM
- [ ] geist-memory: Race in `tools/check-repro.sh`. Das Skript erbt `-j` über MAKEFLAGS und startet `deps dist` parallel.
- [ ] geist-memory: `make -j deps check-deps` ist ebenso ein Race. `check-deps` braucht `deps` als Voraussetzung.
- [ ] `check-deps` erwartet `tools/fetch-dep.sh` in der Engine, das in v0.11.0 fehlt. Bis zu einem neuen geistlib-Stand bleibt `ENGINE_geist-memory` die Ausnahme.
- **geistkit danach:** Patch entfällt, `ENGINE_geist-memory := $(SHA_geistlib)`.

### F5 – Einheitlicher C/C++-Header-Check (Repos geistlib, geistshell, geist-memory, geistkit)

**Vertrag für jede Bibliothek:**
- `make check-headers` kompiliert jeden öffentlichen Header einzeln.
- Einmal als C23 (gcc-14 und clang-19), einmal als C++17 mit `-pedantic-errors`.
- Vorbild ist `geist-memory/Makefile:42–47`.
- geist-diktat ist eine Anwendung ohne öffentliche Header und damit nicht betroffen.

**Messung vom 15.09.:**

| Repo | Header ok in C23 | Header ok in C++17 | Ursache |
|---|---|---|---|
| geist-memory | 2/2 | 2/2 | – |
| geistlib | 6/6 | 3/6 (`geist.h`, `geist_types.h`, `geist_weight.h`) | 19× `T a[static n]`, dazu Array-Parameter mit Längenbezug |
| geistshell | 58/58 | 13/58 | 50× `[static n]`, rund 200 Array-Parameter mit Längenbezug |

Alle Header haben bereits `extern "C"`-Guards. Die Ursache ist allein die C-Syntax für Array-Parameter, die AGENT.md §1 bewusst vorschreibt.

- [ ] **F5a (geistlib)** Macro in `geist_types.h`: `GEIST_ALEN(n)` wird in C zu `static n`, in C++ zu nichts. Für längenabhängige Parameter entsprechend.
  - AGENT.md §1 um die Schreibweise ergänzen.
  - Gate nach §6: Die Präprozessor-Ausgabe für C bleibt identisch, also auch die Disassembly.
- [ ] **F5b (geistlib)** `check-headers` wie in geist-memory, in `make test` und in der CI
- [ ] **F5c (geistshell)** Dasselbe Macro (aus geistlib) in allen Headern von `include/geistshell/`. Mechanisch, aber groß: PRs je Modul (policy, journal, machine, model, eval, memory)
- [ ] **F5d (geistshell)** `check-headers` in `make test` und in der CI
- [ ] **F5e (geistkit)** Schritt `<projekt>.headers` für jedes Bibliotheks-Repo. Die Vorgabe `exit == 0` bleibt rot, bis F5a–F5d gemergt sind

### F6 – Testmodelle (Repos geistlib und geistkit)

**Heute in geistlib:**

| Modell | Größe | Pin |
|---|---|---|
| Qwen3-0.6B Q8_0 | 609 MB | SHA-256 (`fetch-qwen3-model`) |
| Qwen3.5-0.8B Q8_0 | 780 MB | SHA-256 (`fetch-qwen35-model`) |
| BitNet b1.58 2B-4T i2_s | ≈ 1,1 GB | **ohne SHA**, von `resolve/main` |

- [ ] **F6a (geistlib)** BitNet mit fester Hugging-Face-Revision und SHA-256 pinnen
- [ ] **F6b (geistlib)** Testmodell wählbar machen. Das Standardmodell der Tests ist heute Gemma 4 E2B (3,1 GB) und steckt in sieben Test-Targets. Messen, welche der 24 Unit-, 48 Integrations- und 9 e2e-Skips mit Qwen und BitNet wirklich laufen. Gemma-spezifische Tests für Vision und Audio bleiben sonst übersprungen.
- [ ] **F6c (geistkit)** Modelle mit URL und SHA-256 in `versions.mk`, `make fetch-models`, Cache in Actions über den SHA als Schlüssel
- [ ] **F6d (geistkit)** Profil „model“ (nächtlich): Zähler je Modell in `acceptance.tsv`, als Ratsche

### F7 – Upstream-Hygiene

- [ ] geist-memory: nächtlicher Lauf mit echtem Modell scheitert seit 5 Nächten am Modell-Download
- [ ] geist-diktat: Engine-Sync nicht beim Parsen des Makefiles, Skip bei fehlendem Modell nicht als exit 0
- [ ] geistshell: Pi-5-Workflow wurde 30-mal nach 24 h abgebrochen (kein Runner hat die Jobs angenommen)
- [ ] homebrew-tap von 0.6.0 auf v0.11.0

---

## CI-Plan für geistkit

| Plattform | Runner | Ausführung | Auslöser |
|---|---|---|---|
| Linux x86_64 | `ubuntu-24.04` (GitHub-hosted) | Docker-Image | Push, PR · nächtlich mit Qwen3.5-0.8B und BitNet |
| Linux x86_64 | `[self-hosted, amd-desktop]` | Docker-Image | Push auf main, nächtlich, manuell, **nie PR** |
| Linux arm64 | `ubuntu-24.04-arm` (GitHub-hosted) | Docker-Image (Digest ist Multi-Arch) | Push, PR |
| Raspberry Pi 5 | `[self-hosted, pi5]` (erst ab 18.09. erreichbar) | Docker oder nativ, `TARGET=pi5` | nächtlich, manuell, **nie PR** |
| macOS arm64 | `macos-15` (GitHub-hosted), Apple clang **und** brew llvm@19 | nativ, kein Docker verfügbar | Push, PR |
| macOS Intel | `macos-15-intel` (GitHub-hosted), Apple clang **und** brew llvm@19 | nativ | Push, PR |

- [ ] **C1** Makefile nach Plattform parametrisieren: `CC` (Linux gcc-14, macOS clang), `TARGET` (linux/pi5/mac), `GEMM_PROVIDER`. Heute sind `gcc-14` und `TARGET=linux` fest verdrahtet
- [ ] **C2** Toolchain-Protokoll auch nativ: Compiler-Version und SDK in `build/toolchain.txt`
- [ ] **C3** `.github/workflows/ci.yml` (Matrix wie oben) und `nightly.yml` (Modellprofil)
- [ ] **C4** Absicherung der eigenen Runner im öffentlichen Repo:
  - Jobs nie auf `pull_request` aus Forks
  - Freigabe für Außenstehende erzwingen
  - Runner-Gruppe nur für geistkit
  - Jobs im Container, möglichst ephemeral
  - Keine Secrets nötig
- [ ] **C5** `verify.txt`, `results.tsv` und Logs als Artefakt, Zusammenfassung im Job-Summary
- [ ] **C6** Gegenprobe „falscher Tag stoppt den Fetch“ automatisieren
- [ ] **C7** `JOBS` nach gemessenem Speicherbedarf setzen (heute 8; `-j32` mit ASan war zu viel)

---

## Später (unverändert)

- **P3 – Vorgaben maschinenlesbar:**
  - Produktkriterien (diktat WER, p95, RTF)
  - Benchmarks als `key value`
  - Median und Streuung
  - Regressionsvergleich
- **P4 – Sicherheit:**
  - Fuzzing für GGUF, safetensors, WAV und Tokenizer
  - geistshell: `realpath` für das Workdir, reservierte Memory-Namen, Isolation mit bwrap/Landlock/seccomp
- **P6 – Erstes neues Programm:**
  - Spec zuerst (Muster `geist-watch/PLAN.md`)
  - Abnahmekriterien in `acceptance.tsv`
  - Linken mehrerer Bausteine erst nach F3/F4
- **P7 – Selbstverbessernder Agent:**
  - Evaluator außerhalb der Schreibrechte
  - Hold-out-Suite
  - Archiv statt fester Mutationen
  - Hybrid-Modell, Codeänderungen nur mit Freigabe

---

## Pull Requests

| Fix | PR | Status |
|---|---|---|
| F2 | [geisten/geist-diktat#50](https://github.com/geisten/geist-diktat/pull/50) | offen, wartet auf Review |
| F1 | geistlib (ASan x86) | in Arbeit |
| F3 | geistshell (Engine v0.11.0, Pin, Race) | in Arbeit |
| F6a | geistlib (Modell-Revisionen und SHA-256) | in Arbeit |

**Nach jedem Merge:** SHA in `versions.mk` nachziehen und die Vorgaben in `acceptance.tsv` verschärfen.

## Offene Fragen

1. **Tag v0.11.1:** Setzt Claude ihn nach den Merges von F1 und F4 (nach Rückfrage), oder macht das der User?
