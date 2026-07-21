# Desert Velocity

Gioco di guida arcade 3D low-poly per Godot 4, autonomo e senza dipendenze esterne.

Percorso effettivo del progetto: `D:\DPROGETTIDESERT-RACER-GODOT\DESERT-RACER-GODOT`.

Eseguibile verificato: `D:\DPROGETTIDESERT-RACER-GODOT\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe`.

Blender verificato: `C:\Program Files\Blender Foundation\Blender 4.5\blender.exe` (`Blender 4.5.11 LTS`).

## Pipeline artistica Blender

- Sorgenti modificabili in `source_art/blender/`.
- Modelli usati da Godot in formato GLB dentro `assets/models/`.
- `source_art/blender/scripts/build_visual_prototype.py` rigenera vettura e ambiente con contenuti originali.
- `scenes/visual/VisualPrototype.tscn` è isolata e non modifica fisica, collisioni o gameplay.
- I materiali del prototipo sono procedurali e compatibili glTF; non richiedono bitmap esterne in questa fase.
- Le cinque viste di controllo sono in `screenshots/visual_prototype/`.

### Prototipo V2 non integrato

- Sorgente: `source_art/blender/vehicles/desert_stallion_65_v2.blend`.
- Esportazione: `assets/models/vehicles/desert_stallion_65_v2.glb`.
- Scena isolata: `scenes/visual/VisualPrototypeV2.tscn`.
- Texture originali 1024×1024: base color, roughness, sporco, graffi e variazione vernice in `assets/textures/vehicles/`.
- Serie neutra e ambientata: `screenshots/visual_prototype_v2/`.
- La V1 resta conservata e la V2 non è collegata al controller, alla fisica o al gameplay.

### Integrazione Stallion V2

- La Desert Stallion usa `desert_stallion_65_v2.glb` in garage e gameplay.
- `VehicleFactory.use_blender_stallion_v2 = true` abilita l’asset; in caso di caricamento fallito viene istanziato automaticamente il modello procedurale precedente.
- Il GLB è figlio di un wrapper visivo separato dal `CharacterBody3D` e dalla collisione stabile `2.5 × 1.25 × 4.7 m`.
- I pivot `Wheel_FL`, `Wheel_FR`, `Wheel_RL`, `Wheel_RR` ricevono rotazione e sterzo dal controller; rollio, beccheggio e affondamento restano sul wrapper.
- La GT e i relativi offset camera non sono stati modificati.
- Screenshot e metriche sono in `screenshots/stallion_v2_integration/` e `reports/stallion_v2_integration_metrics.txt`.

### Blockout Desert Stallion V3 isolato

- Il sorgente modificabile e riproducibile è `source_art/blender/vehicles/desert_stallion_v3.blend`; gli script di costruzione ed esportazione sono in `source_art/blender/scripts/`.
- Il GLB di blockout è `assets/models/vehicles/desert_stallion_v3_blockout.glb`, istanziato soltanto dal wrapper `scenes/visual/assets/DesertStallionV3Blockout.tscn`.
- La review neutra `scenes/visual/StallionV3BlockoutReview.tscn` confronta V3 e V2 senza collegare il nuovo modello a factory, controller, fisica o gameplay.
- La revisione D1.1 sostituisce il precedente linguaggio da roadster con muso sfaccettato, parafanghi separati, canopy verticale, roll-cage dominante, sospensioni esposte e retrotreno meccanico aperto.
- Il blockout usa sette materiali di servizio senza texture e non include UV/PBR, baking, LOD definitivi o integrazione di produzione.
- Le dodici viste tecniche 1280×720 sono in `screenshots/stallion_v3_review/blockout/`; metriche e test restano soggetti ad approvazione visiva manuale prima di ogni fase successiva.

### Desert Stallion V3 visual review isolata

