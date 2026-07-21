# Desert Velocity — Progress

## 2026-07-21 — Release difficulty selector G1-I0

- [x] Checkpoint stabile di ingresso `3c43ba6bfae4fe7dc9e1550d295241181d20874b`; report metriche preesistente e 15 diagnostici camera/recovery preservati ed esclusi.
- [x] Selettore FACILE / NORMALE / DIFFICILE aggiunto soltanto al garage Prova Speciale, navigabile con mouse e frecce; NORMALE predefinito, restart conservativo e reset dal menu principale.
- [x] Tempi verificati su entrambe le vetture: FACILE 105 s e +18 s a CP1–CP5; NORMALE 90 s e +15 s; DIFFICILE 75 s e +12 s. CP6 e traguardo non aggiungono tempo.
- [x] HUD Stage mostra `DIFFICOLTÀ <livello>` nel pannello destro esistente senza pannelli nuovi o sovrapposizioni; garage 1280×720 ispezionato dopo la correzione del layout.
- [x] Suite dedicata 173 controlli PASS: decremento, CP1–CP6, pausa, restart, timeout, arrivo, menu, mouse/tastiera, due vetture, Endurance, audio e HUD.
- [x] Parser/import, Boot, HUD binding, G1-H 98 controlli e audiovisual 124 controlli PASS; test finali con APPDATA isolato.
- [x] Sei screenshot reali 1280×720 prodotti e ispezionati in `screenshots/release_difficulty/`.
- [ ] Warning non bloccante: la harness dedicata segnala 6–8 istanze ObjectDB al teardown dopo Boot ripetuti; nessuna failure runtime o regressione nelle suite consolidate.
- [x] Stato: **A) RELEASE DIFFICULTY SELECTOR PASS**. Endurance, gameplay, route, fisica, checkpoint logici, audio, grafica, camera, salvataggi e progressione invariati; nessun push eseguito.

## 2026-07-21 — Final audiovisual release polish G1-H

- [x] Checkpoint tecnico di ingresso `0349621792bec9ca9a41da155b93a6eb819cfa8c`; report metriche vertical-slice già modificato e 15 diagnostici camera/recovery preservati ed esclusi.
- [x] Risolta la causa dei quadrati Bavarian: i quattro `QuadMesh` legacy opachi ora usano texture alpha procedurale morbida, fade progressivo, scala/rotazione casuali, durata breve e densità differenziata per superficie.
- [x] Pilot Stallion ridotto e ammorbidito; frammenti d'atterraggio dimezzati. ASPHALT quasi nullo, GRAVEL contenuto, SAND/DEEP_SAND progressivi; attivazione gameplay invariata.
- [x] Nessun pannello HUD vuoto: i tre pannelli superiori partono nascosti e si mostrano soltanto con testo valido. Stage conserva pacenote/timer; Endurance mostra obiettivo, marcia, RPM, superficie e bonus/ostacoli.
- [x] F3 resta disattivato all'avvio ed è attivabile/disattivabile senza contaminare i pannelli principali.
- [x] Audio motore condiviso con loop multi-armonico, smoothing RPM frame-rate independent, dip di cambiata 0,19 s, carico/rilascio/airborne/boost e profili Stallion ruvido 64 Hz / Bavarian compatto 76 Hz. Pitch massimo misurato 1,393/1,471.
- [x] Test dedicato 124 controlli PASS; G1-H 98, HUD, effetti 40/40, risorse, 144 seam crossing, GT V2, runtime e salvataggi isolati PASS.
- [x] MX150 warm, 840 frame: 59,99 FPS medi, P5 58,49, minimo sostenuto 58,61, P95 17,097 ms, P99 17,579 ms, 218 draw call, 65,78 MB, nessuno stutter.
- [x] Dodici screenshot reali 1280×720 prodotti e ispezionati in `screenshots/playable_visual_integration_pilot/g1h_release/`.
- [ ] Stato: **AWAITING MANUAL RELEASE APPROVAL**. Ascolto soggettivo gara completa ancora richiesto; nessun export, ZIP, RC o push eseguito.

## 2026-07-21 — Final gameplay consistency repair G1-H

- [x] Checkpoint tecnico di ingresso `a30ff57fdac74c29da7f703141552483211bcafe`; 15 diagnostici camera/recovery preesistenti preservati ed esclusi.
- [x] Endurance Stallion e Bavarian riusano mesh, materiali, texture e LOD G1-F.1 tramite adapter collision-free sui segmenti riciclati; regole Endurance e fallback storico restano invariati.
- [x] Eliminato il tic continuo: i toni brevi di superficie non vengono più riavviati da `update_engine`; un quarto player loop dedicato gestisce la texture continua, senza duplicazioni al restart.
- [x] Prova Speciale: timer residuo 90 s dopo il countdown, +20 s una volta a CP1–CP5, pausa/ripresa/riavvio e schermata `TEMPO SCADUTO` verificati; cronometro storico dei risultati conservato.
- [x] Atterraggio visual-only: compressione 0,04–0,10 m, rebound 32% e ritorno neutro in 0,34 s; collider, camera, traiettoria e danno gameplay invariati. Impatti visuali misurati 7,83/9,00 m/s.
- [x] Schermata Come si gioca aggiornata con controlli reali, Prova Speciale ed Endurance, integra a 1280×720.
- [x] Test dedicato: 98 controlli PASS (minimo richiesto 30). Parser/import, runtime, risorse, HUD, effetti 40/40, 144 seam crossing, GT V2, salti e salvataggi isolati PASS.
- [x] MX150 warm, 840 frame: 60,41 FPS medi, P5 58,36, minimo sostenuto 59,07, P95 17,136 ms, P99 17,619 ms, nessuno stutter; 209 draw call, 142.634 primitive, 1.169 nodi, 65,49 MB, load warm 1.362,29 ms.
- [x] Sedici screenshot reali 1280×720 prodotti e ispezionati in `screenshots/playable_visual_integration_pilot/g1h/`.
- [ ] Warning: la prima esecuzione del test runtime storico ha incontrato un recupero precoce casuale e fallito la sola accelerazione Stallion; la riesecuzione isolata immediata è PASS (48,0 m/s). Nessuna modifica G1-H tocca accelerazione o grip.
- [ ] Stato: **AWAITING MANUAL FINAL GAMEPLAY APPROVAL**. Nessun export, ZIP, RC o push eseguito.

## 2026-07-21 — Garage, scenario parity and route dynamics repair G1-G

- [x] Checkpoint tecnico di ingresso `688906cc3d54bbaf13c76ec931e76ee948263745`; diagnostici camera/recovery preesistenti preservati ed esclusi.
- [x] Garage 1280×720 separato in pannello sinistro da 390 px e safe area preview destra da 818 px; Camera3D dedicata orientata dopo l'ingresso nel SceneTree. Bounds Stallion x 654–953 e Bavarian x 629–961, senza coperture o clipping.
- [x] Avvio Stage lega esplicitamente G1-F.1 a RoadManager indipendentemente da `save.vehicle`; Stallion e Bavarian ricevono entrambi `G1-F.1_FULL_STAGE`. Fallback originale, pilot Environment V2 e Stallion V2 restano espliciti e PASS.
- [x] Route invariata a 64×52 m = 3.328 m, 17 asfalto/47 gravel e checkpoint 9/19/29/39/49/59; archi multi-segmento, esse, tornante, settore tecnico e curva finale ora hanno ampiezza coerente con le pacenote.
- [x] Quattro profili: DOSSO 12, CRESTA 20, RAMPA 30, CRESTA 60. Test fisico reale: Stallion 96 km/h, 0,417 s airborne; Bavarian 112 km/h, 0,500 s; entrambi atterrano senza danno e senza impulsi o modifiche handling.
- [x] Entrambe le auto completano CP `[1,2,3,4,5,6]` e traguardo; pausa/ripresa, restart, menu e persistenza selezione PASS. Seam: 144 attraversamenti PASS.
- [x] MX150 warm, 840 frame: 59,99 FPS medi, P5 58,44, minimo sostenuto 58,99, P95 17,111 ms, P99 18,052 ms, nessuno stutter; 436 draw call, 250.728 primitive, 1.168 nodi, 65,28 MB. Cold 1.390,56 ms, warm 591,05 ms.
- [x] Parser/import, Boot, full-stage inventory, GT V2, gameplay resources, salvataggi isolati e runtime generale PASS; 20 screenshot gameplay reali 1280×720 in `screenshots/playable_visual_integration_pilot/g1g/`.
- [ ] Stato: **AWAITING MANUAL GAMEPLAY ROUTE APPROVAL**. Camera chase, HUD, auto, handling, punteggio, risorse, checkpoint logici, salvataggi, Endurance e art full-stage non modificati.

## 2026-07-21 — Full-stage zone identity and final-run polish G1-F.1

