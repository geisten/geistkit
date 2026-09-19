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
| PRs | Claude öffnet PRs mit `gh` unter dem Konto `geisten`. **Seit 17.09.: Claude mergt auch**, sobald ein PR grün ist. Grün heißt: kein roter Check, der auf den PR selbst zurückgeht. Fremdursachen sind der Vulkan-Job (Treiber-Mismatch auf amd-desktop), der coverage ratchet (Modell-Cache, F10) und die vorbestehenden nvim-Fehler in diktat (F9) |
| Repo | **öffentlich** als `geisten/geistkit`, Apache-2.0 |

---

## Stand (15.09.2026)

**Letzter `make ci`** (17.09., nach den ersten fünf Merges, Profil `linux-x86_64-avx512`):

| Vorgabe | Wert | Fix |
|---|---|---|
| `geistlib.asan.exit` | 2 (ASan-Build bricht ab) | F1, F1e |
| `geistlib.asan.failed`, `.error` | fehlen | F1, F1e |

Alles andere ist grün: geistlib unit 40/24/0, geistshell 61/1/0, geist-memory alle sechs Schritte, geist-diktat Build, Smoke **und Audit** (F2 gemergt).

**Lock nachgezogen:** `SHA_geistshell` auf `4e97b60b`, `SHA_geist-diktat` auf `98525d23` (kein Tag mehr, main ist hinter v0.2.0 weitergelaufen). **Die Ausnahme `ENGINE_geistshell` entfällt:** geistshell und geist-diktat bauen beide gegen `6781d42` (v0.11.0), lokal bestätigt.

**Verbleibende Abweichung vom Lock:** geist-memory baut mit Engine `b78df97` plus Patch (F4).

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

### F8 – geistlib auf macOS Intel (Repo geistlib), gefunden durch geistkit#1

- [ ] `src/base/hw_probe.c:58`: `sysctl_bool` ist unter `__APPLE__` definiert, wird aber nur im aarch64-Zweig benutzt (Z. 135/136). Auf `macos-15-intel` bricht der Build mit Apple clang 17 und mit llvm@19 an `-Werror,-Wunused-function` ab.
  - **Fix:** Die Definition genauso bedingen wie die Nutzung.
- [ ] macOS-Intel-Job in der geistlib-CI. Heute fehlt er. geist-memory baut die Engine ohne `-Werror`, deshalb fiel der Fehler dort nicht auf.
- **geistkit danach:** In `acceptance.d/darwin-x86_64.tsv` die gemessenen Zähler eintragen.

### F9 – geist-diktat: quality-audit `contracts` auf main rot (Repo geist-diktat), gefunden bei der Prüfung von #50