- Asset finale: `assets/models/vehicles/desert_stallion_v3.glb`; LOD manuali separati in `desert_stallion_v3_lod1.glb` e `desert_stallion_v3_lod2.glb`.
- Budget: LOD0 54.268 triangoli, LOD1 27.670, LOD2 10.574; 14 mesh renderizzabili e 7 materiali. Il LOD0 resta lievemente sotto il target indicativo perché non è stato aggiunto dettaglio privo di funzione.
- Le cinque mappe PBR originali e riproducibili sono in `assets/textures/vehicles/stallion_v3/`: base color, normal e ORM 2048²; dirt/damage mask ed emissive 1024².
- Il wrapper `scenes/visual/assets/DesertStallionV3Visual.tscn` gestisce Rally Sand, Night Raid e clay, oltre alla selezione manuale dei LOD; non è collegato a `VehicleFactory` o al gameplay.
- La scena isolata `scenes/visual/StallionV3VisualReview.tscn` include luce neutra/tramonto, confronto V2/V3, viste tecniche e pannello metriche. Le quattordici catture reali sono in `screenshots/stallion_v3_review/visual/`.
- La revisione D2.1 ricostruisce nel wrapper i sette slot materiali rimossi dall'export GLB placeholder e mantiene la vernice dielettrica, senza modificare geometria o asset esportati.
- I preset Studio Neutral, Outdoor Daylight e Sunset e le modalità Base Color, Roughness, Metallic, Normal, AO, Clay e Final PBR sono disponibili soltanto nella review isolata.
- Stato della D2.1: **MANUAL VISUAL APPROVAL — DESERT STALLION V3 APPROVED FOR CONTINUED DEVELOPMENT**; la V3 resta non integrata in `VehicleFactory`, vertical slice o scene di produzione.

### Environment Kit V2 blockout isolato

- Sorgente riproducibile: `source_art/blender/environment/environment_kit_v2_blockout.blend`, costruito ed esportato dagli script dedicati in `source_art/blender/scripts/`.
- Il GLB `assets/models/environment/environment_kit_v2_blockout.glb` contiene 40 moduli nominati e separati con 10.474 triangoli e 7 materiali clay condivisi.
- Il kit comprende rocce hero/medie/piccole, arco, canyon, mesa, vegetazione, segnaletica, barriera, relitto, dune, bordi strada e detriti; non contiene texture o LOD finali.
- La scena `scenes/visual/EnvironmentKitV2BlockoutReview.tscn` è isolata da gameplay e vertical slice e produce le catture tecniche in `screenshots/environment_kit_v2_review/blockout/`.
- La revisione geometrica E1.1 concentra 26.982 triangoli su HeroRock A/B/C, CanyonWall A/B e RockArch, lasciando invariati gli altri 34 moduli e i sette materiali clay.
- Hero A è una massa bassa con blocchi crollati; Hero B sviluppa due terrazze orizzontali; Hero C usa un contrafforte a base larga con cresta spezzata e cavità laterale.
- Le pareti aggiornate usano piani continui, terrazze, rientranze, contrafforti irregolari, falde e spalle terminali; l'arco raggiunge circa 17 m di luce e 10 m di cresta con Stallion V3 usata soltanto come riferimento di scala nella review.
- Le quattordici catture E1.1 sono in `screenshots/environment_kit_v2_review/blockout/`; stato: **AWAITING MANUAL VISUAL APPROVAL** prima di UV, PBR, atlas, LOD, MultiMesh o integrazione.

### Environment Kit V2 visual review isolata