- [x] Checkpoint tecnico di ingresso `3073441e64b0c62269c68d605d48618e1d686520`; intervento confinato alla composizione visuale full-stage esistente.
- [x] Confini invariati: Desert Start/Open Flats 0–9, Eroded Rock Corridor 10–17, Canyon Approach 18–28, High Plateau 29–39, Dunes and Wreck 40–47, Technical Gravel Pass 48–56, Final Golden Run 57–63.
- [x] Partenza e traguardo rossi sostituiti visivamente da gate collision-free `PARTENZA` e `TRAGUARDO`, coerenti con i checkpoint approvati; trigger e fine gara invariati.
- [x] Landmark distinti: paddock/start, doppia parete erosa, canyon fins, mesa panoramiche, relitto tra dune, due porte tecniche e porta naturale aperta verso il traguardo.
- [x] Palette locali derivate e transizioni progressive differenziano silhouette, masse e ritmo senza cambiare shader/materiali sorgente, Golden Hour o geometria logica.
- [x] Scatter redistribuito e ridotto: 4 LOD0, 70 LOD1, 646 LOD2; 28 MultiMesh e 690 istanze contro 710 G1-F. Sessantaquattro elementi di contatto ancorano talus e detriti alle composizioni principali.
- [x] RockArch_A resta rinviato per proteggere curva e CP5; la porta finale usa canyon fins asimmetriche senza tetto, collider o modifica route.
- [x] Verifica `0 m`: un solo campione su 320, al centro esatto del target pacenote finale clampato, durata massima un campione. Nessun bug HUD persistente; i valori ripetuti appartenevano al fixture congelato senza look-ahead.
- [x] MX150 / GL Compatibility / 1280×720, 840 frame: 59,98 FPS medi, P5 58,94, minimo sostenuto 59,83, P95 16,967 ms, P99 17,189 ms, nessuno stutter; 500 draw call, 249.534 primitive, 1.163 nodi, 66,15 MB, cold load 15.045,40 ms e warm load 824,37 ms.
- [x] Parser/import, Boot, gara 0–63, checkpoint `[1,2,3,4,5,6]`, fine gara, pausa/ripresa/riavvio, fallback, seam e 15 suite regressive non distruttive PASS.
- [x] Ventiquattro screenshot gameplay reali 1280×720 prodotti in `screenshots/playable_visual_integration_pilot/g1f1/`; video facoltativo non prodotto.
- [ ] Warning: il cold load include la prima compilazione/import degli shader; il warm load è stabile. La revisione visiva manuale resta necessaria.
- [ ] Stato: **AWAITING MANUAL FULL STAGE VISUAL APPROVAL**. Route, gameplay, fisica, camera, Stallion V3, HUD, effetti, checkpoint logici, salvataggi e progressione invariati.

## 2026-07-21 — Full Special Stage visual expansion G1-F

- [x] Checkpoint visivo approvato `fc93278e15789938b5922285b86b8d4f673f06f1`; baseline, inventario 0–63 e piano di sette zone consolidati nel checkpoint intermedio `1beac9504faf4709cec14682b41f3070f439bbae`.
- [x] Prova Speciale invariata: 64 segmenti × 52 m = 3.328 m, 17 ASPHALT, 47 GRAVEL, bande offroad SAND/DEEP_SAND, sei checkpoint agli indici 9/19/29/39/49/59, 22 ostacoli e tre salti DOSSO/CRESTA/RAMPA.
- [x] Sette zone visuali: Open Flats 0–9, Eroded Rock Corridor 10–17, Canyon High Ridge 18–28, High Plateau Technical 29–39, Technical Asphalt Pass 40–47, Dunes/Wreck 48–56 e Final Golden Run 57–63.
- [x] Strada, terreno, banchine e intrusioni combinati per zona seguono gli stessi `stage_layout` e quote; materiali derivati G1-D.1 distinguono asfalto e gravel. Underlay MultiMesh anti-gap e nessun collider visuale aggiunto.
- [x] 8 istanze LOD0, 50 LOD1 e 661 LOD2; 26 MultiMesh aggregano 710 istanze con visibility range e margine, senza caricamento asincrono o streaming rischioso.
- [x] Sei portali visuali CP01–CP06 mantengono trigger, ordine, collider e logica originali. CP02–CP06 sono statici e collision-free; feedback HUD e impulso visuale leggono soltanto `stage_checkpoint`.
- [x] RockArch_A rinviato: la candidata 50–54 è prossima a CP5 e a una curva; due CanyonWall laterali ai segmenti 52/54 forniscono il landmark senza attraversare o restringere la strada.
- [x] Gara controllata completa da Boot: segmenti 0–63, checkpoint `[1,2,3,4,5,6]`, superfici, salti, ostacoli, offroad, arrivo e schermata risultati PASS. Fallback full→pilot 0–9→originale e Stallion V2 PASS.
- [x] MX150 / GL Compatibility / 1280×720, 840 frame su sette zone: 60,01 FPS medi, P5 58,97, minimo sostenuto 59,88, P95 16,958 ms, P99 17,387 ms, nessuno stutter ricorrente; 484 draw call, 249.330 primitive, 1.097 nodi, 61,30 MB, cold load 3.940,36 ms e warm load 1.093,61 ms.
- [x] Ventidue screenshot reali obbligatori prodotti in `screenshots/playable_visual_integration_pilot/g1f/`; video facoltativo non prodotto.
- [x] Parser/import, `git diff --check`, Boot, gameplay, HUD, salvataggi, seam, V2/GT, vertical slice, Environment Kit e wrapper V3 PASS.
- [ ] Warning storico: `stallion_v3_asset_verification.gd` supera le soglie assolute di review (619,00/550 ms istanziazione; 671,10/650 ms primo render), ma geometria, materiali, LOD e test playable V3 passano e nessun file Stallion è stato modificato.
- [ ] Stato: **AWAITING MANUAL FULL STAGE VISUAL APPROVAL**. Gameplay, fisica, camera, Stallion V3, HUD, effetti G1-E.1, checkpoint logici, salvataggi e progressione invariati.

## 2026-07-21 — HUD compactness and effects readability polish G1-E.1

- [x] Checkpoint tecnico di ingresso `62f9021697d7a06b74df2fd27cd7619820a97e6b`; intervento confinato a particelle, HUD e overlay visuale del checkpoint.
- [x] Polvere desaturata, trasparente, bassa e arretrata, con sprite allungati e scala variabile; fattore asfalto ridotto a 0,015, mentre gravel, sand, deep sand e offroad conservano intensità progressiva.
- [x] Boost ridotto a due nuclei caldi affusolati con scia corta e senza luce dinamica; polvere e scarico restano sistemi separati.
- [x] Atterraggio distinto dalla scia continua tramite impulso radiale breve e dieci frammenti; scintille limitate agli urti con danno almeno 8, dieci scie piccole, laterali e one-shot.
- [x] HUD ridotto di circa il 18%: pannelli superiori, tachimetro e turbo più compatti, velocità secondaria abbreviata, barra e stato turbo nello stesso indicatore. Tutti i dati e le firme pubbliche restano invariati a 1280×720.
- [x] Portale `CP 01` con pannello scuro, accenti laterali e label più leggibile; collider e dimensioni logiche invariati. Feedback `CHECKPOINT 1/6` con ingresso in scala e dissolvenza rapida.
- [x] MX150 / GL Compatibility / 1280×720, campione warm 32 s: 60,43 FPS medi, P5 57,56, minimo sostenuto 58,97, P95 17,374 ms, P99 18,378 ms, nessuno stutter ricorrente; 757 draw call, 184.774 primitive, 997 nodi, 60,01 MB e load warm 1.240,28 ms.
- [x] Tutti i 40 controlli G1-E.1 PASS; 14 catture reali richieste prodotte in `screenshots/playable_visual_integration_pilot/g1e1/`, inclusa la prova di scintille su urto reale.
- [x] `git diff --check`, parser/import, Boot/STAGE, superfici, boost, atterraggio, scintille, checkpoint, pausa, riavvio, fallback e 17 suite regressive PASS; salvataggi verificati in APPDATA isolata.
- [ ] Stato: **AWAITING MANUAL GAMEPLAY VISUAL APPROVAL**. Gameplay, fisica, turbo logico, danno, integrità, checkpoint logici, camera, Stallion V3, scenario, percorso, salvataggi e progressione invariati.

## 2026-07-21 — Gameplay visual effects and HUD pilot G1-E

- [x] Checkpoint di ingresso approvato `ed9592fc5489fbeaf72aad6a2a839a264a73bc55`; integrazione confinata a effetti locali Stallion V3, presentazione HUD e overlay visuale del checkpoint.
- [x] Due emettitori posteriori leggono velocità, throttle, sterzo, slip, superficie, offroad, airborne e `turbo_time`; intensità quasi nulla da fermo, progressiva su ASPHALT/GRAVEL/SAND/DEEP_SAND, plume boost e burst one-shot all'atterraggio.
- [x] Boost V2 sincronizzato al turbo reale con due scarichi caldi brevi, nucleo emissivo a particelle e accento posteriore senza luce dinamica; start/stop nello stesso stato logico, pausa e riavvio verificati senza persistenza o duplicazione.
- [x] Scintille one-shot limitate agli urti con danno almeno 8; urti minori non attivano il sistema. Nessun collider, danno, soglia fisica o logica gameplay aggiunti.
- [x] HUD V2 a pannelli antracite/ocra nella safe area 1280×720: centro libero, velocità e turbo gerarchizzati. Punti, record, distanza, velocità, moltiplicatore, carburante, integrità, turbo, tempo, penalità, checkpoint, marcia, RPM, superficie, pacenote, direzione, distanza e messaggi conservati con firme pubbliche invariate.
- [x] Portale checkpoint 1 ricostruito come overlay puramente visuale sul `route_detail` reale: posizione e luce logica invariate, 0 collisioni, pannello `CP 01` e impulso breve sul passaggio; checkpoint e ordine restano gestiti esclusivamente da GameManager.
- [x] MX150 / GL Compatibility / 1280×720, campione warm 32 s: 60,90 FPS medi, P5 58,35, minimo sostenuto 59,13, P95 17,139 ms, P99 17,568 ms, nessuno stutter ricorrente; 738 draw call, 250.498 primitive, 993 nodi, 57,19 MB e load 1.332,13 ms.
- [x] Tutti i 35 controlli G1-E PASS; 14 screenshot reali 1280×720 prodotti in `screenshots/playable_visual_integration_pilot/g1e/`; video opzionale non prodotto.
- [x] Parser/import, `git diff --check`, gameplay/HUD/save, V2/GT/V3, route, vertical slice e runtime più recente G1-C.1B PASS; test storici eseguiti in copie isolate con ambiente ed effetti successivi disattivati.
- [ ] Warning: il test storico `stallion_v3_playable_visual_pilot_runtime_verification.gd`, superato dalla verifica LOD1 G1-C.1B, resta sopra la propria soglia load assoluta G1-C nella copia (951,32 ms contro 868,65 ms), pur passando FPS, draw call, primitive, nodi, memoria, gameplay e fallback. La suite G1-C.1B più recente passa integralmente (61,81 FPS, P5 56,85, minimo 58,89, 848 nodi, 51,29 MB).
- [ ] Stato: **AWAITING MANUAL GAMEPLAY VISUAL APPROVAL**. Gameplay, fisica, camera, scenario G1-D.1, geometria/materiali/LOD Stallion V3, checkpoint logici, salvataggi e progressione invariati.

