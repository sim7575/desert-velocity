# Desert Velocity — Art Direction 2.0

## Visione
Desert Velocity è un racing arcade 3D ambientato in un deserto cinematografico. La nuova direzione è **stylized realism / indie premium**: forme chiare e caratterizzate, materiali credibili, luce cinematografica e forte sensazione di velocità, senza inseguire il fotorealismo AAA.

## Obiettivo visivo
Il gioco deve apparire come un prodotto intenzionale e pubblicabile, non come una demo costruita con primitive. L'immagine-obiettivo mostra una camera posteriore ravvicinata, strada inserita in un canyon stratificato, luce calda, traffico leggibile, polvere volumetrica, nitro e HUD moderno.

## Cosa conservare
- Identità desert rally.
- Veicoli originali e privi di marchi reali.
- Gameplay arcade/simcade accessibile.
- Prestazioni compatibili con desktop e Web.
- Palette calda già definita in `ArtDirection`.
- Separazione fra modello visivo e fisica.

## Cosa abbandonare nella presentazione finale
- Grandi parallelepipedi come rocce o canyon.
- Cactus a croce e props eccessivamente elementari in primo piano.
- Strada piatta e uniforme senza materiale, sporco, crepe o bordi naturali.
- Cielo piatto e illuminazione priva di atmosfera.
- Inquadratura distante che riduce l'auto a una piccola sagoma.
- HUD da prototipo e composizione visiva vuota.

## Pilastri visivi

### 1. Sensazione di velocità
- Camera chase più vicina e leggermente bassa.
- FOV dinamico moderato con accelerazione e nitro.
- Vibrazioni e shake controllati, mai continui.
- Scie di polvere, sassolini, deformazione visiva o motion cues compatibili col renderer.
- Elementi laterali che scorrono a velocità percepibile.

### 2. Deserto credibile
- Terreno con macro-variazione di colore e roughness.
- Microdettagli: ghiaia, pietre, crepe, tracce, sabbia accumulata.
- Rocce con silhouette irregolari, stratificazione e variazioni di scala.
- Canyon costruito su almeno tre piani di profondità.
- Vegetazione e props distribuiti con logica, evitando ripetizione evidente.

### 3. Luce cinematografica
- Golden hour come scenario principale della vertical slice.
- Sole radente, ombre lunghe e leggibili.
- Foschia atmosferica e separazione progressiva dei piani.
- Contrasto sufficiente sull'auto senza neri chiusi o superfici bruciate.
- Fari, fanali e nitro usati come accenti, non come unica fonte di spettacolarità.

### 4. Veicoli hero
- Silhouette riconoscibile anche in movimento.
- Materiali separati per vernice, vetro, gomma, metallo e plastica.
- Normali/smussature credibili sui bordi più importanti.
- Sporco, graffi e polvere localizzati, non texture uniformi.
- Ruote, sospensioni e rollio leggibili dalla camera posteriore.

### 5. Composizione e leggibilità
- Ostacoli distinguibili dallo sfondo con anticipo sufficiente.
- Strada chiaramente separata da banchina e terreno.
- Nessun effetto deve nascondere traiettoria, checkpoint o avversari.
- La scena deve avere foreground, mid-ground e background.

### 6. HUD premium
- Informazioni primarie: velocità, posizione/obiettivo, nitro, distanza o tempo.
- Informazioni secondarie ridotte o contestuali.
- Tipografia leggibile e allineamenti coerenti.
- Trasparenze e cornici discrete; evitare pannelli pesanti.
- Safe area per 16:9 e adattamento futuro a risoluzioni diverse.

## Palette iniziale
- Sabbia chiara: `#D59A55`
- Sabbia profonda: `#B9773D`
- Roccia rossa: `#7B3F2B`
- Roccia scura: `#432F2A`
- Asfalto: `#303238`
- Polvere: `#C99059`
- Tramonto: `#D87949`
- Accento pericolo: `#F2B632`

La palette può essere ampliata, ma deve mantenere contrasto caldo/freddo e separazione fra auto, strada e ambiente.

## Vertical Slice — contenuto minimo
Durata percepita: 30–45 secondi.

1. Partenza in rettilineo con canyon visibile in profondità.
2. Accelerazione e ingresso del FOV dinamico.
3. Curva ampia con props laterali e polvere.
4. Sorpasso di un veicolo o superamento di un ostacolo mobile.
5. Salto controllato con atterraggio leggibile.
6. Attivazione nitro verso un gate o punto scenografico finale.

## Lista asset della vertical slice

### Hero
- 1 veicolo giocatore rifinito.
- 1 veicolo avversario/traffico con LOD o dettaglio ridotto.

### Terreno e strada
- 1 materiale strada con variazione, bordi e segni d'usura.
- 1 materiale sabbia/ghiaia con macro e micro-variazione.
- 3–5 gruppi di rocce modulari organiche.
- 2 pareti/canyon modulari con stratificazione.
- Decal o mesh per tracce, crepe, sabbia sulla carreggiata.

### Props
- 3 varianti di cactus/vegetazione desertica.
- Cartelli direzionali, guardrail/barriere rally, pali o strutture leggere.
- Piccoli massi, detriti e oggetti di scala.
- 1 elemento memorabile: relitto, arco roccioso, torre o stazione abbandonata.

### Effetti
- Polvere ruote per asfalto, ghiaia e sabbia.
- Polvere atmosferica in profondità.
- Nitro e calore/scia compatibili con GL Compatibility.
- Scintille leggere per urti.

### UI
- Tachimetro/velocità.
- Barra nitro.
- Obiettivo o posizione.
- Indicatore di progresso/tempo.

## Budget tecnico iniziale
I valori sono obiettivi da misurare, non vincoli assoluti:
- 60 FPS a 1280×720 su macchina di sviluppo nella vertical slice.
- Draw call sensibilmente inferiori alle 606 misurate nella Stallion V2 integrata, oppure giustificate da un guadagno visivo evidente.
- Texture 1K per props, 2K solo per hero/terreno quando il dettaglio è visibile.
- LOD o semplificazione per elementi mid/background.
- Particelle con preset Bassa/Media/Alta.

## Gate di approvazione visiva
La vertical slice è approvata solo se:
1. a colpo d'occhio non sembra più il prototipo low-poly attuale;
2. l'ambiente ha almeno tre livelli di profondità;
3. strada e terreno mostrano materiale e variazione credibili;
4. auto e ostacoli restano leggibili durante la velocità massima;
5. luce, polvere e camera producono atmosfera senza ostacolare il controllo;
6. screenshot comparativi dimostrano un miglioramento sostanziale;
7. parser, boot, test e prestazioni restano accettabili.

## Non-obiettivi della prima fase
- Open world.
- Fotorealismo AAA.
- Distruzione complessa.
- Multiplayer.
- Rifacimento completo di tutte le piste e modalità.
- Acquisto o uso di asset esterni prima di una decisione esplicita sulle licenze.