- Il sorgente finale riproducibile è `source_art/blender/environment/environment_kit_v2.blend`; i tre GLB manuali sono `assets/models/environment/environment_v2_lod0.glb`, `environment_v2_lod1.glb` e `environment_v2_lod2.glb`.
- Le silhouette E1.1 approvate restano invariate; i budget sono LOD0 26.982, LOD1 16.495 e LOD2 9.346 triangoli, con 40 asset modulari per livello.
- Quattro atlanti originali separano materiali naturali, strada, props e vegetazione. Ogni atlas usa base color, normal e ORM; le dodici mappe sono in `assets/textures/environment/environment_v2/`.
- Il wrapper isolato `scenes/visual/assets/EnvironmentKitV2.tscn` ricostruisce nove materiali PBR condivisi, seleziona i LOD e aggiunge soltanto collisioni box di review e tre gruppi MultiMesh.
- La scena `scenes/visual/EnvironmentKitV2VisualReview.tscn` offre preset studio/daylight/sunset, clay/final PBR, confronto blockout/finale, confronto LOD e riferimento di scala Stallion V3 senza integrare il kit nel gioco.
- Le sedici catture tecniche reali 1280×720 sono in `screenshots/environment_kit_v2_review/visual/`; le metriche MX150 sono in `reports/environment_kit_v2_metrics.txt`.
- Stato E2: **AWAITING MANUAL VISUAL APPROVAL**. Vertical slice, gameplay e scene di produzione restano invariati.

### Environment Kit V2 visual polish E2.1

- La review E2.1 usa lo shader dedicato `assets/shaders/environment_v2_polish.gdshader` sui nove materiali condivisi; GLB, Blender, UV, LOD e silhouette E1.1 restano invariati.
- Tre preset documentati sono disponibili: Daylight Neutral (esposizione 0,84), Golden Hour principale (0,90) e Sunset Cinematic (0,88), tutti con ACES, cielo procedurale e fill freddo compatibili con GL Compatibility.
- Terreno e strada della sola review usano mesh suddivise leggere, variazione procedurale, rilievo locale e bordi irregolari; talus e raccordi sono aggregati con MultiMesh per evitare duplicazioni di nodi.
- Le quattordici catture reali E2.1 sono in `screenshots/environment_kit_v2_review/visual_polish/`, incluso il confronto diretto prima/dopo.
- Stato E2.1: **AWAITING MANUAL VISUAL APPROVAL**. Il kit non è integrato nella vertical slice o nelle scene di produzione.

### Premium Vertical Slice V2 isolata

- `scenes/visual/PremiumVerticalSliceV2.tscn` combina Desert Stallion V3 Rally Sand LOD0, seconda V3 Night Raid LOD1, Environment Kit V2 E2.1 e preset Golden Hour senza modificare il gioco principale.
- La presentazione usa esclusivamente Path3D/PathFollow3D: dura 38 secondi, parte e termina automaticamente e non istanzia controller, fisica, GameManager, salvataggi o progressione di produzione.
- Il percorso comprende curva, sorpasso, discesa, canyon, ostacolo, dosso, boost meccanico e uscita attraverso RockArch; camera, HUD, polvere, boost e audio sono componenti locali in `scenes/visual/vertical_slice_v2/`.
- Le quattordici catture reali 1280×720 sono in `screenshots/premium_vertical_slice_v2/`; le metriche MX150 della sequenza continua sono in `reports/premium_vertical_slice_v2_metrics.txt`.
- Stato F1: **AWAITING MANUAL VISUAL APPROVAL**. `PremiumVerticalSlice.tscn` V1 resta intatta come confronto e fallback; nessuna integrazione di produzione è stata eseguita.

### Premium Vertical Slice V2 revisione F1.1

