# Audit visivo iniziale — Desert Velocity

## Esito
Il limite percepito non deriva da GDScript, Godot o dalla risoluzione 1280×720. Il progetto usa già modelli Blender/GLB e texture fino a 1024×1024. Il collo di bottiglia è la direzione artistica low-poly e, soprattutto, la semplicità dell'ambiente di gameplay.

## Evidenze
- Le auto V2 mostrano più dettaglio e materiali distinti.
- Nel gameplay strada, terreno, cactus, gate e rocce restano geometrici e poco stratificati.
- Le scene ambientate dei prototipi V2 sono più curate del gameplay reale, ma mantengono canyon costruiti con grandi forme semplici.
- Il repository contiene modifiche non committate e nuovi file di review; qualunque pulizia distruttiva sarebbe rischiosa.

## Decisione
1. Conservare architettura e repository.
2. Mettere in sicurezza il diff corrente con test e checkpoint.
3. Formalizzare regole operative e direzione artistica.
4. Costruire una vertical slice isolata prima di modificare le modalità principali.
5. Valutare il salto visivo con screenshot comparativi e metriche.