Nachgestellt mit `tests/ubuntu.Dockerfile`, ohne Netz. Die Fehler sind auf `origin/main` und im PR-Branch identisch. Der Workflow läuft nur bei PRs auf bestimmte Pfade, deshalb gab es auf main nie einen roten Lauf. Befund: [#50, Kommentar](https://github.com/geisten/geist-diktat/pull/50#issuecomment-5686026515).

Genauer Stand: **10 Fehler**, nicht 4. `nvim_contract.lua` scheitert in 8 von 13 Prüfungen, `ibus_lifecycle` in 2 von 12.

- [x] ibus (2 Fehler) und Push-Trigger für quality-audit: [geist-diktat#51](https://github.com/geisten/geist-diktat/pull/51). Child-Watch sammelt den Gruppenleiter ein und setzt `e->pid` zurück, `pipeline_stop` ist idempotent. Nachweis: 12/12, dazu 100 Start/Stop- und 100 EOF-Zyklen ohne übrige Kindprozesse.
- [ ] nvim (8 Fehler): Produktarbeit, bereits als Issues erfasst. #19 Zeilenpuffer für fragmentierte stdout-Zeilen und getrenntes UTF-8 (`lua/geist-diktat/init.lua:62`), #20 Sitzungsgeneration statt einem `job`-Handle, #24 Commandline-Queue und verschluckte Fehler.
- [ ] Nirgends erfasst: „binary path shell-quoted“. `init.lua:34` maskiert `model`, aber nicht `binary`. Issue anlegen?
- **Folge:** `contracts` bleibt rot, bis #19, #20 und #24 behoben sind. Durch den neuen Push-Trigger ist das auf main sichtbar.
- **geistkit:** Später `make test-ubuntu` als eigenen Container-Schritt aufnehmen (GTK/Qt/IBus unter Xvfb). Heute nicht Teil der Pipeline.

### Plattform-Befunde aus geistkit#1 (15.09.)

| Profil | Runner | geistlib unit | geistshell | Rot durch |
|---|---|---|---|---|
| `linux-x86_64-avx512` | amd-desktop (lokal) | 40 / 24 / 0 | 61 / 1 / 0 | F1 (ASan), F2 (Audit) |
| `linux-x86_64` | ubuntu-24.04 | 39 / 25 / 0 (ohne AVX-512) | 61 / 1 / 0 | F1, F2 |
| `linux-aarch64` | ubuntu-24.04-arm | 31 / 23 / 0, ASan 31 / 23 / 0 | 61 / 1 / 0 | F2 |
| `darwin-arm64` | macos-15, beide Compiler | 31 / 23 / 0, ASan 31 / 23 / 0 | 60 / 2 / Host-Skip 1 (von geistshell erlaubt) | – nach geistkit-Fix |
| `darwin-x86_64` | macos-15-intel, beide Compiler | baut nicht | Folgefehler | F8 |

- **geistkit-Fix (kein Upstream-Defekt):** Die ASan-Targets `test-model-alloc` und `test-tokenizer-oom` von geist-memory brauchen GNU ld `--wrap`. geistkit lässt sie auf Darwin weg, wie die macOS-CI von geist-memory selbst.
- **Infrastruktur:** Der Job „Vulkan backend (discrete GPU)“ in geistlib ist in allen PRs rot. Auf amd-desktop passen NVIDIA-Kernel-Modul (595.84) und Userspace (595.91) nicht zusammen. **Neustart des Rechners nötig.**

### F10 – geistlib: Cache-Politik für Modelle (Repo geistlib)

Gemessen am 17.09.: **9,5 von 10 GB belegt, 46 Einträge.** Jeder PR legt eine eigene Kopie an: Gemma 2,8 GB je PR (#416, #417), Qwen3 0,57 GB je PR (#415, #416, #417), SmolLM2 0,34 GB je PR. Für `main` gibt es **keine** Gemma-Kopie mehr. Folge: Jobs werden ohne Codefehler rot, siehe #413, #414, #417.

- [ ] Modell-Caches nur auf `main` schreiben, PRs nur lesen (`actions/cache/restore` mit `lookup-only`/`restore-keys`, `actions/cache/save` nur bei Push auf main)
- [ ] Alternativ oder zusätzlich: Modelle nicht cachen, sondern über den SHA-256-Pin aus F6a frisch laden (Gemma 3,1 GB in etwa 30 s gemessen)
- [ ] Sofortmaßnahme durch den User: alte PR-Caches löschen, `gh cache list -R geisten/geistlib`, dann `gh cache delete <key>`
- **Zusammenhang:** #413 behebt nur die Folge (Fetch-Schritt), nicht die Ursache.

### F7 – Upstream-Hygiene

- [ ] geist-memory: nächtlicher Lauf mit echtem Modell scheitert seit 5 Nächten am Modell-Download
- [ ] geist-diktat: Engine-Sync nicht beim Parsen des Makefiles, Skip bei fehlendem Modell nicht als exit 0
- [ ] geistshell: Pi-5-Workflow wurde 30-mal nach 24 h abgebrochen (kein Runner hat die Jobs angenommen)
- [ ] homebrew-tap von 0.6.0 auf v0.11.0
- [ ] geistlib: `bench_q4k_kernel` steht in `CBLAS_REF_TESTS` und `NEON_KERNEL_TESTS` und ist deshalb auf x86 nicht baubar, obwohl der Kernel dort läuft. Gefunden bei F1e, das musste auf `bench_perf_sweep` ausweichen.

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
| F2 | [geisten/geist-diktat#50](https://github.com/geisten/geist-diktat/pull/50) | **gemergt** (17.09.). quality-audit `contracts` bleibt rot, war aber schon auf main rot (→ F9) |
| F1 | [geisten/geistlib#414](https://github.com/geisten/geistlib/pull/414) | **gemergt** (17.09.). Nur Tests, CI und Doku. Ursprünglich blockiert: Der neue Job hat einen echten Defekt gefunden (siehe F1e), und der coverage ratchet braucht #413 |
| F1e | [geisten/geistlib#417](https://github.com/geisten/geistlib/pull/417) | **gemergt** (17.09.). ASan instrumentierte den Prolog der AVX-512-TU EVEX-codiert, also vor dem Guard in `kernel_q4kx8_gemm_avx512_full.c:815`; auf CPUs ohne AVX-512 gibt das SIGILL. Fix: Guard und Shape-Dispatch liegen in der TU ohne `-mavx512*`, das Panel bleibt als `q4kx8_gemm16x16_avx512_bulk()`. Nachweise: qemu ohne AVX-512 vorher Exit 132, jetzt 0 · EVEX in der Einsprungfunktion 2 → 0 · Tile-Kernel unverändert 1315 Befehle · Release-Suite 39/24/0 · Sweep ohne Regression. CI: TSan und AVX-512-Build grün, rot nur Vulkan (Infrastruktur) und coverage ratchet (Modell-Cache, siehe F10). **Reihenfolge:** vor #414 mergen |
| F5a | [geisten/geistlib#416](https://github.com/geisten/geistlib/pull/416) | **gemergt** (17.09.). `GEIST_AT_LEAST(n)`, alle 6 Header auch in C++17 nutzbar, `make check-headers` in Test und CI. Nachweis: C-Tokenstrom identisch, `libgeist.a` bit-gleich. Nebenbei das Release-Gate korrigiert, das den von §6 geforderten CHANGELOG-Eintrag verbot. 20 von 21 Jobs grün |
| F9 | [geisten/geist-diktat#51](https://github.com/geisten/geist-diktat/pull/51) | **gemergt** (17.09.). ibus-Lifecycle 12/12, quality-audit läuft jetzt auch bei Push auf main. Die 8 nvim-Prüfungen bleiben rot (Issues #19, #20, #24) |
| F3 | [geisten/geistshell#148](https://github.com/geisten/geistshell/pull/148) | **gemergt** (17.09.): API v0.11.0, SHA-Pin, Gitlink weg, `scripts/sync-engine.sh`, Race behoben (vorher 3/3 fehlgeschlagen, jetzt 3/3 grün) |
| F6a | [geisten/geistlib#413](https://github.com/geisten/geistlib/pull/413) | **gemergt** (17.09.): BitNet, Qwen3.5, Qwen3 und SmolLM2 per HF-Revision und SHA-256. Dazu `8668bbb`: coverage-Job lädt Gemma nach, statt sich auf den Cache zu verlassen (Cache 8,4 von 10 GB, pro PR 3 GB). Vulkan-GPU-Job rot durch Infrastruktur |
| F8 | [geisten/geistlib#415](https://github.com/geisten/geistlib/pull/415) | **gemergt** (17.09.). macOS-Intel-Job grün. Umfang größer als geplant, 6 Commits: `hw_probe.c`; mac-Targets auf x86_64 mit `cpu_x86`; CI-Leg `macos-15-intel`; clang-x86-Fixes in `audio_linear.c` (VNNI), `ptqtp_kernel.c`, `elementwise.c`. Nachweise nach §6: bitgleich, Opcode-Folgen gleich, Laufzeit im Rauschen |
| C1–C5 | [geisten/geistkit#1](https://github.com/geisten/geistkit/pull/1) | **gemergt** (17.09.). 2. Lauf: macOS arm64 grün, übrige Legs rot nur durch F1, F2, F8 |

**Gehostete x86-Runner:** Der CPU-Pool ist gemischt, mal mit, mal ohne AVX-512. Die Profil-Erkennung wählt pro Lauf `linux-x86_64` oder `linux-x86_64-avx512`, beide Profile werden gebraucht.

**Runner:** `geisten_amd_nvidea-gk` ist für geistkit registriert (`~/actions-runner-geistkit`). Der Dienst muss noch mit sudo installiert werden. Pi 5: ab 18.09. eine eigene geistkit-Runner-Instanz registrieren, dann die Repo-Variable `PI5_RUNNER=on` setzen.

**Nach jedem Merge:** SHA in `versions.mk` nachziehen und die Vorgaben in `acceptance.tsv` verschärfen.

## Offene Fragen

1. **Tag v0.11.1:** Setzt Claude ihn nach den Merges von F1 und F4 (nach Rückfrage), oder macht das der User?

**Stand 17.09. (überholt, siehe unten), alle neun PRs gemergt:** geistlib `main` = `559a1173` (enthält #413, #414, #415, #416, #417), geistshell `4e97b60b`, geist-diktat `98525d23`, geistkit `main`.

- **Der Lock zeigt weiter auf v0.11.0.** Alle geistlib-Fixes stecken in `main`, nicht im Tag. Deshalb bleibt der ASan-Schritt bei uns rot, bis der Tag **v0.11.1** existiert und der Lock dorthin wandert. Laut Entscheidung erst, wenn auch F4 durch ist.
- `ASAN_OPTIONS=detect_leaks=0` ist aus dem geistkit-Makefile entfernt, weil F1c das Leck behoben hat. Wirksam wird das mit dem Lock-Bump.
- **Fremder offener PR:** geist-diktat#41 „test: Plattform-Audit, deutsche WER und Produktfahrplan“ (Branch `codex/quality-audit-20260905`, vom 05.09.). Nicht von uns, nicht angefasst.

---

## Stand 18.09.: alle zwölf PRs gemergt, Lock auf geistlib `main`

`SHA_geistlib := 18a52c30` (v0.11.0-64), `TAG_geistlib := -`. **Kein Release 0.11.1**, Entscheidung des Users: In geistlib entstehen Tags ausschließlich über `release.yml` (`workflow_dispatch`), der die Version gegen `include/geist.h` prüft, die SDK-Artefakte baut und Tag **und** Release veröffentlicht. Ein handgesetztes Tag würde diese Konvention brechen. Der Tag v0.11.0 trägt außerdem `tools/fetch-dep.sh` nicht im Baum — in `main` ist sie vorhanden.

**Gemessen mit dem neuen Lock (`make ci`, Profil `linux-x86_64-avx512`, 179 s):**

| Schritt | Ergebnis |
|---|---|
| geistlib unit | 40 bestanden / 24 übersprungen / 0 fehlgeschlagen |
| geistlib **ASan/UBSan mit Leak-Erkennung** | 40 / 24 / 0, Exit 0 — F1, F1c und F1e wirken, `detect_leaks=0` ist entfernt |
| geistlib py, contract | grün |
| geistshell | 61 / 1 / 0, Journal-Baseline grün, Engine = Referenz |
| geist-diktat | Build, Smoke und Audit grün, Engine = Referenz |
| geist-memory | **rot**, siehe unten |

ASan-Zähler sind jetzt in `acceptance.d/linux-x86_64-avx512.tsv` (≥ 40 / ≤ 24) und `acceptance.d/linux-x86_64.tsv` (≥ 39 / ≤ 25) verankert.

**geist-memory ist rot, und zwar richtig so:** `make deps` scheitert, weil `patches/geistlib-compat.patch` auf `18a52c30` nicht mehr anwendbar ist — genau an `src/base/hw_probe.c`, `src/engine/model.c` und `src/engine/gguf_tokenizer.c`, deren Fixes inzwischen upstream sind (#415, #418, #419, #420). Die drei Folgefehler (asan, install, repro) hängen an der fehlenden Stempeldatei. Behoben wird das durch den PR `build/drop-engine-patch` in geist-memory (F4b, in Arbeit), danach `SHA_geist-memory` nachziehen.

**Zwei neue Befunde für die Liste:**
- Unser Toolchain-Image enthält **kein `clang-format`**. Die geistlib-CI pinnt Version 22.1.5 per pip, das Gate ist bei uns also nicht abgedeckt. Für geistkit nachrüsten oder bewusst offenlassen.
- Tags in geistlib sind Release-Ereignisse, kein `git tag`. Das gehört in die Entscheidungstabelle, falls später doch v0.11.1 gefahren wird: erst Versionsbump in `include/geist.h` plus CHANGELOG, dann `release.yml`.

---

## 19.09.: Gate erstmals vollständig grün

`make ci` → **Exit 0** in 315 s, Profil `linux-x86_64-avx512`, alle 11 Vorgaben erfüllt.

| Projekt | Lock | Engine | Ergebnis |
|---|---|---|---|
| geistlib | `18a52c30` (main, v0.11.0-64) | – | unit 40/24/0 · **ASan/UBSan mit Leak-Erkennung 40/24/0** · py · contract |
| geistshell | `5c8a9761` | `18a52c3` | 61/1/0, Journal-Baseline grün |
| geist-memory | `b29243de` | `18a52c3` | alle 6 Schritte, **ohne Engine-Patch** |
| geist-diktat | `98525d23` | `18a52c3` | Build, Smoke, Audit |

**Damit ist P1 erreicht:** eine Engine für alle, kein Patch, keine Ausnahme in `ENGINE_*`. geistshell und geist-memory pinnen diese Revision inzwischen selbst.

**15 PRs gemergt:** geistlib #413–#420, geistshell #148 und #149, geist-diktat #50 und #51, geist-memory #5, geistkit #1.

### Neue Befunde, noch offen

- [ ] **`test_cli_device` in geistshell ist flakey unter Last.** Im `make ci`-Lauf mit parallelen Fork-Containern: 58/1/0, Fehlschlag „the plant readings never reached the journaled context“. Gegenprobe mit frischem Baum: **6 von 6 Läufen 61/1/0**, dreimal gegen Engine `main`, dreimal gegen v0.11.0 — also nicht engine-abhängig. Der Test wartet auf Messwerte eines Device-Kanals; unter Last reicht die Wartezeit nicht. Upstream mit Zeitbudget oder Warteschleife statt fester Frist.
- [ ] **geist-memory: `-j`-Races bleiben.** `deps` (check-engine vor dem Stempel) und `check-repro.sh` (erbt `MAKEFLAGS`). geistkit läuft deshalb für beide ohne `-j`. Eigener PR.
- [ ] **geistshell-Makefile:** Der Kommentarblock zu `GEIST_TARGET` (Z. 25–40) steht doppelt, praktisch wortgleich.
- [ ] **`clang-format` fehlt im Toolchain-Image.** Die geistlib-CI pinnt 22.1.5 per pip. Solange geistkit keinen Format-Schritt aufruft, wäre Nachrüsten allein wirkungslos — beides zusammen oder bewusst offenlassen.
- [ ] **geist-diktat#41** („Plattform-Audit, deutsche WER und Produktfahrplan“, 05.09.) ist fremd und unangetastet.
- [ ] **Ohne Issue:** `lua/geist-diktat/init.lua:34` maskiert `model`, aber nicht `binary`.

### Als Nächstes

- [ ] **P2:** Testmodelle in den Lock (Qwen3.5-0.8B und BitNet, beide mit SHA-256 in geistlib gepinnt), Profil „model“ nächtlich, Skip-Zahlen senken
- [ ] **P3:** Produktkriterien messbar machen (diktat WER, p95, RTF)
- [ ] **P4:** Fuzzing, geistshell-Isolation (bwrap/Landlock), reservierte Memory-Namen, `realpath` im Workdir
- [ ] **Freitag:** `AMD_DESKTOP_RUNNER=on`, Pi-Runner registrieren und `PI5_RUNNER=on`, Rechner neu starten wegen der NVIDIA-Treiber

---

## 19.09., Nachtrag: `main` trägt den Lock-Stand, macOS Intel bleibt rot

**Eigener Fehler, behoben:** Nach dem Merge von geistkit#1 blieb ich lokal auf dem Branch `ci/actions`. Vier Commits (alle Lock-Bumps, die Profile, das grüne Gate) lagen deshalb nie auf `main`, und die nächtlichen Läufe prüften zwei Tage lang den Ursprungsstand. Zusammengeführt über geistkit#2, `main` = `241b023`. Lehre: nach jedem Merge eines eigenen PRs lokal auf `main` zurückwechseln.

**Plattform-Matrix auf diesem Baum (Lauf 35429331508):**

| Plattform | Ergebnis |
|---|---|
| Linux x86_64 (Container) | **grün** |
| Linux arm64 (Container) | **grün** |
| macOS arm64, Apple clang und llvm@19 | **grün** |
| macOS Intel, beide Compiler | rot, eine Ursache (F11) |

### F11 – geistlib: Sanitizer-Build auf macOS x86_64 (Repo geistlib), gefunden durch geistkit#2

- [ ] `src/backends/cpu_x86/elementwise.c:71/90/124` im Ziel `mac-omp`, Modus `asan`: clang meldet „loop not vectorized: the optimizer was unable to perform the requested transformation“, und `-Werror` bricht ab. Beide Compiler betroffen, Release ist grün — es trifft nur Sanitizer-Builds mit `-O1`.
- **Wirkung in geistkit:** vier rote Schritte aus einer Ursache — `geistlib.asan` sowie `geistshell.build`, `.test` und `.baseline`, weil geistshell die Engine im Sanitizer-Modus mitbaut.
- **Lücke:** #415 hat genau diese Datei angefasst (`firstprivate` an zwei `parallel for simd`) und nur den Release geprüft. Der macOS-x86_64-Leg der geistlib-CI enthält offenbar keinen Sanitizer-Build — genau dort ist es durchgerutscht.
- **In Arbeit:** PR mit dem Fix plus, falls nötig, ein macOS-Sanitizer-Leg in der geistlib-CI.
- **geistkit danach:** `SHA_geistlib` nachziehen, dann sollten alle sechs Plattformen grün sein, und in `acceptance.d/darwin-x86_64.tsv` die dann gemessenen Zähler eintragen statt der Platzhalter.

---

## 19.09., Nachtrag 2: eigener Runner in Betrieb, clang deckt Neues auf

Der Rechner ist neu gestartet: NVIDIA-Kernel-Modul und Userspace stehen beide auf 595.91.07, Vulkan enumeriert die RTX 2080 Ti. **geistlib#421 ist damit mit allen Checks grün gemergt, erstmals inklusive „Vulkan backend (discrete GPU)“** — die Fremdursache, die bisher jeden PR rot machte. Lock steht auf `0f35be4a` (v0.11.0-67).

Der geistkit-Runner läuft (`AMD_DESKTOP_RUNNER=on`), und der eigene Leg baut jetzt eine Matrix aus `gcc-14` und `clang-19`, wie geist-memory upstream beide Compiler prüft.

**Zwei eigene Fehler dabei behoben:**
- `make ci` gab `CC` nie in den Container weiter — jede Variante baute mit dem gcc-14-Default.
- Image-Tag **und** Container-Name waren fest. Lokaler Lauf und CI-Job auf demselben Rechner haben sich gegenseitig das Image überschrieben und den Container entfernt. Beide tragen jetzt einen Hash der Arbeitskopie.
- Im Image fehlte die zu clang passende OpenMP-Laufzeit: `libomp-dev` (18) ist durch `libomp-19-dev` ersetzt, `libomp-dev` braucht gcc nicht (es nutzt libgomp). Belegt: `clang-19 -fopenmp` baut wieder, gcc-14 unverändert grün.

### F12 – geistlib: clang-19 stürzt auf x86 ab (Repo geistlib), gefunden durch die clang-Variante

- [ ] `src/archs/audio_conformer/audio_linear.c`: clang-19 bricht mit einem internen Fehler ab (exit 70), Pass „X86 DAG->DAG Instruction Selection“, Funktion `@w8a8_avx512vnni.omp_outlined`.
- **Muster:** Beim OpenMP-Auslagern verliert der Rumpf offenbar die `target`-Attribute, sodass VPDPBUSD in einer Funktion ohne AVX512-VNNI landet. F8 hat dieselbe Datei schon einmal umgebaut („Cannot select VPDPBUSD“), damals für den Nicht-OpenMP-Pfad.
- **Nicht abgedeckt upstream:** geistlib baut Linux mit gcc; clang-x86 mit OpenMP wird nirgends geprüft.
- **Wirkung in geistkit:** Der `clang-19`-Leg auf `amd-desktop` bleibt rot, bis das behoben ist.

**19.09., Plattform-Stand mit Lock `0f35be4a`:** Linux x86_64 und arm64 grün, macOS arm64 beide Compiler grün, **macOS Intel erstmals grün** (beide Compiler, gemessen 39/25 für unit und ASan, geistshell 60/2/1) — F11 wirkt. Die Zähler stehen jetzt als Vorgaben in `acceptance.d/darwin-x86_64.tsv` statt der Platzhalter. Offen ist allein der `clang-19`-Leg auf `amd-desktop` (F12).

---

## 19.09., Richtigstellung: es gab kein F12, und das Gate ist überall grün

**F12 war ein Messfehler von mir, kein Upstream-Defekt.** Ich habe den diktat-Build manuell mit `GEIST_REPO`, aber ohne `GEIST_REF` aufgerufen. Also baute diktat seine **eigene** gepinnte Engine v0.10.8 (`bb751c5`), nicht den Lock-Stand. Dort stürzt clang tatsächlich ab, und zwar mit clang-19 **und** clang-21 — es ist also kein LLVM-Bug, sondern ein Codemuster, das jeder clang ablehnt. Auf `main` (`0f35be4`) ist es längst behoben: #415 hat die Intrinsics nach `w8a8_avx512vnni_row` mit `AUDIO_VNNI_TARGET` gelegt, der OpenMP-Rumpf ruft sie nur auf. Die echte geistkit-Pipeline übergibt beide Variablen und war nie betroffen.

Der rote clang-Leg hatte eine andere, ebenfalls eigene Ursache: die fehlende zu clang passende OpenMP-Laufzeit im Image (`libomp-19-dev`).

**Übrig bleibt daraus ein sinnvoller Beitrag:** [geistlib#422](https://github.com/geisten/geistlib/pull/422) ergänzt den fehlenden CI-Leg `build-test-x86_64-clang`. Jeder x86_64-Leg baute bisher mit gcc, die macOS-clang-Legs bauen eine andere Konfiguration — die Schnittmenge „clang + x86_64 + OpenMP-Outlining“ hatte kein Gate. Nachweis: Auf v0.10.8 fängt der Leg den Absturz, auf `main` ist er grün (39/24/0).

**Plattform-Stand, Lauf `35437016697` (Lock `0f35be4a`): alle acht Legs grün.**

| Leg | Ergebnis |
|---|---|
| Linux x86_64, Linux arm64 (hosted) | grün |
| macOS arm64, Apple clang und llvm@19 | grün |
| macOS Intel, Apple clang und llvm@19 | grün |
| amd-desktop, gcc-14 **und clang-19** | grün |

- [ ] **Folgepunkt:** `geist-diktat` pinnt weiterhin v0.10.8 und trifft den Absturz bei clang-Builds. Ein Pin-Bump auf den Lock-Stand löst es ohne Engine-Änderung.

---

## 19.09., Endstand: Lauf `35439278291` grün — alle acht Legs

Lock: geistlib `a424d4dd` (v0.11.0-69), geistshell `5c8a9761`, geist-memory `b29243de`, geist-diktat `98525d23`. Jeder Konsument baut gegen dieselbe Engine, keiner patcht sie.

| Leg | Ergebnis |
|---|---|
| Linux x86_64 (hosted, Container) | grün |
| Linux arm64 (hosted, Container) | grün |
| macOS arm64 — Apple clang, llvm@19 | grün |
| macOS Intel — Apple clang, llvm@19 | grün |
| amd-desktop — gcc-14 | grün |
| amd-desktop — clang-19 | grün |

**18 PRs gemergt:** geistlib #413–#422, geistshell #148 und #149, geist-diktat #50 und #51, geist-memory #5, geistkit #1 und #2.

### Offen, nach Priorität

- [ ] **P2 Testmodelle:** Qwen3.5-0.8B und BitNet (beide in geistlib SHA-gepinnt) in `versions.mk`, `make fetch-models`, Profil „model“ nächtlich. Erst damit laufen die 24 übersprungenen Unit-, 48 Integrations- und 9 e2e-Tests.
- [ ] **Pi 5:** Runner für geistkit registrieren, dann `PI5_RUNNER=on` — Anleitung und Checkliste in [geistkit#3](https://github.com/geisten/geistkit/issues/3). Das Speicherlimit ist dafür parametrisiert (`MEMORY`, im pi5-Job 6g bzw. Variable `PI5_MEMORY`).
- [ ] **P3 Produktkriterien** messbar machen (diktat WER, p95, RTF).
- [ ] **P4 Sicherheit:** Fuzzing für GGUF/safetensors/WAV/Tokenizer, geistshell-Isolation (bwrap/Landlock), reservierte Memory-Namen, `realpath` im Workdir.
- [ ] Ältere Befunde: flakey `test_cli_device` unter Last, `-j`-Races in geist-memory, doppelter Kommentarblock im geistshell-Makefile, `geist-diktat` pinnt noch v0.10.8, nvim-Issues #19/#20/#24, fremder PR diktat#41.

---

## 19.09.: P2 umgesetzt — Modellprofil, nächtlich

`MODELS=1` schaltet die modellabhängigen Suiten dazu und wechselt auf ein eigenes Vorgabenprofil (`-model`). Ohne Modelle bricht es ab, statt still zu überspringen.

**Gemessen auf amd-desktop (Profil `linux-x86_64-avx512`), Qwen3.5-0.8B und BitNet b1.58 2B-4T:**

| Suite | modellfrei | mit Modellen |
|---|---|---|
| geistlib `test-unit` | 40 / 24 / 0 | 40 / 24 / 0 (unverändert) |
| geistlib `test-int` | 2 / 48 / 0 | **5 / 45 / 0** |
| geistlib `test-e2e` | 0 / 9 / 0 | **1 / 8 / 0** |

Neu laufen `test_qwen35_load_int`, `test_qwen35_e2e_int` und drei weitere Integrationstests. Laufzeit des vollen Modelllaufs: 291 s gegenüber 264 s modellfrei; Download der zwei Modelle 41 s, 1,9 GB.

**Wichtige Korrektur eines Irrtums:** Ein erzwungenes `GEIST_GGUF_PATH` auf Qwen3.5 macht die Suite **rot**, nicht grün — 1 Unit- und 6 Integrationstests scheitern, weil sie gegen die Gemma-Fixture geschrieben sind (SPM-Tokenizer, Gemmas Chat-Template und EOS, Gemma-Geometrie). Richtig ist, die Modelle nur in `gguf_artifacts/` zu legen: Jeder Test sucht die Fixture, die er braucht, und überspringt sauber, wenn sie fehlt. Genau so macht es geistlibs eigene CI.

**BitNet aktiviert derzeit keinen pass/fail-Test.** Es ist das Benchmark-Modell für `make bench` (Timing, kein Gate). Es wird trotzdem geladen, weil es die Wahl des Users ist und `bench` damit nächtlich möglich wird.

**Was weiterhin übersprungen wird, mit Grund (gemessen, 45 Skips in `test-int`):** 26 warten auf die Gemma-4-E2B-Fixture (3,1 GB), 3 auf den Audio-Tower, 2 auf Qwen3-0.6B (609 MB), 2 auf SmolLM2-360M (386 MB), der Rest auf safetensors-Dumps.

- [ ] **Folgepunkt, bestes Verhältnis:** Qwen3-0.6B und SmolLM2-360M dazunehmen (zusammen ~1 GB, beide SHA-gepinnt) — löst 4 weitere Skips.
- [ ] **Folgepunkt, größter Block:** Gemma 4 E2B (3,1 GB) löst 26 Skips, treibt den Cache aber auf ~5 GB von 10 GB Budget.
- [ ] **Folgepunkt:** `make bench` als nächtlicher Messschritt mit Protokoll (BitNet), nicht als Gate.
- [ ] **Nicht abgedeckt:** geist-memory `bench-model` und `test-e2e` brauchen ein eigenes Embedding-Modell (`bitnet-embedding-0.6b-geist.gguf`), das der nightly-Workflow von geist-memory selbst erzeugt. geist-diktat `test-e2e` braucht Audio-Tower und Gemma.

---

## 19.09.: P3 — Messwerte neben Pass/Fail

`results.tsv` enthält jetzt nicht nur Zähler, sondern Zahlen. Gemessen wird der Durchsatz von geistlibs Benchmark-Modell (BitNet b1.58 2B-4T, i2_s) mit `tests/bench_perf_sweep`: 128-Token-Prefill plus 16 Decode-Schritte, Mittel über 10 Wiederholungen nach verworfenem Warmup, **4 festgenagelte Threads**. Das Werkzeug liefert JSON, `tools/run.sh` nimmt daraus `prefill_tps`, `decode_tps`, `rss_mb` und `threads` — kein Parsen von Fließtext.

Damit hat BitNet endlich eine Aufgabe: Es aktiviert keinen Pass/Fail-Test, ist aber das Modell, an dem der Durchsatz hängt.

**Streuung, gemessen auf amd-desktop (Ryzen 9 9950X, gcc-14):**

| Bedingung | prefill tok/s | decode tok/s |
|---|---|---|
| 5 isolierte Läufe, ruhige Maschine | Median 700,3 (Streuung 0,6 %) | Median 110,4 (0,5 %) |
| im vollen `verify`, ruhige Maschine | 696,6 | 110,5 |
| im vollen `verify`, direkt nach Builds | 680,3 | 103,5 |

Also ~3 % Streuung beim Prefill und ~7 % beim Decode unter realen Bedingungen, nicht die 0,5 % einer unbeschäftigten Maschine. RSS 2865 MB, Streuung 0,0 %.

**Vorgabenform: Untergrenzen bei etwa einem Viertel des Medians, ausdrücklich keine Ratsche.** Eine Ratsche auf einem Durchsatzwert geht bei Rauschen und auf jeder langsameren Maschine rot — und wird dann ignoriert. Die Untergrenzen fangen die Klippen, die wirklich vorkommen: skalarer Fallback statt AVX-512/VNNI, versehentliches `-O0`, OpenMP aus, ein Kernel der zu früh zurückkehrt. Jede davon kostet einen Faktor, nicht ein paar Prozent. Dieselbe Begründung wie in geistlibs eigenem `benchmark/perf_gate.py`. Zusätzlich prüft `threads == 4`, dass die Messbedingung stimmte — und dass ein still verschwundener Bench-Schritt auffällt, weil ein fehlender Messwert als Fehler gilt.

**Wo gemessen wird:** Der Schritt läuft bei jedem `MODELS=1`, also in beiden nächtlichen Läufen. Die Untergrenzen gelten aber nur im Profil `linux-x86_64-avx512-model`, das ich gemessen habe. Für den gehosteten Runner gibt es noch keine — dort habe ich nie gemessen, und eine erfundene Zahl ist schlechter als keine. Neu ist dafür der Job `nightly-models-desktop` auf eigener Hardware, wo die Last bekannt ist.

### Nicht messbar, und warum

**WER, p95 und RTF von geist-diktat gehen heute nicht.** `tests/e2e_wer.sh` braucht **beides**: `gemma4-e2b-Q4_K_M.gguf` (3,1 GB) **und** `audio_tower.safetensors`. Fehlt eines, endet das Skript mit SKIP und Exit 0. Keines von beiden liegt im Modellprofil. Halb gebaut wäre das schlechter als gar nicht, deshalb bleibt es offen:

- [ ] Gemma-4-E2B-Fixture und Audio-Tower ins Modellprofil aufnehmen (≈3,3 GB zusätzlich, beide in geistlib gepinnt: `fetch-model`, `fetch-audio-tower`). Erst danach sind WER, p95 und RTF messbar — und erst dann lohnt sich ein Gate darauf.
- [ ] Achtung bei den Zielwerten: Die Zahlen in `doc/PRODUCT-PLAN.md` (WER ≤ 10 %, mit Rauschen ≤ 25 %, p95 ≤ 3 s, RTF ≤ 0,8) sind dort ausdrücklich **vorgeschlagen**, und der Abnahmetext verlangt eine „vorher vereinbarte und auf einem unabhängigen Testset gemessene“ WER. Vor einem Gate braucht es also erst die Vereinbarung und das Testset.
- [ ] Untergrenzen für `linux-x86_64-model` (gehostet) nachtragen, sobald ein paar nächtliche Läufe die Spanne zeigen.
- [ ] Mit den 26 Gemma-Skips in `test-int` fällt dann auch der größte Brocken der übersprungenen Integrationstests.

---

## 19.09.: P2 und P3 sind gemergt

**P2 ([#4](https://github.com/geisten/geistkit/pull/4)):** `MODELS=1` schaltet `test-int` und `test-e2e` dazu und wechselt auf das Profil `<plattform>-model`. `make fetch-models` nutzt geistlibs gepinnte Targets (keine URL, keine Prüfsumme dupliziert), legt die Modelle nach `build/models` — außerhalb von `build/deps`, weil `fetch-dep.sh` jeden Klon per `git clean -fdx` leert — und `link-models` hardlinkt sie offline zurück.

Gemessen: `test-int` 2/48/0 → **5/45/0**, `test-e2e` 0/9/0 → **1/8/0**, `test-unit` unverändert 40/24/0. Voller Lauf 291 s statt 264 s, Download 1,9 GB in 41 s.

**Befund, der eine Annahme korrigierte:** Ein erzwungenes `GEIST_GGUF_PATH` auf Qwen3.5 macht die Suite **rot** (1 Unit-, 6 Integrationstests), weil sie gegen die Gemma-Fixture geschrieben sind. Richtig ist, die Modelle nur bereitzustellen und jeden Test seine Fixture selbst wählen zu lassen.

**Warum 45 int-Tests weiter übersprungen werden:** 26 warten auf Gemma 4 E2B (3,1 GB), 3 auf den Audio-Tower, 2 auf Qwen3-0.6B, 2 auf SmolLM2-360M, der Rest auf safetensors-Dumps. Bestes Verhältnis: Qwen3 plus SmolLM2, zusammen ~1 GB für 4 weitere Tests.

**P3 ([#5](https://github.com/geisten/geistkit/pull/5)):** `geistlib.bench.prefill_tps`, `decode_tps`, `rss_mb` und `threads` landen in `results.tsv`, Quelle ist das JSON von `tests/bench_perf_sweep` (Mittel über `--repeats`, Warmup verworfen), gemessen mit BitNet und **4 festgenagelten Threads**.

Streuung auf amd-desktop: ruhig isoliert 700,3 prefill / 110,4 decode (0,5 %), im vollen `verify` ruhig 696,6 / 110,5, direkt nach Builds 680,3 / 103,5 — real also ~3 % prefill und ~7 % decode. Kosten: ~7 s.

**Vorgabenform bewusst keine Ratsche:** `prefill_tps >= 150`, `decode_tps >= 25`, `rss_mb <= 4500`, `threads == 4`. Untergrenzen bei etwa einem Viertel fangen das, was wirklich passiert — skalarer Fallback, `-O0`, OpenMP aus —, je ein Faktor statt Prozente. Eine Ratsche würde bei Rauschen rot gehen und dann ignoriert werden. Die Untergrenzen gelten nur im gemessenen Profil; der gehostete Runner behält nur `threads == 4`, weil eine erfundene Zahl für eine nie gemessene Maschine schlechter ist als keine.

**WER, p95 und RTF bleiben unmessbar**, und zwar begründet: `tests/e2e_wer.sh` braucht Gemma 4 E2B **und** den Audio-Tower (~3,3 GB zusammen), sonst SKIP mit Exit 0. Dieselbe fehlende Fixture blockiert die 26 Gemma-wartenden Integrationstests. Außerdem sind die Zahlen in `doc/PRODUCT-PLAN.md` als *vorgeschlagen* markiert, und der Abnahmetext verlangt eine vorher vereinbarte WER auf unabhängigem Testset — die Vereinbarung kommt also vor dem Gate.

### F13 – geistshell: `test_cli_device` fällt unter Last um (Repo geistshell)

- [ ] `test/test_cli_device.sh`, zweite Prüfung: „the plant readings never reached the journaled context“. Der Test wartet offenbar mit fester Frist darauf, dass Messwerte des Device-Kanals im Journal erscheinen.
- **Beleg:** ruhig 6 von 6 Läufen grün (beide Engine-Revisionen), unter Last 58/1/0 statt 61/1/0. In der CI reproduzierbar im Job „linux x86_64 (models, nightly)“ auf gehostetem `ubuntu-24.04` mit 4 vCPU (Lauf 35446906881), während derselbe Lauf auf dem Ryzen 9 9950X grün ist.
- **Die Vorgabe wird nicht aufgeweicht.** Ein Test, der unter Last falsch fehlschlägt, ist der Fehler. Fix upstream: auf das Ereignis warten statt auf Zeit.
- **In Arbeit** als PR in geistshell.

**F13 gemergt** ([geistshell#150](https://github.com/geisten/geistshell/pull/150)), Lock nachgezogen. Der Test wartete eine feste Anzahl Versuche auf ein Physikmodell, das nach Wandzeit fortschreibt, und nagelte eine nicht determinierbare Temperatur fest (264–635 Deci-Grad über 20 Läufe gemessen). **Gravierender war:** Die Journal-Prüfung hing nicht an ihrem eigenen Lauf — alle Agent-Läufe hängen an dieselbe Journal-Datei an, also konnte ein späterer Block das `grep` erfüllen. Der Test war damit teils falsch-positiv und ist jetzt strenger: Journal vor dem geprüften Lauf geleert, Warten auf das Ereignis mit Budget, Aussage statt Zahl geprüft. Nachweis: 10 Läufe ruhig und 10 Läufe auf 2 CPUs mit 6 Spinnern, alle grün.

**Beleg in der Praxis, Lauf `35448435206`: alle zehn Jobs grün**, auch `linux x86_64 (models, nightly)` auf dem gehosteten Runner, der zuvor genau daran scheiterte.

| Job | Ergebnis |
|---|---|
| Linux x86_64, Linux arm64 (hosted) | grün |
| macOS arm64 und Intel, je Apple clang und llvm@19 | grün |
| amd-desktop, gcc-14 und clang-19 | grün |
| Modellprofil, gehostet **und** amd-desktop | grün |

### Als Nächstes

- [ ] **Gemma 4 E2B plus Audio-Tower ins Modellprofil** (~3,3 GB, in geistlib gepinnt). Das ist der Hebel mit dem größten Ertrag: Es weckt 26 der 45 noch übersprungenen Integrationstests **und** macht WER, p95 und RTF überhaupt erst messbar, also den Rest von P3. Vorher zu klären: die WER-Vereinbarung, weil der Abnahmetext ein unabhängiges Testset verlangt und die Zahlen im Produktplan nur vorgeschlagen sind.
- [ ] **P4 Sicherheit:** Fuzzing für GGUF, safetensors, WAV und Tokenizer; geistshell-Isolation (bwrap oder Landlock), reservierte Memory-Namen, `realpath` im Workdir.
- [ ] **Pi 5:** [#3](https://github.com/geisten/geistkit/issues/3).
- [ ] Kleinere Befunde: `-j`-Races in geist-memory, doppelter Kommentarblock im geistshell-Makefile, `geist-diktat` pinnt noch v0.10.8, nvim-Issues #19/#20/#24.

---

## 19.09.: Gemma-Fixture und Audio-Tower im Modellprofil

`make fetch-models` holt jetzt zusätzlich die Gemma-4-E2B-Fixture und den Audio-Tower über geistlibs Targets; `link-models` legt den Tower nach `audio_bench/`, wo die Tests ihn suchen. geist-diktats WER-Test braucht **nichts** im Engine-Klon: Er liest Modell und Tower aus `GEIST_DIKTAT_DATA` und seine WAV aus den eigenen Fixtures — und es darf auch nichts dort liegen, weil sein `sync-engine` ein `geistlib/`-Verzeichnis ablehnt, das kein Git-Checkout ist (genau darüber bin ich zuerst gestolpert).

**Gemessen auf amd-desktop, Profil `linux-x86_64-avx512-model`** (bestanden/übersprungen/fehlgeschlagen):

| Suite | modellfrei | Qwen3.5 + BitNet | **plus Gemma + Tower** |
|---|---|---|---|
| geistlib `test-unit` | 40/24/0 | 40/24/0 | **44/20/0** |
| geistlib **ASan** | 40/24/0 | 40/24/0 | **44/20/0** |
| geistlib `test-int` | 2/48/0 | 5/45/0 | **27/22/1** |
| geistlib `test-e2e` | 0/9/0 | 1/8/0 | **4/5/0** |
| geist-diktat `test-e2e` (WER) | – | – | **bestanden, WER 0,0 %** |

Vier Tests mehr laufen damit auch **unter AddressSanitizer** — das war nicht vorhergesehen, sondern gemessen.

**WER:** 0,0 % auf dem LibriSpeech-Clip. Der Test gatet sich selbst bei 15 %; der Produktplan schlägt ≤ 10 % vor. geistkit setzt **kein** eigenes WER-Gate: Ein Clip trägt keine Schwelle, und der Abnahmetext verlangt ein vorher vereinbartes, unabhängiges Testset. Der Messwert steht als `geist-diktat.e2e.wer_pct` in `results.tsv`. **p95 und RTF bleiben unmessbar**, auch mit allen Fixtures: Der Test misst die Wandzeit auf ganze Sekunden gerundet und nennt seine tok/s-Zeile im Kommentar selbst bedeutungslos.

**Kein Cache für die Modelle, mit Zahlen begründet:** Der Satz ist 5,4 GB. Ein Eintrag belegt 54 % des 10-GB-Budgets, der nächste Lock-Bump legt einen zweiten an — genau die Verdrängung aus F10. Alle vier Dateien zu holen dauerte 76 s, etwa so lange wie 5,4 GB aus dem Cache zu restaurieren. Platz auf gehosteten Runnern: 5,4 GB Modelle plus rund 1,2 GB Klone und Build-Bäume gegen etwa 14 GB frei.

**Laufzeit:** modellfrei 262 s, mit Modellen 549 s. Gehört damit weiter nur in den nächtlichen Job.

### F14 – geistlib: Audio-Paritätstest driftet auf x86 (Repo geistlib)

- [ ] `test_audio_attn_w8a8_parity_int` scheitert mit vorhandenem Tower auf amd-desktop: „drifts from reference“ für `attn+lconv` und `defaults` (1-cos schlechtester Wert 1,582e-01, max|diff| 6,7). Der Fall `attn-W8A8` allein besteht (5,541e-02).
- **Warum es niemandem auffiel:** geistlib führt genau diesen Test nur im Job „audio harness smoke (Linux arm64, NEON)“ aus. Der x86-Pfad mit AVX-512/VNNI-Kerneln hat kein Gate.
- **Die Vorgabe bleibt `failed == 0`.** Ein driftender Paritätstest ist der Defekt; ihn wegzulockern würde genau das verbergen, wofür das Profil existiert. Das Modellprofil auf AVX-512-Hardware ist deshalb rot, bis der Fix da ist.

### Folgepunkte

- [ ] **Qwen3-0.6B und SmolLM2-360M** (~1 GB zusammen) wecken 4 weitere Integrations- und 2 e2e-Tests. Bestes verbliebenes Verhältnis.
- [ ] Von den 22 verbleibenden int-Skips warten 7 auf safetensors-Dumps, der Rest auf Vision-Tower und weitere Audio-Fixtures.
- [ ] Das gehostete Profil `linux-x86_64-model` behält bewusst die lockeren Zähler, bis die erste Nacht mit Gemma echte Werte liefert — auch die Frage, ob der Paritätstest dort ebenfalls driftet.
- [ ] Lock auf den Merge von [geistlib#423](https://github.com/geisten/geistlib/pull/423) heben, damit Gemma und Tower per Revision und SHA-256 gepinnt sind statt über `resolve/main`.