- La revisione corregge esclusivamente composizione, camera, superfici e presentazione della scena isolata: percorso, durata di 38 secondi, sequenza automatica, Stallion V3 ed Environment Kit V2 originali restano invariati.
- Camera chase: distanza 6,20 m, altezza 2,15 m, FOV 68° con massimo 74° in boost e look-ahead 18 m; le viste normali mantengono la protagonista intorno al 23–24% dell'altezza schermo.
- Lo shader locale `assets/shaders/vertical_slice_v2/premium_slice_surface.gdshader` deriva il linguaggio E2.1 senza modificare i materiali base: sabbia calda, compatto, ghiaia, strada scura, tracce e banchine irregolari sono ora distinti.
- Sette gruppi MultiMesh aggregano 310 elementi ambientali; polvere, boost caldo, HUD e regia dell'arco sono stati rifiniti soltanto nei componenti F1.1.
- Le quattordici catture reali revisionate sono in `screenshots/premium_vertical_slice_v2/revision/`; le metriche MX150 della sequenza continua sono in `reports/premium_vertical_slice_v2_metrics.txt`.
- Stato F1.1: **AWAITING MANUAL VISUAL APPROVAL**. Nessuna modifica o integrazione nel gioco principale.

### Premium Vertical Slice V2 motion review F1.2

- La F1.1 isolata ha ricevuto approvazione visiva manuale; la F1.2 verifica esclusivamente la sequenza in movimento e non integra la scena nel gioco.
- La cattura nativa Godot è `captures/premium_vertical_slice_v2/premium_vertical_slice_v2_motion_review.avi`: 1280×720, 60 FPS, 2.281 frame, durata 38:01 e stream audio incluso.
- Quattordici frame tecnici distribuiti tra partenza, curva, sorpasso, discesa, canyon, ostacolo, salto, boost e arco sono in `screenshots/premium_vertical_slice_v2/motion_review/`.
- Una correzione locale sposta il gruppo ostacolo verso la spalla destra e riduce soltanto la scala dell'istanza principale, eliminando l'occlusione grave osservata nella prima registrazione senza cambiare asset sorgenti, percorso o camera.
- La verifica a 60 FPS misura 0,289 m/frame e 0,0031 rad/frame come massimi passi camera, copertura massima dell'ostacolo 31,0% e variazione polvere 0,0079/frame.
- Metriche MX150 real-time: media 59,97 FPS, minimo sostenuto 57,99 FPS, 455 draw call, 487.433 primitive, 357 nodi e 44,08 MB.
- Stato F1.2: **AWAITING MANUAL MOTION APPROVAL**. Produzione, gameplay, fisica e controller restano invariati.

### Gameplay baseline hardening G1-B

- Il gioco reale resta avviato da `scenes/main/Boot.tscn`; grafica, fisica, controlli, percorso, checkpoint, salvataggi e progressione non sono stati riprogettati.
- Il punteggio di guida conserva il ritmo teorico `|velocità| × moltiplicatore × 0,8` punti/s usando un residuo frazionario tra frame. Il test deterministico produce 152 punti a 30, 60 e 120 FPS contro 152,24 teorici.
- Test dedicati proteggono carburante, integrità, atterraggio, turbo, moltiplicatore, record, timer, penalità, checkpoint, fine gara, riavvio, binding HUD e salvataggi in storage temporaneo isolato.
- La route di Prova Speciale resta invariata a 64 segmenti da 52 m, circa 3.328 m; il precedente riferimento a 3.200 m era documentazione obsoleta.
- La baseline MX150 del gameplay reale è in `reports/gameplay_runtime_baseline_before_visual_integration.txt`: 60,58 FPS medi, P5 58,42, minimo sostenuto 58,14, nessuno stutter ricorrente, 823 draw call, 100.146 primitive, 860 nodi, 51,32 MB e caricamento 368,65 ms.
- Stato G1-B: **READY FOR PLAYABLE VISUAL INTEGRATION PILOT**. L'integrazione grafica G1 non è iniziata.

### Environment Kit V2 playable visual polish G1-D.1

