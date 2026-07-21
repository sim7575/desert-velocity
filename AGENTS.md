# AGENTS.md — Desert Velocity

## Missione
Evolvere Desert Velocity da prototipo rally 3D low-poly a titolo indie premium in stile **stylized realism**, preservando la base tecnica, la giocabilità e la stabilità già raggiunte.

## Regola assoluta: protezione del lavoro
1. Prima di modificare qualunque file, eseguire `git status --short` e descrivere il diff esistente.
2. Non usare mai `git reset --hard`, `git clean -fd`, checkout distruttivi o comandi equivalenti senza autorizzazione esplicita.
3. Non scartare né sovrascrivere modifiche non committate dell'utente.
4. Prima di ogni nuova fase creare un checkpoint Git, ma soltanto dopo aver verificato che parser, boot e test pertinenti siano superati.
5. Le modifiche artistiche devono rimanere separabili e reversibili.

## Gerarchia delle fonti
1. `DESERT_VELOCITY_ART_DIRECTION.md` — obiettivo visivo e criteri di approvazione.
2. `README.md` e `PROGRESS.md` — stato, architettura e decisioni già prese.
3. Test automatici e scene di review — prova tecnica.
4. Codice e asset correnti — implementazione effettiva.
5. Prompt della singola attività — valido solo se non contraddice i documenti precedenti.

## Vincoli tecnici
- Motore: Godot 4.7, renderer GL Compatibility, target iniziale 1280×720 scalabile.
- Conservare `CharacterBody3D`, collisioni semplificate, statistiche veicolo, superfici, checkpoint, reset e modalità di gioco salvo richiesta esplicita.
- Non cambiare contemporaneamente grafica, fisica e bilanciamento.
- Le mesh visive devono restare figlie di wrapper separati dal corpo fisico.
- Conservare fallback procedurali finché il nuovo asset non supera tutti i test.
- Preferire scene isolate di review e vertical slice prima dell'integrazione generale.
- Non aumentare indiscriminatamente risoluzione o poligoni: misurare draw call, memoria, tempi di caricamento e FPS.

## Workflow obbligatorio per ogni fase
1. **Baseline**: stato Git, commit corrente, test pertinenti e screenshot prima.
2. **Piano minimo**: elencare file da modificare, invarianti e prova di completamento.
3. **Implementazione isolata**: una sola area o obiettivo per fase.
4. **Validazione automatica**: parser/import, boot, runtime e test mirati.
5. **Validazione visiva**: screenshot comparativi con stessa camera, ora e inquadratura.
6. **Metriche**: FPS, draw call, memoria e caricamento quando rilevanti.
7. **Review**: classificare PASS, PASS CON RISERVE o FAIL.
8. **Checkpoint**: commit descrittivo solo dopo i controlli.
9. **Aggiornamento**: registrare risultati e limiti in `PROGRESS.md`.

## Regole artistiche operative
- Non usare primitive nude o grandi blocchi geometrici visibili nella vertical slice finale.
- Evitare superfici uniformi prive di variazione cromatica, roughness e microdettaglio.
- Ogni primo piano deve avere silhouette, materiale, ombra e scala credibili.
- Il dettaglio deve diminuire con la distanza: hero, mid-ground, background.
- Polvere, nitro, motion cues e illuminazione devono sostenere velocità e leggibilità, non coprire il gameplay.
- La camera deve comunicare accelerazione senza compromettere controllo e visibilità degli ostacoli.
- HUD leggibile, moderno e non invasivo; evitare elementi provvisori nella cattura finale.

## Vertical slice
La prima milestone grafica è una scena isolata di 30–45 secondi con:
- una vettura approvata;
- un tratto di canyon completo;
- una curva leggibile, un salto controllato e un sorpasso/ostacolo;
- terreno stratificato, rocce organiche, vegetazione e props;
- luce cinematografica al tramonto;
- polvere e nitro;
- camera chase definitiva provvisoria;
- HUD di presentazione;
- screenshot e breve cattura comparativa.

La vertical slice non deve modificare Endurance o Prova Speciale finché non viene approvata manualmente.

## Divieti
- Nessun rifacimento totale del repository senza prova che l'architettura corrente impedisca l'obiettivo.
- Nessun asset esterno con licenza incerta.
- Nessuna affermazione di completamento senza test o prova visiva.
- Nessuna integrazione massiva dopo una singola immagine riuscita.
- Nessuna ottimizzazione prematura che degradi silhouette, materiali o illuminazione.