## 2026-07-20 — Environment Kit V2 playable visual polish G1-D.1

- [x] Checkpoint tecnico di ingresso `dbea31ff29a2b00394884c5b6a0ad34eb980953c`; perimetro invariato ai segmenti reali 0-9, 520 m e checkpoint 1.
- [x] Rilievo puramente visuale aumentato con dune basse, avvallamenti e terrapieni continui; raccordo laterale all'underlay e normali del terreno calcolate senza collider o `SurfaceTool` runtime.
- [x] Palette locale in cinque famiglie attenuate: ocra, terra bruciata, marrone, rosso smorzato e grigio caldo. Top più chiari, cavità/fratture più scure; shader, materiali, texture e GLB E2.1 sorgenti invariati.
- [x] Cinque dune di raccordo e due gruppi MultiMesh di contatto aggiungono talus, ghiaia e piccoli massi attorno a hero rock e canyon; nessuna roccia o prop introduce collisioni.
- [x] Strada rifinita con centro consumato, doppie tracce, roughness/polvere variabili, banchine suddivise e fasce irregolari di sabbia invasiva; larghezza logica e superfici fisiche invariate.
- [x] Composizione riorganizzata in cluster asimmetrici con masse principali/secondarie, detriti e vegetazione; checkpoint, segnaletica, curva e traiettoria restano liberi.
- [x] Golden Hour riequilibrata localmente: key meno satura, fill freddo più presente, fog orizzontale leggera e separazione della Stallion migliorata; nessuna nebbia volumetrica.
- [x] LOD0/1/2: 3/36/370 istanze; sette MultiMesh e 368 istanze aggregate. CollisionShape3D 22/22 fallback/polish e 0 CollisionObject3D nel wrapper.
- [x] MX150 / GL Compatibility / 1280x720: 60,67 FPS medi, P5 56,03, minimo sostenuto 59,11, P95 17,846 ms, P99 19,025 ms, nessuno stutter; 750 draw call, 271.644 primitive, 972 nodi, 54,65 MB e load warm 535,37 ms.
- [x] Dodici screenshot obbligatori reali prodotti in `screenshots/playable_visual_integration_pilot/environment_g1d1/`, inclusi confronti palette e G1-D/G1-D.1; tutte le viste ispezionate senza clipping camera.
- [x] `git diff --check`, parser/import, Boot headless/reale, test G1-D.1, 21 suite regressive tracciate e salvataggi in APPDATA isolata PASS.
- [ ] Warning: il primo run dopo la compilazione dei due nuovi shader ha misurato 5.324,70 ms; a cache calda il load finale è 535,37 ms. Il test camera storico resta isolato col fallback ambiente perché usa la soglia memoria assoluta G1-C.1A.
- [ ] Stato: **AWAITING MANUAL PLAYABLE ENVIRONMENT APPROVAL**. Percorso, camera, Stallion V3, gameplay, fisica, checkpoint, HUD e salvataggi invariati; RockArch e conversione completa non iniziati.

## 2026-07-20 — Environment Kit V2 playable scenario pilot G1-D

- [x] Checkpoint iniziale approvato `fd2719e97fdde330c1d8a0a79f24c5f93e5af2ff`; integrazione limitata ai segmenti reali 0-9 della Prova Speciale, 520 m con rettilineo, curva e checkpoint 1 sul segmento 9.
- [x] Wrapper visuale separato agganciato da `RoadManager` tramite flag locale reversibile; con flag disattivato lo scenario originale resta visibile e funzionale. Nessuna modifica a route, spline, larghezza logica, collider, superfici, checkpoint o ostacoli.
- [x] Strada e banchine F1.1 con terreno suddiviso a coordinata longitudinale continua e underlay procedurale anti-gap; nessun seam, buco, z-fighting o superficie bianca nelle catture finali.
- [x] Environment Kit V2 E2.1 disposto su tre profondità: HeroRock A/B/C LOD0; CanyonWall A/B, dune, props e rocce medie LOD1; Mesa, rocce piccole, ghiaia, cactus e cespugli LOD2. RockArch rimandato per proteggere camera e checkpoint.
- [x] Golden Hour applicata come override locale reversibile con key calda, fill freddo, cielo a gradiente, foschia orizzontale leggera e tonemapping ACES; `project.godot` invariato.
- [x] LOD0/1/2: 3/31/228 istanze. Cinque MultiMesh aggregano 226 elementi; 0 CollisionObject3D nel pilot e 22 CollisionShape3D sia nel fallback sia con G1-D.
- [x] MX150 / GL Compatibility / 1280x720: 60,53 FPS medi, P5 56,43, minimo sostenuto 59,14, P95 17,720 ms, P99 19,012 ms, nessuno stutter; 758 draw call, 233.572 primitive, 945 nodi, 54,71 MB, caricamento 614,70 ms.
- [x] Prova Speciale reale guidata per 32 s, checkpoint 1 raggiunto, fuori strada e superfici logiche verificati; fallback originale, Stallion V3 LOD1 e 14 screenshot reali 1280x720 PASS.
- [x] `git diff --check`, parser/import, Boot headless, 21 test regressivi tracciati e test G1-D dedicato PASS. I test con output sono stati eseguiti in copia temporanea e i salvataggi in APPDATA isolata.
- [ ] Warning: il test camera G1-C.1A usa una soglia memoria assoluta della vecchia baseline (53,18 MB) e con G1-D attivo attribuisce erroneamente il costo ambiente alla camera; isolato con il fallback ambiente passa integralmente a 51,63 MB. Il file camera non è modificato.
- [ ] Limiti residui: RockArch rinviato; il caricamento G1-D resta superiore alla baseline Stallion pura ma entro i gate della fase; la conversione del resto del percorso non è iniziata.
- [ ] Stato: **AWAITING MANUAL PLAYABLE ENVIRONMENT APPROVAL**. Camera, Stallion V3, gameplay, fisica, checkpoint, percorso, HUD e salvataggi invariati.

## 2026-07-20 — Stallion V3 runtime optimization repair G1-C.1B

- [x] Ingresso verificato sul checkpoint camera approvato `971a05f5d391d4436676622336dbd7dacb61201e`; checkpoint veicolo `28814e59fc4e4e3a261430a6555dbcffc7bf94c8` presente e recovery del lavoro parziale aggiornata prima delle modifiche.
- [x] Rimossa dal percorso runtime la fusione `SurfaceTool` per istanza, causa del caricamento a 798,21 ms e dello stutter ricorrente nel prototipo incompleto.
- [x] Risorsa LOD1 precomputata e rigenerabile: 10 MeshInstance3D, 14 superfici, 27.670 triangoli, sei gruppi statici per materiale e quattro gerarchie ruota; sette materiali approvati condivisi.
- [x] Il wrapper gameplay carica soltanto la risorsa ottimizzata derivata dal LOD1; LOD0, LOD2 e Stallion V2 non risultano in cache durante il percorso V3 normale. Nessuna commutazione LOD o popping.
- [x] Caricamenti su tre campioni: asset cold min/media/max 6,056/7,042/8,156 ms; warm 0,005/0,007/0,010 ms; Boot/STAGE 174,532/329,290/636,622 ms; VehicleFactory 16,598/16,692/16,876 ms.
- [x] MX150 / GL Compatibility / 1280x720: media 61,27 FPS, P5 57,59, minimo sostenuto 59,29, frame-time P95 17,363 ms e P99 18,311 ms; zero frame oltre soglia durante guida stabile e nessuno stutter ricorrente.
- [x] Picchi runtime: 762 draw call, 98.900 primitive, 848 nodi e 51,29 MB, tutti inferiori alla baseline G1-C; caricamento Boot medio ridotto da 694,81 a 329,29 ms.
- [x] Confronto reale LOD0/LOD1 e sei viste LOD1 prodotti con stessa scena, camera approvata, posa, illuminazione, HUD e risoluzione; silhouette, roll cage, parafanghi, ruote, normali e materiali verificati senza perdita evidente alla distanza chase.
- [x] Parser/import, generatore offline, Boot headless/reale, test V3, V2, GT V2, camera approvata, gameplay runtime, 17 suite funzionali e tre suite grafiche runtime PASS; test salvataggi eseguito in APPDATA dedicata.
- [ ] Warning: il target consigliato sotto 750 draw call non e raggiunto (762), ma il valore migliora 842 e resta entro tutti i criteri di PASS senza semplificare materiali o ruote.
- [ ] Stato: **AWAITING MANUAL V3 RUNTIME OPTIMIZATION APPROVAL**. Camera, gameplay, fisica, collisioni, controller, HUD e scenario invariati.