- La revisione resta confinata ai 520 m dei segmenti 0-9: terreno, banchine, palette, illuminazione e composizione sono locali al wrapper G1-D; route, collider e larghezza logica non cambiano.
- Due shader in `assets/shaders/production_visual_pilot/` preservano texture e materiali E2.1/F1.1 sorgenti: cinque famiglie rocciose attenuate distinguono ocra, terra bruciata, marrone e grigio caldo, con superfici superiori più chiare e fratture più scure.
- Il terreno visuale usa rilievo continuo, avvallamenti, terrapieni e raccordo all'underlay. Dune, ghiaia e piccoli massi formano gruppi di contatto; due MultiMesh dedicati distribuiscono talus e frammenti attorno alle formazioni.
- Strada e banchine usano bordi suddivisi e fasce di sabbia irregolari, centro consumato, doppia traccia e roughness variabile senza modificare collider o superfici fisiche.
- LOD0/1/2: 3/36/370 istanze; sette MultiMesh aggregano 368 elementi. MX150: 60,67 FPS medi, P5 56,03, minimo sostenuto 59,11, 750 draw call, 271.644 primitive, 972 nodi, 54,65 MB e caricamento warm 535,37 ms.
- Report e dodici catture gameplay reali sono in `reports/environment_v2_playable_visual_polish_metrics.txt` e `screenshots/playable_visual_integration_pilot/environment_g1d1/`.

### Full-stage zone identity polish G1-F.1

- Le sette zone mantengono gli stessi confini e la stessa route G1-F, ma ora usano silhouette, densità, palette e landmark distinti: start paddock, corridoio eroso, canyon fins, plateau panoramico, relitto tra dune, passaggio tecnico e porta naturale finale.
- I gate visuali `PARTENZA` e `TRAGUARDO` sostituiscono i vecchi archi rossi senza collider o modifiche ai trigger. RockArch_A resta rinviato; il finale usa due canyon fins asimmetriche e aperte.
- Lo scatter è stato redistribuito e ridotto a 690 istanze MultiMesh; 4 elementi LOD0, 70 LOD1 e 646 LOD2 mantengono spazio negativo e contatto col terreno.
- MX150 warm a 1280×720: 59,98 FPS medi, P5 58,94, minimo sostenuto 59,83, 500 draw call, 249.534 primitive, 1.163 nodi, 66,15 MB e warm load 824,37 ms, senza stutter ricorrente o popping grave.
- Il valore HUD `0 m` non è persistente: compare soltanto per un campione sul target pacenote finale clampato; il fixture automatico senza look-ahead spiegava le catture precedenti.
- Report e 24 catture gameplay reali: `reports/full_special_stage_zone_identity_polish_metrics.txt`, `reports/full_special_stage_zone_review.txt` e `screenshots/playable_visual_integration_pilot/g1f1/`. Stato: **AWAITING MANUAL FULL STAGE VISUAL APPROVAL**.

### Full Special Stage visual expansion G1-F

- Il pacchetto approvato G1-D.1/G1-E.1 copre ora tutti i 64 segmenti e 3.328 m della Prova Speciale, suddivisi in sette zone desertiche progressive senza cambiare route, superfici logiche, salti, ostacoli o checkpoint.
- Strada e terreno sono combinati per zona; landmark LOD0/1 e scatter LOD2 MultiMesh usano solo Environment Kit V2 e materiali derivati dagli shader approvati. Visibility range con margine limita il costo senza caricamenti asincroni.
- CP01–CP06 sono leggibili e collision-free. RockArch_A è rinviato per proteggere CP5 e la curva 50–54; due canyon fins laterali costituiscono l’alternativa sicura.
- La gara controllata completa da Boot raggiunge in ordine i sei checkpoint e il traguardo. Il flag locale ripristina prima il pilot 0–9 e poi lo scenario originale; Stallion V2 resta disponibile.
- MX150 warm a 1280×720: 60,01 FPS medi, P5 58,97, minimo sostenuto 59,88, 484 draw call, 249.330 primitive, 1.097 nodi, 61,30 MB, cold load 3.940,36 ms, warm load 1.093,61 ms e nessuno stutter ricorrente.
- Report e ventidue catture reali sono in `reports/full_special_stage_visual_expansion_metrics.txt` e `screenshots/playable_visual_integration_pilot/g1f/`. Stato: **AWAITING MANUAL FULL STAGE VISUAL APPROVAL**.

