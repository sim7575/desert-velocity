class_name HandcraftedStage
extends RefCounted

# Profilo intenzionale di 64 segmenti (3328 m): gli archi sono raggruppati
# su più segmenti perché siano percepibili dalla chase camera e coerenti con
# le note. Larghezza, superfici, checkpoint e lunghezza logica restano invariati.
static func route() -> Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for i in 64:
		var section:Dictionary={"curve":0.0,"pitch":0.0,"surface":"GRAVEL","note":"RETTILINEO"}
		if i<3: section={"curve":0.0,"pitch":0.0,"surface":"ASPHALT","note":"PARTENZA"}
		elif i<6: section={"curve":.13,"pitch":.006,"surface":"GRAVEL","note":"DESTRA 5 APRE"}
		elif i<8: section={"curve":-.14,"pitch":0.0,"surface":"GRAVEL","note":"ESSE SINISTRA"}
		elif i<10: section={"curve":.14,"pitch":0.0,"surface":"GRAVEL","note":"ESSE DESTRA"}
		elif i<14: section={"curve":0.0,"pitch":.014 if i<12 else (-.014 if i==13 else 0.0),"surface":"GRAVEL","note":"DOSSO, ATTENZIONE"}
		elif i<18: section={"curve":-.20,"pitch":-.004,"surface":"GRAVEL","note":"TORNANTE SINISTRA"}
		elif i<23: section={"curve":.09 if i<21 else .06,"pitch":.020 if i<21 else -.030,"surface":"GRAVEL","note":"SALITA, DESTRA SU CRESTA"}
		elif i<26: section={"curve":-.12,"pitch":-.004,"surface":"ASPHALT","note":"SINISTRA 4 LUNGA"}
		elif i<29: section={"curve":.10,"pitch":-.004,"surface":"ASPHALT","note":"DESTRA 4 APRE"}
		elif i<34: section={"curve":.04,"pitch":.014 if i in [29,30] else (-.014 if i in [32,33] else 0.0),"surface":"GRAVEL","note":"RAMPA, ATTENZIONE"}
		elif i<36: section={"curve":.13,"pitch":.004,"surface":"GRAVEL","note":"DESTRA 4"}
		elif i<38: section={"curve":-.16,"pitch":-.004,"surface":"GRAVEL","note":"SINISTRA 3"}
		elif i<40: section={"curve":.13,"pitch":0.0,"surface":"GRAVEL","note":"DESTRA 4, COLLEGA"}
		elif i<44: section={"curve":-.11,"pitch":-.010,"surface":"ASPHALT","note":"SINISTRA 4 STRINGE"}
		elif i<48: section={"curve":.09,"pitch":.010,"surface":"ASPHALT","note":"DESTRA 5 APRE"}
		elif i<51: section={"curve":.12,"pitch":.006,"surface":"GRAVEL","note":"DESTRA 4 LUNGA"}
		elif i<54: section={"curve":-.14,"pitch":-.006,"surface":"GRAVEL","note":"SINISTRA 3"}
		elif i<57: section={"curve":.10,"pitch":.004,"surface":"GRAVEL","note":"DESTRA 4, COLLEGA"}
		elif i<59: section={"curve":-.11,"pitch":.010,"surface":"GRAVEL","note":"SINISTRA FINALE"}
		elif i==59: section={"curve":0.0,"pitch":.010,"surface":"GRAVEL","note":"CRESTA DOPO CHECKPOINT"}
		elif i==60: section={"curve":0.0,"pitch":.020,"surface":"GRAVEL","note":"SALTO SU CRESTA"}
		else: section={"curve":0.0,"pitch":-.015 if i<63 else 0.0,"surface":"GRAVEL","note":"TRAGUARDO"}
		# Il profilo locale viene applicato una sola volta per salto: la strada
		# resta continua ai due lati e non diventa una sequenza di rampe piatte.
		if i == 12: section["jump_kind"]="DOSSO"
		elif i == 20: section["jump_kind"]="CRESTA"
		elif i == 30: section["jump_kind"]="RAMPA"
		elif i == 60: section["jump_kind"]="CRESTA"
		result.append(section)
	return result