## 2026-07-20 — Dynamic playable camera repair G1-C.1A

- [x] Checkpoint di ingresso preservato: `28814e59fc4e4e3a261430a6555dbcffc7bf94c8`; diff parziale e inventario untracked salvati localmente prima della ripresa.
- [x] Causa corretta: il vecchio profilo V3 era troppo vicino e basso e usava un lerp posizione non delimitato seguito da orientamento immediato, producendo protagonista sovradimensionata e risposta instabile nelle transizioni dinamiche.
- [x] Chase V3 finale: distanza 9,80 m, altezza 2,90 m, look-ahead 8,50 m, look-height 4,50 m; risposta posizione 10, rotazione 12, errore follow impostato 0,60 m e guardie radiali dedicate, inclusa distanza boost 8,60 m.
- [x] Confronto statico controllato: occupazione dal 29,95% al 20,72%; centro verticale dal 62,39% al 72,87%.
- [x] Rettilineo, alta velocita, curva, boost, dosso e fuoristrada PASS: occupazione 17,52-22,60%, centro 69,67-74,02%, errore follow massimo 0,562 m e nessuna permanenza fuori soglia.
- [x] MX150 / GL Compatibility / 1280x720: media 76,79 FPS, minimo sostenuto 59,89, nessuno stutter consecutivo, 717 draw call, 102.720 primitive, 817 nodi e 51,30 MB.
- [x] Parser/import, Boot headless, test camera dedicato, 17 suite funzionali e due suite grafiche runtime regressive PASS.
- [x] Caricamento camera test 637,64 ms; il lavoro LOD/runtime preesistente non e stato modificato o ottimizzato in questa fase.
- [ ] Stato: **AWAITING MANUAL DYNAMIC CAMERA APPROVAL**. LOD/runtime, wrapper V3, asset Stallion, gameplay, fisica, collisioni, route, checkpoint e HUD invariati dalla fase.

## 2026-07-20 — Stallion V3 playable visual pilot G1-C

- [x] `VehicleFactory` usa di default `use_stallion_v3_visual_pilot=true` per Desert Stallion V3 Rally Sand; Stallion V2 resta il fallback esplicito e reversibile.
- [x] Wrapper produttivo separato: Rally Sand, LOD0, scala 1:1, offset visuale Y +0,04 m e pivot ruote adattati ai centri runtime senza cambiare GLB sorgenti.
- [x] Gameplay, fisica, collisione, `VehicleController`, camera, route, checkpoint, HUD e salvataggi personali invariati.
- [x] I test storici Stallion V2 e GT V2 disattivano temporaneamente il pilot V3, verificano la V2 e ripristinano il flag; entrambi PASS.
- [x] Test dedicato V3: factory default, Rally Sand/LOD0, 14 mesh, 7 categorie materiali, 54.268 triangoli, pivot, rotazione ruote e fallback V2 PASS.
- [x] Parser/import, Boot reale, test mirati e 17 suite regressive complete PASS; storage Godot e salvataggi test isolati.
- [x] MX150 reale 1280×720: media 60,28 FPS, P5 56,30, minimo sostenuto 58,88, minimo istantaneo 27,43, nessuno stutter ricorrente, 842 draw call, 148.892 primitive, 852 nodi e 52,13 MB.
- [x] Caricamento 694,81 ms, incremento misurato +326,16 ms sulla baseline V2; resta sotto il gate controllato di 868,65 ms. LOD1/LOD2 non vengono caricati nel wrapper produttivo.
- [x] Cinque catture gameplay reali da `Boot.tscn` prodotte e ispezionate: posteriore, fiancata, frontale tre quarti, allineamento ruote e confronto V3/V2, tutte con HUD.
- [ ] Stato: **AWAITING MANUAL PLAYABLE VEHICLE APPROVAL**. Nessuna ulteriore integrazione grafica autorizzata o avviata.

## 2026-07-20 — Gameplay baseline hardening G1-B

- [x] Preservati e verificati rapporto e screenshot G1-A; checkpoint di ingresso `c76520f516e7903bd8782572c870056107d1d108`.
- [x] Corretto esclusivamente il difetto frame-rate del punteggio: il contributo teorico `|velocità| × moltiplicatore × 0,8` viene accumulato con residuo frazionario e azzerato a ogni nuova gara.
- [x] Test deterministico punteggio: 152 punti a 30/60/120 FPS su 11 s a 17,3 m/s, contro 152,24 teorici; bonus, moltiplicatore, record e penalità invariati.
- [x] Aggiunta copertura per carburante, integrità, danno d'atterraggio, turbo, moltiplicatore, timer, penalità, checkpoint ordinati, traguardo, mancato completamento, riavvio e binding completo HUD.
- [x] Salvataggi verificati tramite `SaveManager` reale con `APPDATA` temporanea isolata: default, round trip record/impostazioni, record monotono e fallback su file non valido; salvataggi personali non toccati.
- [x] Atterraggio caratterizzato senza correzione: `landing_impact` misurato dopo `move_and_slide()` è 0 nella fixture, `damage_level` resta 0 e l'integrità GameManager resta 100.
- [x] Documentata la route effettiva invariata di circa 3.328 m (64×52 m); il riferimento a 3.200 m era documentazione obsoleta.
- [x] Baseline gameplay reale da Boot su MX150/GL Compatibility/1280×720: 60,58 FPS medi, P5 58,42, minimo sostenuto 58,14, spike singolo 2,78, 17,007 ms medi, nessuno stutter ricorrente, 823 draw call, 100.146 primitive, 860 nodi, 51,32 MB, caricamento 368,65 ms.
- [x] `git diff --check`, parser/import, Boot headless, cinque test G1-B e tutte le dodici suite regressive precedenti: PASS.
- [ ] Warning residuo storico: `runtime_verification.gd` segnala 6 istanze ObjectDB al teardown; nessuna failure funzionale.
- [ ] Stato: **READY FOR PLAYABLE VISUAL INTEGRATION PILOT**. Integrazione grafica non iniziata.

## 2026-07-19 — Premium Vertical Slice V2 motion review F1.2

- [x] Approvazione visiva manuale F1.1 registrata sul checkpoint `1c85e2da758e09bdf4531e4839d35b631f432162`.
- [x] Sequenza completa registrata con Movie Maker nativo Godot: AVI MJPEG 1280×720, 60 FPS, 2.281 frame, 38:01 e stream audio.
- [x] Quattordici frame reali distribuiti lungo tutti gli undici beat estratti e ispezionati.
- [x] Occlusione grave dell'ostacolo a 22,7 s corretta soltanto tramite posizione/scala delle istanze locali; mesh sorgente, percorso e camera invariati.
- [x] Movimento camera verificato frame per frame: massimo 0,289 m e 0,0031 rad per frame a 60 FPS; protagonista sempre nella safe area.
- [x] Polvere, boost caldo, curva FOV e HUD verificati senza popping, alone blu, sovraesposizione, troncamenti o tremolio.
- [x] Attraversamento dell'arco leggibile e privo di clipping grave; spalla destra e traiettoria non hanno richiesto modifiche.
- [x] MX150: media 59,97 FPS, P5 60,00, minimo sostenuto 57,99, 455 draw call, 487.433 primitive, 357 nodi, 44,08 MB.
- [x] Parser/import, boot, caricamento diretto, F1.1, motion test e suite regressiva completa PASS.
- [ ] Warning residui: 4 istanze ObjectDB al teardown Movie Maker; 6 nel caricamento diretto interrotto.
- [ ] Stato: **AWAITING MANUAL MOTION APPROVAL**. Nessuna integrazione nel gioco principale.

## 2026-07-19 — Premium Vertical Slice V2 visual revision F1.1