### HUD compactness and effects readability polish G1-E.1

- La polvere G1-E è ora più bassa, arretrata, desaturata e direzionale, quasi assente su asfalto e più leggibile su gravel/sand/deep sand senza coprire il retrotreno.
- Boost, landing burst e scintille usano forme brevi e distinte: scarichi affusolati senza luce dinamica, impulso di atterraggio radiale con frammenti e scintille rare su urti significativi.
- L'HUD conserva tutti i dati e le firme pubbliche ma riduce l'ingombro di circa il 18%; il portale `CP 01` e il feedback `CHECKPOINT 1/6` hanno maggiore separazione e impulso breve.
- Metriche MX150 warm a 1280×720: media 60,43 FPS, P5 57,56, minimo sostenuto 58,97, 757 draw call, 184.774 primitive, 997 nodi, 60,01 MB, load 1.240,28 ms e nessuno stutter ricorrente.
- Report e quattordici catture reali sono in `reports/gameplay_visual_effects_hud_polish_metrics.txt` e `screenshots/playable_visual_integration_pilot/g1e1/`. Stato: **AWAITING MANUAL GAMEPLAY VISUAL APPROVAL**.

### Gameplay visual effects and HUD pilot G1-E

- Il wrapper Stallion V3 aggancia in modo reversibile `GameplayVisualEffectsPilot.tscn`; `StallionV3PlayableVisual.use_g1e_gameplay_visual_effects` conserva il fallback tecnico per le baseline storiche, mentre V2 e scenario originale restano indipendenti.
- Polvere posteriore, atterraggio, boost e scintille leggono esclusivamente stato e segnali già esistenti del `VehicleController`; non scrivono velocità, turbo, danno, superficie, fisica o checkpoint.
- L'HUD di produzione mantiene metodi, riferimenti pubblici, valori e formati gameplay, con una presentazione semitrasparente antracite/ocra e centro visuale libero.
- Il portale `CP 01` è un overlay privo di collider sul dettaglio visuale del segmento 9; GameManager, trigger, ordine e conteggio checkpoint non cambiano.
- Metriche MX150 warm a 1280×720: media 60,90 FPS, P5 58,35, minimo sostenuto 59,13, 738 draw call, 250.498 primitive, 993 nodi, 57,19 MB, load 1.332,13 ms e nessuno stutter ricorrente.
- Report e quattordici catture reali sono in `reports/gameplay_visual_effects_hud_pilot_metrics.txt` e `screenshots/playable_visual_integration_pilot/g1e/`. Stato: **AWAITING MANUAL GAMEPLAY VISUAL APPROVAL**.
- Stato G1-D.1: **AWAITING MANUAL PLAYABLE ENVIRONMENT APPROVAL**. RockArch e conversione del resto del percorso restano esclusi.

### Environment Kit V2 playable scenario pilot G1-D

- La Prova Speciale reale avviata da `scenes/main/Boot.tscn` usa Environment Kit V2 nella sola tratta 0-9: 520 m con rettilineo iniziale, curva e checkpoint 1 sul segmento 9.
- `RoadManager.use_environment_v2_playable_pilot` aggancia un wrapper esclusivamente visuale e reversibile; disattivando il flag restano disponibili strada, terreno e scenario originali. Route, larghezza logica, superfici, collider, ostacoli e checkpoint non cambiano.
- La tratta usa strada/terreno F1.1, underlay suddiviso anti-gap, shader/materiali E2.1, Golden Hour locale, HeroRock A/B/C, CanyonWall A/B, Mesa A/B, rocce, dune, cactus, cespugli, cartelli, barriera, relitto, ghiaia e detriti. RockArch è rimandato per evitare clipping e occlusione del checkpoint.
- LOD0/1/2 sono distribuiti come 3/31/228 istanze; cinque MultiMesh aggregano 226 elementi. Il pilot non introduce CollisionObject3D e conserva 22 CollisionShape3D, identiche al fallback.
- MX150 / GL Compatibility / 1280x720: 60,53 FPS medi, P5 56,43, minimo sostenuto 59,14, nessuno stutter ricorrente; 758 draw call, 233.572 primitive, 945 nodi, 54,71 MB e caricamento 614,70 ms.
- Report e quattordici catture gameplay reali sono in `reports/environment_v2_playable_scenario_pilot_metrics.txt` e `screenshots/playable_visual_integration_pilot/environment_g1d/`.
- Stato G1-D: **AWAITING MANUAL PLAYABLE ENVIRONMENT APPROVAL**. Camera approvata, Stallion V3 LOD1, gameplay, fisica, route, checkpoint, HUD e salvataggi restano invariati.

