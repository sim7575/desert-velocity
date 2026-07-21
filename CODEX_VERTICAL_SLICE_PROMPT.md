# Prompt operativo per Codex — Vertical Slice grafica

Lavora nel repository reale di Desert Velocity. Prima di qualsiasi modifica leggi integralmente `AGENTS.md`, `DESERT_VELOCITY_ART_DIRECTION.md`, `README.md` e le sezioni più recenti di `PROGRESS.md`.

## Obiettivo
Creare una **vertical slice visiva isolata** di 30–45 secondi che dimostri il passaggio dal low-poly basilare allo stylized realism indie premium. Non integrare ancora il nuovo ambiente nelle modalità Endurance o Prova Speciale.

## Sicurezza iniziale obbligatoria
1. Mostra `git status --short`, commit corrente e diff stat.
2. Preserva tutte le modifiche esistenti, incluse quelle relative alla geometria della prova speciale e alle scene di review.
3. Esegui i controlli disponibili sullo stato attuale.
4. Se i controlli passano, crea un checkpoint Git descrittivo che includa fedelmente il lavoro presente. Non ripulire o riscrivere il diff.
5. Se un controllo fallisce, diagnostica e applica solo correzioni minime prima del checkpoint; non iniziare la vertical slice finché la baseline non è chiarita.

## Implementazione
- Crea una scena isolata, ad esempio `scenes/visual/PremiumVerticalSlice.tscn`, con script e asset dedicati.
- Riutilizza una sola auto V2 attraverso il wrapper visivo esistente, senza modificare collisione, statistiche o controller.
- Costruisci un tratto breve con rettilineo, curva ampia, salto controllato e un veicolo/ostacolo per il sorpasso.
- Sostituisci nella scena di review i grandi blocchi geometrici con canyon e gruppi rocciosi modulari organici.
- Aggiungi materiali strada e terreno con variazione cromatica, roughness e microdettaglio compatibili con GL Compatibility.
- Introduci foreground, mid-ground e background, foschia atmosferica, luce golden-hour, polvere ruote e nitro.
- Prepara una camera chase più ravvicinata con FOV dinamico moderato.
- Crea un HUD di presentazione essenziale e non invasivo.
- Mantieni contenuti originali e licenze verificabili; non scaricare asset esterni senza autorizzazione.

## Validazione
- Parser/import e boot.
- Test automatici esistenti, senza regressioni.
- Test mirati della nuova scena.
- Screenshot prima/dopo con stessa risoluzione e inquadrature comparabili.
- Metriche: caricamento, FPS, memoria e draw call.
- Verifica manuale di leggibilità di strada, ostacoli e auto.

## Gate finale
Non dichiarare il lavoro concluso se manca una delle prove. Restituisci:
1. stato iniziale e checkpoint creato;
2. file modificati e motivazione;
3. screenshot prodotti;
4. risultati dei test e metriche;
5. differenze rispetto al prototipo attuale;
6. limiti residui;
7. raccomandazione PASS, PASS CON RISERVE o FAIL per l'integrazione futura.

Non modificare Endurance, Prova Speciale, fisica, bilanciamento o salvataggi durante questa fase, salvo correzioni indispensabili e documentate per avviare la scena isolata.