- [x] Registrata la classificazione F1: **TECHNICAL PASS — MANUAL VISUAL REVISION REQUIRED** sul checkpoint `fb568e2a18fbe2338af4698495fe7d7aeb92f89e`.
- [x] Individuata e corretta la causa del piano grigio: strada e terreno procedurali venivano osservati dal lato scartato dal back-face culling; lo shader locale F1.1 conserva intatti shader e materiali E2.1 originali.
- [x] Terreno ora caldo e stratificato con sabbia, compatto, ghiaia, dune e microvariazione; strada più scura con centro usurato, tracce, roughness variabile e due banchine irregolari.
- [x] Camera chase rivista a 6,20 m, altezza 2,15 m, FOV 68° / 74° boost e look-ahead 18 m; la Stallion occupa circa 23–24% dell'altezza nelle viste normali.
- [x] Sorpasso ricomposto con V3 Night Raid LOD1 più avanti e laterale; arco finale ridimensionato nella sola istanza e ripreso da tre quarti posteriore con auto, strada e landmark leggibili.
- [x] Densità aumentata vicino pista: 18 rocce medie contestuali, props aggiuntivi e 310 istanze in sette MultiMesh con LOD2; LOD0/1/2 restano attivi.
- [x] Golden Hour riequilibrata con key calda, fill freddo, esposizione ACES 0,86, cielo a gradiente e foschia orizzontale non volumetrica.
- [x] Polvere più leggibile e coerente con la sabbia; boost caldo con fiamme brevi, plume, accento posteriore, FOV massimo 74° e shake deterministico contenuto; nessun alone blu.
- [x] HUD alleggerito con barra superiore più corta, spessori ridotti, safe area e gerarchia riallineate.
- [x] Metriche sequenza continua MX150 / GL Compatibility 1280×720: media 59,97 FPS, p5 60,00, minimo sostenuto 58,01, minimo istantaneo 30,81; 455 draw call, 487.433 primitive, 357 nodi, 44,41 MB, caricamento 887,87 ms.
- [x] Quattordici catture reali F1.1 generate in `screenshots/premium_vertical_slice_v2/revision/`, incluso confronto F1/F1.1.
- [ ] Stato F1.1: **AWAITING MANUAL VISUAL APPROVAL**. Produzione, gameplay e asset approvati restano invariati.

## 2026-07-19 — Premium Vertical Slice V2 integration F1

- [x] Registrata l'approvazione manuale E2.1: **MANUAL VISUAL APPROVAL — ENVIRONMENT KIT V2 APPROVED FOR VERTICAL SLICE INTEGRATION** sul checkpoint `990f606c72e96e49800f41fd438ba186d8ca42e1`.
- [x] Creata `PremiumVerticalSliceV2.tscn` come scena completamente isolata; la slice V1, il gioco principale e tutti i sistemi di produzione restano invariati.
- [x] Sequenza deterministica Path3D/PathFollow3D di 38 secondi e 643,76 m con curva ampia 62,61°, dislivello 19,17 m, dosso 4,00 m, sorpasso, ostacolo, boost e uscita attraverso RockArch.
- [x] Desert Stallion V3 Rally Sand LOD0 protagonista e seconda V3 Night Raid LOD1; nessun VehicleController, GameManager, corpo fisico, input, salvataggio o progressione.
- [x] Environment Kit V2 E2.1 disposto lungo il tracciato con HeroRock A/B/C, Canyon A/B, arco, mesa, rocce, dune, props e cinque gruppi MultiMesh; LOD0/1/2 e materiali condivisi verificati.
- [x] Camera chase dedicata: 4,78 m, altezza 1,82 m, FOV 63° / 70° boost, look-ahead e offset laterale deterministici senza shake casuale.
- [x] Polvere V2 morbida alle ruote posteriori, boost meccanico caldo senza alone blu, ombra di contatto sfumata, HUD V2 leggero e istanza audio sintetica esclusivamente locale.
- [x] Metriche sequenza continua MX150 / GL Compatibility 1280×720: media 59,94 FPS, p5 60,00, minimo sostenuto 57,45, spike iniziale 8,83; 425 draw call, 477.717 primitive, 340 nodi, 43,88 MB, caricamento 872,56 ms.
- [x] Quattordici catture reali 1280×720 generate in `screenshots/premium_vertical_slice_v2/`, incluso confronto V1/V2; nessuna finestra o materiale personale estraneo.
- [ ] Stato F1: **AWAITING MANUAL VISUAL APPROVAL**. Nessuna integrazione in VehicleFactory, gameplay, scene di produzione, fisica o HUD di produzione è autorizzata.

## 2026-07-19 — Environment Kit V2 visual polish E2.1

- [x] Classificazione di ingresso registrata: **TECHNICAL PASS — VISUAL POLISH REQUIRED BEFORE INTEGRATION** sul checkpoint E2 `77edca1ce54f645523dbfd8bb75da03db594449c`.
- [x] Diagnosi: la precedente dominante arancione derivava dalla moltiplicazione tra palette calde, key light satura ed esposizione elevata; neri e bianchi chiusi derivavano da fill insufficiente, atlanti molto contrastati e terreno/strada estesi senza controllo locale dei valori.
- [x] Introdotto un solo shader GL Compatibility condiviso dai nove materiali, con palette ocra/rosso/marrone/grigio, fratture verticali, interruzione macro delle bande, normal e roughness differenziate e modalità dedicate terreno/strada non emissive.
- [x] Tre preset documentati: Daylight Neutral esposizione 0,84, Golden Hour principale 0,90 e Sunset Cinematic 0,88; tutti usano ACES, cielo procedurale a gradiente, orizzonte freddo e fill sufficiente a preservare dettaglio nelle ombre.
- [x] Terreno review suddiviso con rilievo locale, sabbia fine, compatto e ghiaia procedurali; strada con bordo irregolare, usura, polvere, roughness variabile e quota corretta per evitare intersezioni.
- [x] Raccordi integrati con dune cromaticamente coerenti, talus, piccoli massi e ghiaia aggregati tramite MultiMesh; cactus, cespugli, cartelli e relitto raggruppati con rotazione/scala variate.
- [x] Controllo pixel sulle 14 catture: nessuna immagine supera 0,0018% di pixel completamente neri, escluso il confronto storico (0,0526%); nessuna cattura supera 0,0084% di pixel completamente bianchi.
- [x] Metriche MX150 / GL Compatibility 1280×720: 59,92 FPS medi, p5 60,00, minimo sostenuto 58,34, spike istantaneo 42,65; 171 draw call, 177.234 primitive, 245 nodi, 41,91 MB statici, caricamento 464,64 ms.
- [x] GLB, sorgenti Blender, 40 asset, identità, scala, composizione generale, UV e LOD 26.982 / 16.495 / 9.346 triangoli invariati.
- [ ] Stato E2.1: **AWAITING MANUAL VISUAL APPROVAL**. Nessuna integrazione in vertical slice, gameplay, Boost V2 o HUD V2 autorizzata.

## 2026-07-19 — Environment Kit V2 visual review E2

- [x] Registrata l'approvazione manuale E1.1: **MANUAL VISUAL APPROVAL — ENVIRONMENT KIT V2 BLOCKOUT APPROVED WITH POLISH NOTES** sul checkpoint `4fd44d3815031f3ace6d027fbea1fe2acc6a0620`.
- [x] Preservate senza variazioni le silhouette approvate di Hero A/B/C, Canyon A/B e RockArch; nessun asset E1/E1.1 è stato sostituito o integrato in produzione.
- [x] UV validate nell'intervallo 0–1 e dodici texture originali riproducibili: quattro atlanti Natural/Road da 2048² e Props/Vegetation da 1024², ciascuno con base color, normal e ORM (R=AO, G=roughness, B=metallic).
- [x] Wrapper isolato con nove materiali PBR condivisi, tre LOD manuali da 26.982 / 16.495 / 9.346 triangoli, collisioni box esclusivamente di review e 70 istanze aggregate in tre MultiMesh.
- [x] Gli GLB conservano geometria e UV ma non incorporano le bitmap: i materiali condivisi sono applicati dal wrapper, evitando copie estratte ridondanti degli atlanti.
- [x] Scena tecnica con preset Studio, Daylight e Sunset, modalità clay/final PBR, confronto blockout/finale, confronto LOD, silhouette e Stallion V3 usata soltanto come riferimento di scala.
- [x] Metriche reali MX150 / GL Compatibility a 1280×720: 59,90 FPS medi, p5 60,00, minimo sostenuto 58,09, spike istantaneo 31,95; 167 draw call, 160.152 primitive, 238 nodi, 41,60 MB statici, caricamento 444,11 ms.
- [x] Sedici catture tecniche reali generate in `screenshots/environment_kit_v2_review/visual/`, inclusi terreno/strada, composizione completa, confronto blockout/finale e LOD.
- [ ] Stato E2: **AWAITING MANUAL VISUAL APPROVAL**. Riserve visive da valutare: raccordi terreno netti, alcuni valori chiari della strada e semplicità dei props minori; nessuna rifinitura o integrazione ulteriore verrà avviata senza approvazione.

## 2026-07-19 — Environment Kit V2 blockout E1.1 geometric revision

- [x] Classificazione di ingresso registrata: **TECHNICAL PASS — MANUAL VISUAL REVISION REQUIRED** sul checkpoint E1 `236be80f0f46fa2e29a2bd54255f1d1f5b15111a`.
- [x] Revisionati esclusivamente HeroRock A/B/C, CanyonWall A/B, RockArch e la composizione isolata; gli altri 34 asset, i sette materiali clay, Stallion V3 e tutti i file di produzione restano invariati.
- [x] Hero A ora è basso e largo con massa secondaria, fratture e blocchi crollati; Hero B sviluppa orizzontalmente due terrazze; Hero C mantiene altezza da contrafforte ma usa base ampia, cresta spezzata e cavità laterale.
- [x] Canyon A è massiccio e lineare; Canyon B è più fratturato. Entrambi hanno piani continui, terrazze, rientranze, contrafforti non equidistanti, falde e spalle terminali volumetriche per mascherare le giunzioni.
- [x] RockArch è stato portato a circa 17 m di luce e 10 m di cresta, con spalle robuste, spessore variabile e apertura verificata usando Stallion V3 soltanto come riferimento di scala.
- [x] Budget finale: 26.982 triangoli, 40 mesh, 7 materiali, 0 triangoli degeneri; hero A/B/C 2.000/2.184/2.188, canyon A/B 5.608/6.204, arco 2.508.
- [x] Metriche reali MX150 a 1280×720 GL Compatibility: 60,00 FPS medi e minimi sostenuti, 18 draw call di picco, 19.484 primitive, 178 nodi, 39,59 MB memoria statica, wrapper 0,49 ms.
- [x] Blender validation, trasformazioni, naming, export/import, parser, boot, review, test dedicato e intera suite regressiva: PASS.
- [x] Generate 14 catture reali E1.1 con turntable, giunzione, arco con scala V3, raccordo terreno, daylight/sunset, silhouette e confronto prima/dopo.
- [ ] Stato E1.1: **AWAITING MANUAL VISUAL APPROVAL**. Nessuna UV, texture, PBR, LOD definitivo o integrazione autorizzata.