### Stallion V3 runtime optimization repair G1-C.1B

- Il gameplay usa un singolo LOD1 Rally Sand precomputato in `scenes/visual/production/runtime_optimized/`; LOD0 e LOD2 non sono precaricati e non esiste commutazione durante la normale camera chase.
- Sei gruppi statici sono aggregati offline per categoria materiale; le quattro gerarchie ruota restano separate e animate. Il runtime carica 10 MeshInstance3D, 14 superfici, 27.670 triangoli e sette materiali condivisi senza eseguire `SurfaceTool` durante boot o istanziazione.
- Lo script riproducibile in `scripts/tools/stallion_v3_runtime_optimization/` deriva la risorsa esclusivamente dal GLB LOD1 approvato, senza modificare GLB, texture, materiali o geometria sorgente.
- MX150 / GL Compatibility / 1280x720: 61,27 FPS medi, P5 57,59, minimo sostenuto 59,29, P99 18,311 ms, nessuno stutter stabile; 762 draw call, 98.900 primitive, 848 nodi, 51,29 MB e Boot/STAGE medio 329,29 ms su tre misurazioni.
- Report e otto catture controllate sono in `reports/stallion_v3_runtime_optimization_repair_metrics.txt` e `screenshots/playable_camera_v3_optimization/runtime_repair/`.
- Stato G1-C.1B: **AWAITING MANUAL V3 RUNTIME OPTIMIZATION APPROVAL**. Camera G1-C.1A, gameplay, fisica, collisioni, controller, HUD e scenario sono invariati.

### Dynamic playable camera repair G1-C.1A

- La chase camera della sola Stallion V3 usa ora inseguimento esponenziale indipendente dal frame rate, errore massimo controllato e damping separato della rotazione; le altre vetture e le altre viste camera conservano il comportamento precedente.
- Il profilo finale usa distanza 9,80 m, altezza 2,90 m, look-ahead 8,50 m e look-height 4,50 m; durante il boost la distanza obiettivo scende a 8,60 m. FOV normale 70 gradi e boost 79 gradi restano invariati.
- La verifica da `Boot.tscn` copre confronto statico controllato, rettilineo, alta velocita, curva, boost, dosso e fuoristrada. L'occupazione dinamica resta 17,52-22,60% e il centro verticale 69,67-74,02%, senza permanenze fuori soglia.
- Metriche e dieci catture 1280x720 sono in `reports/playable_camera_dynamic_repair_metrics.txt` e `screenshots/playable_camera_v3_optimization/dynamic_repair/`.
- Stato G1-C.1A: **AWAITING MANUAL DYNAMIC CAMERA APPROVAL**. LOD/runtime, wrapper V3, asset Stallion, gameplay, fisica, collisioni, route, checkpoint e HUD non sono stati modificati da questa fase.

### Stallion V3 playable visual pilot G1-C