## 2026-07-19 — Environment Kit V2 blockout E1

- [x] Approvazione manuale Stallion V3 registrata: **MANUAL VISUAL APPROVAL — DESERT STALLION V3 APPROVED FOR CONTINUED DEVELOPMENT**.
- [x] Note future V3 registrate senza interventi: ridurre granulosità vernice, controllare accenti rossi, migliorare interni/fari/vetri, rendere Night Raid più blu-antracite, verificare il wrapper normale senza modalità diagnostiche.
- [x] Creato kit Blender/GLB completamente separato con 40 moduli: 3 hero rock, 6 medie, 10 piccole, arco, 2 canyon, 2 mesa, 3 cactus, 3 cespugli, 2 cartelli, barriera, relitto, 3 dune, 2 bordi strada e cluster detriti.
- [x] Le rocce usano profili stratificati, ledge, fratture e sommità spezzate con semi unici; canyon e arco hanno topologie dedicate e buttress integrati, senza sfere o coni deformati.
- [x] Blockout: 10.474 triangoli complessivi, 40 mesh modulari, 7 materiali clay condivisi, 0 texture e 0 triangoli degeneri.
- [x] Wrapper e review Godot isolati con catalogo, viste per famiglia, confronto V2/V3 ambiente, silhouette nera e composizione a tre profondità al tramonto.
- [x] Metriche MX150: 59,99 FPS medi, p5 60,00, minimo sostenuto 59,81, minimo istantaneo 55,82; 99 draw call, 23.546 primitive, 112 nodi, 38,31 MB.
- [x] Caricamento: wrapper 1,19 ms; review test 10,45 ms; primo frame 48,61 ms.
- [x] Blender validation, export, import/parser, boot, review, test E1 e suite regressiva completa: PASS.
- [ ] Stato artistico E1: **AWAITING MANUAL VISUAL APPROVAL**. UV, texture PBR, atlas, LOD, MultiMesh e integrazione restano esclusi.

## 2026-07-19 — Desert Stallion V3, material readability review D2.1

- [x] Confermata la causa della resa scura: il GLB placeholder D2 non contiene nomi materiali; il wrapper ricadeva quindi su `V3_PaintedBody` per tutte le superfici e applicava una ORM unica anche ai metalli strutturali.
- [x] Ricostruita nel solo wrapper isolato la corrispondenza dei sette slot Blender già approvati, senza modificare geometria, GLB, UV, LOD o sorgenti Blender.
- [x] Carrozzeria verniciata resa dielettrica (`metallic = 0,00`); struttura metallica mantenuta a `0,76` senza moltiplicazione impropria per ORM B.
- [x] Cinque texture caricate con fallback leggibili; base color/emissive usate come sorgenti colore sRGB, normal/ORM come dati lineari. Canali verificati: R=AO, G=roughness, B=metallic.
- [x] Rally Sand ora sabbia/avorio con struttura antracite e accenti rossi/arancio; Night Raid blu-antracite leggibile con accenti ambra. Le varianti sono distinguibili anche in miniatura.
- [x] Preset separati Studio Neutral, Outdoor Daylight e Sunset; la review principale usa Studio Neutral senza foschia o grading aggressivo.
- [x] Modalità tecniche isolate: Base Color Only, Roughness, Metallic effettivo, Normal, AO, Clay e Final PBR.
- [x] Quattordici nuove catture reali 1280×720 generate con nomi D2.1 obbligatori, incluso confronto V2/V3 sotto identica illuminazione neutra.
- [x] Metriche MX150: 59,93 FPS medi, p5 60,00, minimo sostenuto 58,37, minimo istantaneo 40,44; 78 draw call, 84.928 primitive, 96 nodi, 36,92 MB.
- [x] Costo review registrato senza occultarlo: 455,67 ms di istanziazione e 510,65 ms al primo frame completo, contro 205,59 ms D2; incremento limitato alla scena tecnica e alla compilazione iniziale dei materiali.
- [x] `git diff --check`, parser/import, boot, caricamento review, test V3 e suite regressiva completa: PASS. Special Stage conserva il warning noto 3 ObjectDB/1 risorsa.
- [ ] Stato artistico: **AWAITING MANUAL VISUAL APPROVAL**. Nessuna integrazione, Environment Kit V2 o modifica di produzione è autorizzata.

## 2026-07-19 — Desert Stallion V3, visual review D2

- [x] Blockout D1.1 rifinito senza modificare silhouette, passo, carreggiata, altezza libera, proporzioni ruote, tetto, roll-cage o retrotreno approvati.
- [x] Fari integrati, griglia, bumper, skid, nervature cofano, pannelli laterali removibili, louvers, fissaggi, protezioni e pacco posteriore rifiniti come dettagli funzionali.
- [x] Abitacolo essenziale completo: due sedili, cinture, volante, colonna, dashboard, roll-cage interno ed estintore; sospensioni con doppi bracci, hub, caliper e molle elicoidali chiuse.
- [x] Topologia LOD0 manifold: 0 bordi aperti, 0 non-manifold; normali ricalcolate e trasformazioni applicate.
- [x] Atlas UV condiviso senza sovrapposizioni intenzionali, margine 0,006, 0 triangoli UV degeneri e densità media 182,31 px/m.
- [x] Baking procedurale riproducibile: base color, normal e ORM 2048²; dirt/damage mask ed emissive 1024². Nessun asset o marchio esterno.
- [x] Sette materiali: vernice, struttura metallica, gomma, vetro, plastica/interno, fari emissivi e accenti/fanali; varianti non distruttive Rally Sand e Night Raid.
- [x] LOD manuali per parte: 54.268 / 27.670 / 10.574 triangoli. LOD0 leggermente sotto il target 55k per evitare geometria aggiunta solo per budget; 14 mesh e 7 materiali.
- [x] Metriche MX150 / GL Compatibility: 59,90 FPS medi, percentile 5% 60,00, minimo sostenuto 57,90; spike istantaneo 24,80 registrato separatamente; 86 draw call, 96.204 primitive, 263 nodi, 37,32 MB statici.
- [x] Caricamento wrapper già in cache 2,20 ms; caricamento completo della scena nel test asset 205,59 ms, sotto il gate di 300 ms.
- [x] Quattordici catture reali 1280×720: Rally Sand, Night Raid, clay, interno isolato, sospensioni isolate, confronto V2/V3, confronto LOD e tramonto.
- [x] Blender validation, `git diff --check`, import/parser, boot, review, test asset V3 e suite regressiva completa: PASS.
- [ ] Stato artistico: **AWAITING MANUAL VISUAL APPROVAL**. Materiali, varianti e lettura dei dettagli devono essere approvati manualmente prima di qualsiasi integrazione.
- [ ] Warning residui di teardown: route review con 3 ObjectDB/1 risorsa; precedente test blockout con 10 ObjectDB. Nessuna failure runtime.

## 2026-07-19 — Desert Stallion V3, revisione strutturale D1.1

- [x] Rimossa la continuità a capsula: carrozzeria centrale più stretta e sfaccettata, cofano a piani strutturali con nervature e presa, frontale corto con fari incassati, presa centrale e bumper tecnico.
- [x] Parafanghi allargati e separati dal corpo, carreggiata portata visivamente verso l'esterno e ruote mantenute a 0,860 × 0,320 m con tasselli geometrici leggibili.
- [x] Doppi bracci superiori/inferiori, hub carrier, ammortizzatori e shock tower resi parte della silhouette; skid plate rialzata e telaio inferiore leggibile.
- [x] Canopy accorciata e resa più verticale; roll-cage maggiorata con traverse, diagonale e puntoni posteriori. Coda della scocca accorciata per esporre pacco meccanico, controventi, scarichi e protezione posteriore.
- [x] Ingombro: 4,900 × 2,206 × 1,742 m; passo 2,940 m; pivot ruota ±0,940 m di carreggiata, asse anteriore/posteriore a ±1,470 m.
- [x] Budget: 21.968 triangoli, 13 mesh e 7 materiali di servizio. La riduzione rispetto ai 28.960 triangoli D1 deriva dalla rimozione della subdivision estetica non funzionale.
- [x] Dodici catture reali 1280×720, incluse viste ravvicinate della meccanica anteriore e posteriore.
- [x] Metriche MX150 / GL Compatibility: 59,99 FPS medi, minimo 56,39, 72 draw call, 58.060 primitive e 57 nodi di picco.
- [x] Trasformazioni, orientamento, dimensioni, pivot, export Blender, `git diff --check`, parser/import, boot, review, test V3 e suite regressiva completa: PASS.
- [ ] Stato artistico: **AWAITING MANUAL VISUAL APPROVAL**. La direzione rally-raid è ora strutturalmente esplicita; proporzioni e linguaggio formale devono comunque essere approvati manualmente prima di texture, PBR, LOD o integrazione.
- [ ] Warning preesistente della sola `SpecialStageRouteReview.tscn`: 3 istanze ObjectDB e 1 risorsa ancora in uso all'uscita headless.

## 2026-07-19 — Desert Stallion V3, blockout D1

- [x] Modello originale ricostruibile da Blender con carrozzeria continua a profili controllati, canopy curva, parafanghi modellati sugli archi ruota e componenti meccanici secondari separati.
- [x] Ingombro LOD0: 4,900 × 2,166 × 1,714 m; passo 2,940 m; ruote da 0,860 × 0,320 m; quattro pivot ruota verificati sugli assi reali.
- [x] Budget blockout: 28.960 triangoli, 13 mesh e 7 materiali di servizio; nessuna texture, UV/PBR, baking o LOD definitivo introdotto.
- [x] Wrapper e scena di review completamente isolati; V2 usata soltanto come confronto. Nessuna modifica a `VehicleFactory`, controller, fisica, gameplay o vertical slice.
- [x] Dieci catture reali 1280×720: fronte, retro, lato, due viste a tre quarti, alto, sottoscocca/sospensioni, due silhouette nere e confronto V2/V3.
- [x] Metriche reali su NVIDIA GeForce MX150 / GL Compatibility: 59,99 FPS medi, minimo 55,38, 66 draw call, 79.036 primitive e 57 nodi di picco.
- [x] Export Blender, `git diff --check`, import/parser, boot, caricamenti diretti, test V3 e suite regressiva completa: PASS.
- [ ] Stato artistico: **AWAITING MANUAL VISUAL APPROVAL**. La silhouette è chiaramente distinta dalla V2, ma la carrozzeria molto levigata può risultare più vicina a una desert roadster che a un rally-raid estremo; nessuna rifinitura verrà avviata senza decisione manuale.
- [ ] Warning preesistente della sola `SpecialStageRouteReview.tscn`: 3 istanze ObjectDB e 1 risorsa ancora in uso all'uscita headless.

## 2026-07-19 — Vertical slice premium, Fase C visual pass V3

- [x] Passaggio visivo applicato soltanto alla scena isolata `PremiumVerticalSlice`; nessun file di produzione, controller, fisica, statistiche, salvataggi o progressione modificato.
- [x] Tre shader originali e separati per strada/terreno, rocce stratificate ed effetti billboard; nessun asset esterno impiegato.
- [x] Terreno con variazione macro/micro, bordi sabbiosi e tracce; canyon ricostruito come affioramenti stratificati indipendenti per evitare auto-intersezioni nella curva.
- [x] Tramonto procedurale, ACES, foschia, luce chiave calda e fill freddo; ombre e leggibilità della Stallion V2 verificate nelle catture reali.
- [x] Due emettitori di polvere, due emettitori boost, luce boost, cue velocità moderato e HUD di presentazione isolato.
- [x] Camera V3: distanza 5,80→4,65 m; altezza 2,25→1,78 m; FOV base 62,00→62,50°; offset laterale 0,48 m; look-ahead 13,00 m.
- [x] Sequenza reale completa di 36 s su NVIDIA GeForce MX150 / GL Compatibility: 60,00 FPS medi, minimo 58,82, percentile 5% 60,00; 351 draw call, 421.920 primitive e 123 nodi di picco.
- [x] Quattro catture reali 1280×720: curva/chase, discesa/sorpasso, dosso/boost e manovra/ostacolo.
- [x] `git diff --check`, import/parser, boot, caricamento diretto della slice e della route review, test dedicato e suite regressiva completa: PASS.
- [ ] Diagnosi V3 — PASS CON RISERVE: composizione, auto protagonista, curva, sorpasso, boost e profondità laterale sono leggibili; rocce procedurali, cielo, varietà dei props e microdettaglio ravvicinato richiedono un futuro passaggio V4 prima dell'integrazione nel gioco.
- [ ] Warning residui di teardown headless: scan thread interrotto alla chiusura editor; route review con 3 istanze ObjectDB e 1 risorsa; un caricamento scena ha segnalato 10 istanze ObjectDB. Nessun errore runtime o test fallito.

## 2026-07-19 — Vertical slice premium, prototipo strutturale

- [x] Scena isolata `scenes/visual/PremiumVerticalSlice.tscn`; nessun collegamento a `project.godot` o alle scene di produzione.
- [x] Sequenza scenografica Path3D/PathFollow3D di 36 secondi con Stallion V2, GT V2, curva ampia, discesa, dosso, sorpasso e ostacolo roccioso.
- [x] Percorso: 535,84 m; curva 64,16°; dislivello 15,44 m; dosso 1,40 m; continuità campionata 1,035 m.
- [x] Strada con collisione locale limitata ai raycast; nessuna simulazione fisica di guida introdotta.
- [x] Camera dedicata ravvicinata e deterministica; HUD strutturale minimale separato dal gameplay.
- [x] Sequenza grafica completa: 61,01 FPS medi, 277 draw call di picco, 286.414 primitive, 83 nodi su NVIDIA GeForce MX150 / GL Compatibility.
- [x] Cattura tecnica reale: `screenshots/premium_vertical_slice/structure_technical.png`.
- [x] `git diff --check`, parser/import, boot, caricamento diretto, test dedicato e suite regressione completa: PASS.
- [ ] Materiali, shader, canyon, atmosfera, polvere, boost e HUD sono intenzionalmente provvisori; Fase C non iniziata.
- [ ] Warning preesistente della sola `SpecialStageRouteReview.tscn`: 3 istanze ObjectDB e 1 risorsa ancora in uso all'uscita headless.

## 2026-07-19 — Baseline prima della vertical slice

- [x] Percorso reale verificato in `D:\DESERT-RACER-GODOT` con `project.godot` presente direttamente nella root.
- [x] Diff preesistente e file non tracciati preservati integralmente prima delle correzioni.
- [x] Ripristinato il ramo `TRAGUARDO` della route artigianale nella catena originaria, senza ridisegnare geometria o gameplay.
- [x] Test runtime di checkpoint e traguardo aggiornati al sistema geometrico corrente.
- [x] `git diff --check`, parser/import, boot, scena di review, giunzioni, Stallion V2, GT V2 visual/gameplay e suite runtime: PASS.
- [ ] Warning residuo isolato nella scena `SpecialStageRouteReview.tscn`: 3 istanze ObjectDB e 1 risorsa ancora in uso all'uscita headless.
- [x] Nessuna modifica grafica avviata; fisica, controller, statistiche veicolo e progressione non modificati in questa baseline.

## 2026-07-17 — Integrazione gameplay Bavarian GT-R V2

- [x] Stato iniziale: checkpoint `a993bc5`, GT V2 `8c0fdeb`, fallback Stallion `b050f1f`.
- [x] Baseline runtime PASS prima delle modifiche; fisica, dati veicolo, collisioni, ambiente e modalità invariati.
- [x] GT V2 integrata tramite wrapper separato, flag `use_blender_gt_v2` e fallback procedurale preservato.
- [x] Collisione semplificata, statistiche, controller, superfici, reset e modalità confermati invariati dai test.
- [x] Pivot ruote, telecamere dedicate GT, garage factory path, Endurance, Prova Speciale, fallback e teardown verificati.
- [ ] Metriche renderer reale e ispezione manuale garage/gara in GL Compatibility ancora necessarie.

## 2026-07-17 — Integrazione gameplay Desert Stallion V2

- [x] Checkpoint pre-integrazione creato (`e0b4212`).
- [x] Stallion V2 attiva in garage e gara tramite `VehicleFactory`.
- [x] Fallback procedurale conservato e verificato con `use_blender_stallion_v2`.
- [x] Corpo fisico e collisione semplificata invariati.
- [x] Quattro pivot ruota collegati a rotazione e sterzata; rollio, beccheggio e sabbia profonda preservati.
- [x] Camere esterne invariate; cofano e paraurti adattate soltanto per Stallion V2.
- [x] GT invariata e verificata dal test mirato.
- [x] Dieci screenshot d’integrazione prodotti e ispezionati.
- [x] Metriche: load 164,79 ms; +3,38 MB; garage 68,67 FPS; Prova Speciale 60,03 FPS; Endurance 92,60 FPS.
- [x] Parser, runtime, giunzioni, test mirato e boot: PASS.
- [ ] Test manuale utente richiesto per feeling visivo in tutte le telecamere durante una gara completa.
- [ ] Ottimizzazione futura: ridurre le 606 draw call unendo battistrada/razze senza cambiare i quattro pivot ruota.

## 2026-07-17 — Prototipo artistico Blender V2

- [x] Checkpoint pre-V2 creato (`879ba9a`), V1 preservata.
- [x] Carrozzeria ricostruita con profilo muscle car angolare, cofano lungo, abitacolo arretrato e tetto basso.
- [x] Dimensioni carrozzeria: 4,72 m × 2,03 m; tetto a 1,36 m; passo 2,82 m.
- [x] Ruote `Wheel_FL`, `Wheel_FR`, `Wheel_RL`, `Wheel_RR`: 0,70 m × 0,28 m, battistrada, sei razze, mozzo e disco.
- [x] Porte con tagli geometrici e maniglie; archi ruota modellati e dettagli rally completi.
- [x] Cinque texture originali 1024×1024: base color, roughness, dirt, scratches, paint variation.
- [x] Studio neutro e tramonto separati; 10 catture neutre e 5 ambientate.
- [x] Ambiente V2 con terreno variato, piccoli sassi, tre rocce irregolari, canyon su più profondità e cactus rastremato.
- [x] V2 importata soltanto in `VisualPrototypeV2.tscn`; gameplay, fisica, collisioni e tappa invariati.
- [ ] Valutazione manuale utente richiesta prima di qualsiasi integrazione.