- La Prova Speciale reale avviata da `scenes/main/Boot.tscn` usa ora Desert Stallion V3 Rally Sand LOD0 come visuale predefinita tramite `VehicleFactory.use_stallion_v3_visual_pilot`.
- Stallion V2 non è stato rimosso: disattivando il flag V3, o se il wrapper V3 non viene caricato, il factory usa la funzione V2 già esistente prima del fallback procedurale.
- Il wrapper produttivo è `scenes/visual/production/StallionV3PlayableVisual.tscn`; GLB sorgente, `VehicleController`, collisione semplificata, fisica, statistiche, controlli, camera, route, checkpoint e HUD non sono stati modificati.
- Le metriche MX150 e la caratterizzazione tecnica sono in `reports/stallion_v3_playable_visual_pilot_metrics.txt`; le cinque prove visive reali sono in `screenshots/playable_visual_integration_pilot/`.
- Stato G1-C: **AWAITING MANUAL PLAYABLE VEHICLE APPROVAL**. Environment Kit, strada/terreno, luci, polvere V2, Boost V2 e HUD V2 non sono integrati.

## Avvio

1. Installare Godot 4.3 o successivo.
2. In Project Manager scegliere **Import**.
3. Selezionare `project.godot` in questa cartella.
4. Premere **F6/F5** o il pulsante Play.

## Controlli

- W / Freccia su: accelera
- S / Freccia giù: frena e retromarcia
- A-D / Frecce: sterza
- Spazio: freno a mano
- C: cambia distanza telecamera
- Esc: pausa
- Invio: conferma nei menu
- R: recupero sull'ultimo punto sicuro con penalità
- F3: telemetria debug (grip, slip, terreno e direzione strada)
- F4: alterna mattino limpido, tramonto caldo e polvere atmosferica

Il gioco genera localmente audio PCM originale per motore, musica ed effetti. Musica, effetti e mute sono regolabili separatamente nelle impostazioni.

Le impostazioni includono inoltre preset grafici Bassa, Media e Alta, che regolano quantità delle particelle e ombre dinamiche.

## Modalità rally

- **Prova Speciale**: partenza 3-2-1-VIA, route effettiva di circa 3.328 metri (64 segmenti da 52 m), sei checkpoint, cronometro, penalità e risultato finale.
- **Endurance**: conserva il loop arcade infinito, punteggio, carburante e raccolte.
- Superfici: asfalto, ghiaia, sabbia e sabbia profonda, tutte sullo stesso piano collisionale.
- Il copilota mostra nota, direzione e distanza in base ai segmenti realmente davanti al veicolo.
- Il tasto C alterna esterna ravvicinata, esterna larga, cofano e paraurti.

## Esportazione Windows

Installare gli Export Templates dalla voce Editor, aprire **Project > Export**, aggiungere il preset **Windows Desktop**, scegliere una cartella di destinazione e premere **Export Project**.

## Esportazione Web

Il renderer è `gl_compatibility`. In **Project > Export** aggiungere il preset **Web**, scegliere `index.html` come destinazione e premere **Export Project**. Pubblicare l'intera cartella generata tramite un server HTTP/HTTPS; l'apertura diretta come file locale non è supportata dai browser.

## Risorse e licenze

Tutta la grafica è costruita a runtime da primitive Godot e materiali originali. Non sono inclusi modelli, texture, marchi, sponsor, font o audio di terze parti.

## Architettura

- `data/`: statistiche veicoli e bilanciamento
- `scripts/game_manager.gd`: flusso menu/garage/partita/pausa/game over
- `scripts/vehicle_controller.gd`: guida arcade
- `scripts/vehicle_factory.gd`: modelli low-poly originali
- `scripts/road_manager.gd`: segmenti riciclati, scenario, raccolte e ostacoli
- `scripts/camera_controller.gd`: inseguimento, FOV turbo e shake
- `scripts/hud.gd`: HUD di gioco
- `scripts/save_manager.gd`: record, veicolo e volume con ConfigFile
- `scripts/audio_manager.gd`: punto di integrazione audio opzionale