## 2026-07-17 — Prototipo artistico Blender

- [x] Blender verificato in `C:\Program Files\Blender Foundation\Blender 4.5\blender.exe` (`4.5.11 LTS`).
- [x] Pipeline `source_art/blender` → `assets/models/*.glb` creata e riproducibile.
- [x] Desert Stallion 65 originale: carrozzeria continua, quattro ruote separate e 29.292 triangoli.
- [x] Materiali distinti per vernice, vetro, gomma, cerchi, metallo, plastica, fari, fanali, roll-bar, livrea e sporco.
- [x] Ambiente con strada, terreno, roccia stratificata, canyon continuo e cactus rastremato.
- [x] `scenes/visual/VisualPrototype.tscn` con tramonto, cielo procedurale, foschia, ombre e camera cinematografica.
- [x] Cinque screenshot prodotti e verificati visivamente.
- [x] Gameplay e collisione stradale principale non modificati.
- [ ] Limite residuo: normal map, microdettaglio del terreno e stratificazione naturale del canyon richiedono un secondo pass dopo valutazione utente.

## 2026-07-17 — Correzione giunzioni collisione

- [x] Registrato feedback manuale: arresti improvvisi su asfalto e giunzioni.
- [x] Causa individuata: ogni BoxShape del terreno esponeva facce verticali terminali; sulle variazioni yaw/pitch potevano creare gradini invisibili.
- [x] Sostituite le collisioni guidabili con superfici triangolari top-only senza fianchi verticali.
- [x] Rimossa la sovrapposizione fra superfici inclinate, che generava una cresta numerica.
- [x] Endpoint consecutivi verificati con tolleranza < 0,015 m.
- [x] Riciclo allontanato e vietato sul segmento più vicino al veicolo.
- [x] Controller: floor snap 0,85, safe margin 0,06, velocità costante in pendenza, floor stop disattivato.
- [x] Telemetria F3 estesa con giunzione, ΔY, Δ angolare, floor normal e collider sospetto.
- [x] Test giunzioni: 8 giunti × 3 corsie × 3 velocità × 2 auto × profili piano/curva/quota PASS.
- [x] Suite completa, boot e teardown: PASS.
- [x] Quattro emettitori particellari, uno in corrispondenza di ogni ruota.
- [x] Preset grafici Bassa/Media/Alta persistenti per particelle e ombre.
- [ ] Test manuale utente richiesto sul percorso completo.

## 2026-07-17 — Visual Rally Ultimate pass

- [x] Checkpoint stabile creato nel progetto reale (`614ccdc`).
- [x] Palette desert rally centralizzata in `ArtDirection`.
- [x] Auto arricchite con pannelli PrismMesh, roll-bar, fari rally, paraspruzzi, cerchi e dettagli differenziati.
- [x] Rollio, beccheggio, affondamento e particelle posteriori per superficie.
- [x] Tappa artigianale di 64 segmenti con salita, dosso, discesa, tornante, S, asfalto e traguardo.
- [x] Quote e pendenze applicate alle trasformazioni/collisioni reali dei segmenti.
- [x] Archi partenza/checkpoint/traguardo e pubblico contestuale nei tornanti.
- [x] Ostacoli casuali disabilitati nella Prova Speciale; layout deterministico e percorribile.
- [x] Tre atmosfere F4: mattino, tramonto, polvere coperta.
- [x] Camera avoidance tramite raycast nelle visuali esterne.
- [x] Flash danno, scintille collisione e audio distinto per start/checkpoint/finish.
- [x] Teardown test corretto: nessun avviso ObjectDB residuo nell'esecuzione finale.
- [x] Parser e suite runtime completi: PASS.
- [ ] Qualità estetica, clipping delle quattro camere e densità particelle richiedono test visivo utente.

## 2026-07-17 — Conversione rally simcade

- [x] Checkpoint stabile pre-conversione creato nel repository reale (`93e9f00`).
- [x] Parametri simcade centralizzati: massa, freni, freno motore, risposta sterzo e stabilità.
- [x] Trasferimenti di carico longitudinali/laterali e perdita progressiva di grip.
- [x] Quattro superfici: asfalto, ghiaia, sabbia e sabbia profonda.
- [x] Prova Speciale con route effettiva di circa 3.328 m (64 segmenti da 52 m), countdown, sei checkpoint, tempo e penalità; il precedente riferimento a 3.200 m era documentazione obsoleta.
- [x] Endurance preservata come modalità separata.
- [x] Note copilota geometriche con direzione, severità e distanza.
- [x] HUD rally con marcia, RPM, superficie, tempo, penalità e checkpoint.
- [x] Quattro telecamere selezionabili con C.
- [x] Danni leggeri a precisione sterzo e accelerazione.
- [x] Test automatici: auto, superfici, recupero, note, countdown, checkpoint, traguardo, audio PASS.
- [ ] Feeling simcade, leggibilità visiva e mix audio richiedono test umano.

## 2026-07-17 — Correzione dopo test manuale

- [x] Creato checkpoint dello stato testato manualmente (`ce2aa8b` nel progetto reale).
- [x] Individuata la causa bloccante: gradino collisionale invisibile di 17,5 cm fra sabbia e asfalto.
- [x] Unificato il piano collisionale e verificato attraversamento reale del bordo in entrata.
- [x] Aggiunti sterzo a bassa velocità, allineamento, trazione di rientro e retromarcia verificata.
- [x] Aggiunti ultimo punto sicuro, reset R, penalità, limite morbido e limite rigido.
- [x] Aggiunti avviso HUD, freccia direzionale e telemetria F3.
- [x] Aggiunto audio PCM originale: motore dinamico, musica, collisione, bonus, turbo e game over.
- [x] Aggiunti volumi separati musica/effetti e mute persistenti.
- [x] Aggiunti pattern di curve medie, S e U ampia multi-segmento.
- [x] Aggiunti paletti catarifrangenti, dune, cespugli, anelli bonus e cerchi ruota.
- [x] Test automatico: rientro reale, permanenza, retromarcia, limite, curve, spawn e audio PASS.
- [ ] Test manuale utente richiesto per giudicare feeling, mix audio e resa visiva nella finestra grafica.

## 2026-07-17 — Ripresa dopo spostamento

- [x] Individuato progetto effettivo: `D:\DPROGETTIDESERT-RACER-GODOT\DESERT-RACER-GODOT`.
- [x] Individuato Godot 4.7.1: `D:\DPROGETTIDESERT-RACER-GODOT\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe`.
- [x] Eseguito caricamento editor headless iniziale senza errori di parser.
- [x] Separata velocità longitudinale/laterale e aggiunti limite slip, grip dinamico e steering damping.
- [x] Ribilanciate muscle car e GT con valori centralizzati.
- [x] Aggiunto recupero di trazione contestuale sulla sabbia.
- [x] Aggiunta sequenza procedurale rettilineo-curva-rettilineo con segmenti realmente trasformati.
- [x] Spawn e collisioni ora seguono la trasformazione locale dei segmenti.
- [x] Migliorata leggibilità di ostacoli, bonus emissivi, anelli luminosi, cactus e rocce.
- [x] Test runtime automatizzati: muscle 4,09→0,98 m/s laterali; GT 2,95→0,00; curve sinistra/destra e spawn trasformati PASS.
- [x] Patch applicata al percorso spostato nel commit `507ce90`.
- [x] Parser/editor Godot 4.7.1 sul percorso reale: PASS senza errori.
- [x] Boot headless del gioco sul percorso reale: PASS, exit code 0.
- [x] Test fisico finale sul percorso reale: muscle 3,86→0,00 m/s laterali; GT 2,95→0,00; curve e spawn PASS.

## 2026-07-17

- [x] Verificata la cartella corrente e preservato il progetto web preesistente `DESERT-RACER`.
- [x] Creato progetto Godot isolato in `DESERT-RACER-GODOT`.
- [x] Inizializzati renderer GL Compatibility, risoluzione 1280×720 e input desktop.
- [x] Fondamenta dati/salvataggi, menu principale e impostazioni.
- [x] Garage 3D con piattaforma rotante e due veicoli originali selezionabili.
- [x] Guida arcade, telecamera, strada a 9 segmenti riciclati, 5 raccolte e 6 ostacoli.
- [x] HUD, pausa, game over, record e difficoltà progressiva di base.
- [x] Controllo statico di struttura, riferimenti `res://`, collisioni e stato Git.
- [x] Documentazione di avvio, controlli ed esportazione Windows/Web.
- [ ] Test parser e runtime reale non eseguibile: Godot 4 non è installato o rilevabile in questo ambiente.

## Ambiente di verifica

- Git CLI presente, ma la cartella principale non è riconosciuta come worktree Git valido.
- Godot non trovato nel PATH né nelle posizioni comuni esaminate; verifica runtime da completare se disponibile.
- Repository Git locale inizializzato nel progetto; commit iniziale creato e aggiornamenti finali versionati.
