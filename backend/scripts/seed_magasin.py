"""
Script de remplissage du magasin avec des pièces de rechange
compatibles avec les types de pannes existants dans la base de données.

Ce script :
1. Crée des pièces de rechange réalistes par catégorie de panne
2. Met à jour les rapports de panne (champ JSON pieces_rechange)
3. Crée des demandes de rechange (demande_rechange)
"""

import sys
import os
import random
from datetime import datetime, timedelta

# Ajouter le répertoire parent au path
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))

from app.core.database import SessionLocal
from app.models.panne import TypePanne, Panne
from app.models.intervention import Intervention, RapportPanne
from app.models.magasin import PieceRechange, DemandeRechange, StatutDemandeEnum
from app.models.enums import StatutInterventionEnum

# ============================================================================
# CATALOGUE DE PIÈCES DE RECHANGE PAR TYPE DE PANNE
# Chaque type de panne a ses pièces spécifiques + des pièces communes
# ============================================================================

PIECES_PAR_TYPE_PANNE = {
    "Moteur défectueux": [
        {"nom": "Bobine moteur 3 phases", "ref_prefix": "MOT-BOB", "unite": "pcs", "desc": "Bobine de remplacement pour moteur triphasé industriel"},
        {"nom": "Roulement à billes 6205", "ref_prefix": "MOT-RLT-6205", "unite": "pcs", "desc": "Roulement à billes étanche pour arbre moteur"},
        {"nom": "Roulement à billes 6308", "ref_prefix": "MOT-RLT-6308", "unite": "pcs", "desc": "Roulement à billes haute charge pour moteur puissant"},
        {"nom": "Balais charbon moteur DC", "ref_prefix": "MOT-BCH", "unite": "pcs", "desc": "Jeu de balais en charbon pour moteur à courant continu"},
        {"nom": "Condensateur démarrage 50µF", "ref_prefix": "MOT-CND-50", "unite": "pcs", "desc": "Condensateur de démarrage pour moteur monophasé"},
        {"nom": "Ventilateur moteur 200mm", "ref_prefix": "MOT-VNT", "unite": "pcs", "desc": "Ventilateur de refroidissement moteur électrique"},
        {"nom": "Joint d'étanchéité arbre", "ref_prefix": "MOT-JNT", "unite": "pcs", "desc": "Joint SPI pour arbre de moteur"},
        {"nom": "Courroie trapézoïdale A68", "ref_prefix": "MOT-CRT-A68", "unite": "pcs", "desc": "Courroie d'entraînement trapézoïdale section A"},
        {"nom": "Poulie moteur ø120mm", "ref_prefix": "MOT-PUL", "unite": "pcs", "desc": "Poulie en fonte pour transmission par courroie"},
        {"nom": "Accouplement flexible GR42", "ref_prefix": "MOT-ACP", "unite": "pcs", "desc": "Accouplement élastique pour liaison moteur-réducteur"},
    ],
    "Surchauffe système": [
        {"nom": "Ventilateur axial 120mm 24V", "ref_prefix": "THR-VNT-120", "unite": "pcs", "desc": "Ventilateur axial pour armoire électrique"},
        {"nom": "Ventilateur axial 80mm 230V", "ref_prefix": "THR-VNT-80", "unite": "pcs", "desc": "Ventilateur de refroidissement pour coffret"},
        {"nom": "Pâte thermique haute performance", "ref_prefix": "THR-PTH", "unite": "pcs", "desc": "Pâte thermique conductrice pour dissipateur (tube 30g)"},
        {"nom": "Dissipateur thermique aluminium", "ref_prefix": "THR-DIS", "unite": "pcs", "desc": "Dissipateur en aluminium pour composants de puissance"},
        {"nom": "Thermostat réglable 0-120°C", "ref_prefix": "THR-TST", "unite": "pcs", "desc": "Thermostat de coupure réglable pour protection thermique"},
        {"nom": "Sonde température PT100", "ref_prefix": "THR-PT100", "unite": "pcs", "desc": "Sonde de température platine PT100 classe B"},
        {"nom": "Relais thermique 10-16A", "ref_prefix": "THR-RLT", "unite": "pcs", "desc": "Relais de protection thermique pour moteur"},
        {"nom": "Filtre à air armoire", "ref_prefix": "THR-FLT", "unite": "pcs", "desc": "Filtre à poussière pour armoire de climatisation"},
        {"nom": "Échangeur thermique eau/air", "ref_prefix": "THR-ECH", "unite": "pcs", "desc": "Échangeur de chaleur pour système de refroidissement"},
        {"nom": "Liquide de refroidissement 5L", "ref_prefix": "THR-LIQ", "unite": "L", "desc": "Liquide caloporteur antigel pour circuit fermé"},
    ],
    "Erreur capteur": [
        {"nom": "Capteur inductif M18 PNP", "ref_prefix": "CPT-IND-M18", "unite": "pcs", "desc": "Capteur de proximité inductif M18 portée 8mm"},
        {"nom": "Capteur inductif M12 NPN", "ref_prefix": "CPT-IND-M12", "unite": "pcs", "desc": "Capteur de proximité inductif M12 portée 4mm"},
        {"nom": "Capteur photoélectrique reflex", "ref_prefix": "CPT-PHO-RFX", "unite": "pcs", "desc": "Capteur photoélectrique à réflexion portée 5m"},
        {"nom": "Capteur de pression 0-10bar", "ref_prefix": "CPT-PRS", "unite": "pcs", "desc": "Transmetteur de pression analogique 4-20mA"},
        {"nom": "Capteur de température K", "ref_prefix": "CPT-TMP-K", "unite": "pcs", "desc": "Thermocouple type K -40 à 1200°C"},
        {"nom": "Encodeur rotatif 1024 PPR", "ref_prefix": "CPT-ENC", "unite": "pcs", "desc": "Encodeur incrémental 1024 impulsions par tour"},
        {"nom": "Cellule de charge 100kg", "ref_prefix": "CPT-CLC", "unite": "pcs", "desc": "Capteur de pesage jauge de contrainte 100kg"},
        {"nom": "Câble blindé capteur 5m", "ref_prefix": "CPT-CBL-5", "unite": "m", "desc": "Câble de raccordement capteur blindé avec connecteur M12"},
        {"nom": "Connecteur M12 4 broches", "ref_prefix": "CPT-CON-M12", "unite": "pcs", "desc": "Connecteur industriel M12 mâle coudé IP67"},
        {"nom": "Réflecteur prismatique 80mm", "ref_prefix": "CPT-RFL", "unite": "pcs", "desc": "Réflecteur pour capteur photoélectrique reflex"},
    ],
    "Calibration nécessaire": [
        {"nom": "Solution étalon pH 7.00", "ref_prefix": "CAL-PH7", "unite": "L", "desc": "Solution tampon de calibration pH 7.00 certifiée"},
        {"nom": "Solution étalon pH 4.00", "ref_prefix": "CAL-PH4", "unite": "L", "desc": "Solution tampon de calibration pH 4.00 certifiée"},
        {"nom": "Masse étalon 1kg classe M1", "ref_prefix": "CAL-MAS-1", "unite": "pcs", "desc": "Masse de calibration 1kg en acier inoxydable"},
        {"nom": "Cale étalon 25mm grade 1", "ref_prefix": "CAL-CLE", "unite": "pcs", "desc": "Cale de référence en céramique pour calibration dimensionnelle"},
        {"nom": "Manomètre étalon 0-16bar", "ref_prefix": "CAL-MAN", "unite": "pcs", "desc": "Manomètre de référence classe 0.25 pour étalonnage"},
        {"nom": "Multimètre de précision", "ref_prefix": "CAL-MLT", "unite": "pcs", "desc": "Multimètre numérique haute précision 6½ digits"},
        {"nom": "Kit calibration débitmètre", "ref_prefix": "CAL-DEB", "unite": "pcs", "desc": "Kit complet de vérification pour débitmètre électromagnétique"},
        {"nom": "Thermomètre étalon digital", "ref_prefix": "CAL-THD", "unite": "pcs", "desc": "Thermomètre de référence -50 à 300°C précision 0.1°C"},
    ],
    "Coupure d'alimentation": [
        {"nom": "Disjoncteur 3P 25A courbe C", "ref_prefix": "ELC-DJC-25", "unite": "pcs", "desc": "Disjoncteur magnétothermique tripolaire 25A"},
        {"nom": "Disjoncteur 3P 40A courbe D", "ref_prefix": "ELC-DJC-40", "unite": "pcs", "desc": "Disjoncteur magnétothermique tripolaire 40A"},
        {"nom": "Contacteur 3P 32A AC3", "ref_prefix": "ELC-CTC-32", "unite": "pcs", "desc": "Contacteur de puissance tripolaire 32A bobine 230V"},
        {"nom": "Fusible cylindrique 10A gG", "ref_prefix": "ELC-FUS-10", "unite": "pcs", "desc": "Fusible de protection 10x38mm 10A courbe gG"},
        {"nom": "Fusible cylindrique 25A gG", "ref_prefix": "ELC-FUS-25", "unite": "pcs", "desc": "Fusible de protection 14x51mm 25A courbe gG"},
        {"nom": "Alimentation 24VDC 10A", "ref_prefix": "ELC-ALM-24", "unite": "pcs", "desc": "Alimentation stabilisée rail DIN 24V 10A 240W"},
        {"nom": "Onduleur rack 3kVA", "ref_prefix": "ELC-OND", "unite": "pcs", "desc": "Onduleur en ligne pure sinus 3000VA/2700W"},
        {"nom": "Parafoudre Type 2 tripolaire", "ref_prefix": "ELC-PFD", "unite": "pcs", "desc": "Parafoudre modulaire type 2 pour réseau triphasé"},
        {"nom": "Câble souple H07VK 6mm² bleu", "ref_prefix": "ELC-CBL-6B", "unite": "m", "desc": "Câble unipolaire souple 6mm² bleu (neutre)"},
        {"nom": "Câble souple H07VK 6mm² noir", "ref_prefix": "ELC-CBL-6N", "unite": "m", "desc": "Câble unipolaire souple 6mm² noir (phase)"},
        {"nom": "Bornier de raccordement 16mm²", "ref_prefix": "ELC-BRN", "unite": "pcs", "desc": "Bornier à vis sur rail DIN 16mm² gris"},
    ],
    "Fuite de fluide": [
        {"nom": "Joint torique Viton ø25mm", "ref_prefix": "HYD-JTR-25", "unite": "pcs", "desc": "Joint torique FPM/Viton résistant aux huiles et solvants"},
        {"nom": "Joint torique NBR ø40mm", "ref_prefix": "HYD-JTR-40", "unite": "pcs", "desc": "Joint torique en nitrile pour applications hydrauliques"},
        {"nom": "Flexible hydraulique DN10 1m", "ref_prefix": "HYD-FLX-10", "unite": "pcs", "desc": "Flexible haute pression DN10 avec raccords sertis"},
        {"nom": "Flexible hydraulique DN16 2m", "ref_prefix": "HYD-FLX-16", "unite": "pcs", "desc": "Flexible haute pression DN16 avec raccords sertis"},
        {"nom": "Raccord rapide hydraulique", "ref_prefix": "HYD-RCC", "unite": "pcs", "desc": "Coupleur rapide hydraulique 1/2\" mâle à billes"},
        {"nom": "Huile hydraulique ISO VG46 20L", "ref_prefix": "HYD-HUI-46", "unite": "L", "desc": "Huile hydraulique anti-usure ISO VG46 bidon 20L"},
        {"nom": "Filtre hydraulique retour 10µm", "ref_prefix": "HYD-FLT-R", "unite": "pcs", "desc": "Cartouche filtre retour hydraulique 10 microns"},
        {"nom": "Filtre hydraulique pression 25µm", "ref_prefix": "HYD-FLT-P", "unite": "pcs", "desc": "Cartouche filtre pression hydraulique 25 microns"},
        {"nom": "Vanne à boisseau 1/2\"", "ref_prefix": "HYD-VAN", "unite": "pcs", "desc": "Vanne d'isolement à boisseau sphérique 1/2\" inox"},
        {"nom": "Ruban PTFE 12m", "ref_prefix": "HYD-PTF", "unite": "pcs", "desc": "Ruban d'étanchéité téflon pour raccords filetés"},
        {"nom": "Colle anaérobie frein-filet", "ref_prefix": "HYD-COL", "unite": "pcs", "desc": "Colle frein-filet moyenne résistance (flacon 50ml)"},
    ],
    "Composant cassé": [
        {"nom": "Vérin pneumatique ø40 course 200", "ref_prefix": "MEC-VER-40", "unite": "pcs", "desc": "Vérin double effet ISO 15552 ø40mm course 200mm"},
        {"nom": "Vérin pneumatique ø63 course 300", "ref_prefix": "MEC-VER-63", "unite": "pcs", "desc": "Vérin double effet ISO 15552 ø63mm course 300mm"},
        {"nom": "Électrovanne 5/2 monostable", "ref_prefix": "MEC-ELV-52", "unite": "pcs", "desc": "Électrovanne pneumatique 5/2 voies 24VDC"},
        {"nom": "Distributeur pneumatique 3/2", "ref_prefix": "MEC-DIS-32", "unite": "pcs", "desc": "Distributeur pneumatique 3/2 voies à commande manuelle"},
        {"nom": "Guide linéaire rail 400mm", "ref_prefix": "MEC-GDL-R", "unite": "pcs", "desc": "Rail de guidage linéaire à billes 400mm"},
        {"nom": "Patin guide linéaire", "ref_prefix": "MEC-GDL-P", "unite": "pcs", "desc": "Chariot patin pour rail de guidage linéaire"},
        {"nom": "Ressort de compression ø30", "ref_prefix": "MEC-RSS", "unite": "pcs", "desc": "Ressort de compression en acier inox ø30 L=80mm"},
        {"nom": "Amortisseur de choc M20", "ref_prefix": "MEC-AMR", "unite": "pcs", "desc": "Amortisseur de choc hydraulique M20x1.5 réglable"},
        {"nom": "Engrenage droit module 2 Z30", "ref_prefix": "MEC-ENG", "unite": "pcs", "desc": "Roue dentée droite module 2 - 30 dents en acier traité"},
        {"nom": "Vis à billes ø16 pas 5 L=500", "ref_prefix": "MEC-VAB", "unite": "pcs", "desc": "Vis à billes de précision ø16mm pas 5mm longueur 500mm"},
    ],
    "Problème de connectivité": [
        {"nom": "Switch Ethernet industriel 8 ports", "ref_prefix": "NET-SWI-8", "unite": "pcs", "desc": "Switch manageable 8 ports Gigabit montage DIN"},
        {"nom": "Câble Ethernet Cat6 blindé 5m", "ref_prefix": "NET-CBL-5", "unite": "pcs", "desc": "Câble réseau Cat6 FTP blindé avec connecteurs RJ45"},
        {"nom": "Câble Ethernet Cat6 blindé 10m", "ref_prefix": "NET-CBL-10", "unite": "pcs", "desc": "Câble réseau Cat6 FTP blindé avec connecteurs RJ45"},
        {"nom": "Connecteur RJ45 Cat6 blindé", "ref_prefix": "NET-RJ45", "unite": "pcs", "desc": "Connecteur RJ45 Cat6 à sertir blindé (lot de 10)"},
        {"nom": "Convertisseur RS485/Ethernet", "ref_prefix": "NET-CVT-485", "unite": "pcs", "desc": "Passerelle Modbus RS485 vers Ethernet TCP/IP"},
        {"nom": "Câble Profibus DP 20m", "ref_prefix": "NET-PFB", "unite": "m", "desc": "Câble de bus Profibus DP blindé violet"},
        {"nom": "Module Wi-Fi industriel", "ref_prefix": "NET-WIF", "unite": "pcs", "desc": "Point d'accès Wi-Fi industriel IP65 2.4/5GHz"},
        {"nom": "Antenne WiFi SMA 5dBi", "ref_prefix": "NET-ANT", "unite": "pcs", "desc": "Antenne omnidirectionnelle 5dBi connecteur SMA"},
        {"nom": "Fibre optique duplex LC 10m", "ref_prefix": "NET-FIB", "unite": "pcs", "desc": "Jarretière fibre optique monomode LC/LC 10m"},
    ],
    "Usure mécanique": [
        {"nom": "Roulement à rouleaux coniques", "ref_prefix": "USR-RRC", "unite": "pcs", "desc": "Roulement à rouleaux coniques 30207 pour charge axiale"},
        {"nom": "Bague d'usure bronze ø50", "ref_prefix": "USR-BAG-50", "unite": "pcs", "desc": "Bague autolubrifiante en bronze fritté ø50mm"},
        {"nom": "Chaîne à rouleaux 08B-1 3m", "ref_prefix": "USR-CHN", "unite": "m", "desc": "Chaîne de transmission à rouleaux simple pas 12.7mm"},
        {"nom": "Pignon chaîne 08B Z17", "ref_prefix": "USR-PGN", "unite": "pcs", "desc": "Pignon pour chaîne 08B 17 dents moyeu à serrer"},
        {"nom": "Courroie crantée HTD-5M 450", "ref_prefix": "USR-CRC", "unite": "pcs", "desc": "Courroie synchrone HTD pas 5mm largeur 15mm"},
        {"nom": "Graisse lithium EP2 cartouche", "ref_prefix": "USR-GRS", "unite": "kg", "desc": "Graisse multiusage lithium complexe EP2 (cartouche 400g)"},
        {"nom": "Huile de coupe soluble 5L", "ref_prefix": "USR-HCS", "unite": "L", "desc": "Lubrifiant d'usinage soluble pour métaux ferreux"},
        {"nom": "Patin de glissement PTFE", "ref_prefix": "USR-PTG", "unite": "pcs", "desc": "Patin de guidage en PTFE chargé bronze autolubrifiant"},
        {"nom": "Goupille cylindrique ø6x30", "ref_prefix": "USR-GPL", "unite": "pcs", "desc": "Goupille cylindrique trempée ø6mm longueur 30mm"},
        {"nom": "Clavette parallèle 8x7x40", "ref_prefix": "USR-CLV", "unite": "pcs", "desc": "Clavette parallèle en acier 8x7x40mm DIN 6885"},
    ],
}

# Pièces communes utilisées pour tous les types de pannes
PIECES_COMMUNES = [
    {"nom": "Boulon M10x40 inox A2", "ref_prefix": "COM-BLN-M10", "unite": "pcs", "desc": "Boulon hexagonal M10x40 acier inoxydable A2-70"},
    {"nom": "Écrou frein M10 inox", "ref_prefix": "COM-ECR-M10", "unite": "pcs", "desc": "Écrou autobloquant Nylstop M10 inox A2"},
    {"nom": "Rondelle plate M10 inox", "ref_prefix": "COM-RND-M10", "unite": "pcs", "desc": "Rondelle plate large M10 acier inoxydable A2"},
    {"nom": "Collier de serrage 20-32mm", "ref_prefix": "COM-CLS", "unite": "pcs", "desc": "Collier de serrage à vis sans fin inox ø20-32mm"},
    {"nom": "Spray dégrippant multifonction", "ref_prefix": "COM-DGR", "unite": "pcs", "desc": "Aérosol dégrippant lubrifiant protecteur 400ml"},
    {"nom": "Nettoyant contact électrique", "ref_prefix": "COM-NCT", "unite": "pcs", "desc": "Spray nettoyant pour contacts électriques 250ml"},
    {"nom": "Gaine thermorétractable kit", "ref_prefix": "COM-GTR", "unite": "pcs", "desc": "Assortiment de gaines thermorétractables (lot 100 pcs)"},
    {"nom": "Serre-câble nylon 200mm", "ref_prefix": "COM-SRC", "unite": "pcs", "desc": "Collier de serrage nylon noir 200x4.8mm (lot 100)"},
    {"nom": "Embout de câblage 2.5mm²", "ref_prefix": "COM-EMB", "unite": "pcs", "desc": "Embout de câblage isolé double 2x2.5mm² (lot 100)"},
    {"nom": "Marqueur de câble 0-9", "ref_prefix": "COM-MRQ", "unite": "pcs", "desc": "Repères de câble clipables chiffres 0 à 9"},
]


def main():
    db = SessionLocal()
    try:
        # ================================================================
        # ÉTAPE 1 : Supprimer les anciennes pièces et demandes
        # ================================================================
        existing_pieces = db.query(PieceRechange).count()
        existing_demandes = db.query(DemandeRechange).count()
        
        if existing_pieces > 0 or existing_demandes > 0:
            print(f"Nettoyage: suppression de {existing_demandes} demandes et {existing_pieces} pièces existantes...")
            db.query(DemandeRechange).delete()
            db.query(PieceRechange).delete()
            db.commit()

        # ================================================================
        # ÉTAPE 2 : Créer les pièces de rechange par type de panne
        # ================================================================
        print("\n=== CRÉATION DU CATALOGUE DE PIÈCES DE RECHANGE ===\n")
        
        # Récupérer les types de pannes
        types_panne = db.query(TypePanne).all()
        type_panne_map = {tp.nom_panne: tp for tp in types_panne}
        
        # Dictionnaire : nom_type_panne -> [PieceRechange, ...]
        pieces_par_type = {}
        all_pieces = []
        piece_counter = 0
        
        for type_name, pieces_data in PIECES_PAR_TYPE_PANNE.items():
            if type_name not in type_panne_map:
                print(f"  ⚠ Type de panne '{type_name}' non trouvé dans la BD, pièces ignorées")
                continue
            
            pieces_par_type[type_name] = []
            print(f"  📦 Type de panne: {type_name}")
            
            for pd in pieces_data:
                piece_counter += 1
                ref = f"{pd['ref_prefix']}-{piece_counter:04d}"
                piece = PieceRechange(
                    reference=ref,
                    nom=pd["nom"],
                    description=pd["desc"],
                    quantite_stock=random.randint(5, 150),
                    unite=pd["unite"]
                )
                db.add(piece)
                pieces_par_type[type_name].append(piece)
                all_pieces.append(piece)
            
            print(f"     → {len(pieces_data)} pièces créées")
        
        # Ajouter les pièces communes
        print(f"\n  🔧 Pièces communes (toutes pannes)")
        pieces_communes_objs = []
        for pd in PIECES_COMMUNES:
            piece_counter += 1
            ref = f"{pd['ref_prefix']}-{piece_counter:04d}"
            piece = PieceRechange(
                reference=ref,
                nom=pd["nom"],
                description=pd["desc"],
                quantite_stock=random.randint(20, 500),
                unite=pd["unite"]
            )
            db.add(piece)
            pieces_communes_objs.append(piece)
            all_pieces.append(piece)
        
        print(f"     → {len(PIECES_COMMUNES)} pièces communes créées")
        
        db.commit()
        print(f"\n  ✅ Total: {len(all_pieces)} pièces créées dans le magasin\n")
        
        # ================================================================
        # ÉTAPE 3 : Mettre à jour les rapports de panne avec les pièces
        # ================================================================
        print("=== MISE À JOUR DES RAPPORTS DE PANNE ===\n")
        
        # Récupérer les interventions terminées avec leur type de panne
        interventions_terminees = (
            db.query(Intervention, Panne, TypePanne)
            .join(Panne, Panne.id_panne == Intervention.id_panne)
            .join(TypePanne, TypePanne.id_type_panne == Panne.id_type_panne)
            .filter(Intervention.statut == StatutInterventionEnum.TERMINEE)
            .all()
        )
        
        rapports_modifies = 0
        demandes_creees = 0
        
        for intervention, panne, type_panne in interventions_terminees:
            # Récupérer le rapport associé
            rapport = db.query(RapportPanne).filter_by(id_intervention=intervention.id_intervention).first()
            if not rapport:
                continue
            
            # Déterminer les pièces compatibles
            type_nom = type_panne.nom_panne
            pieces_compatibles = pieces_par_type.get(type_nom, [])
            
            if not pieces_compatibles:
                continue
            
            # Choisir 1 à 4 pièces spécifiques + 0 à 2 communes
            nb_pieces_specifiques = random.randint(1, min(4, len(pieces_compatibles)))
            pieces_choisies = random.sample(pieces_compatibles, nb_pieces_specifiques)
            
            nb_pieces_communes = random.randint(0, min(2, len(pieces_communes_objs)))
            if nb_pieces_communes > 0:
                pieces_choisies += random.sample(pieces_communes_objs, nb_pieces_communes)
            
            # Mettre à jour le champ JSON pieces_rechange du rapport
            pieces_json = []
            for piece in pieces_choisies:
                quantite = random.randint(1, 5)
                pieces_json.append({
                    "part_name": piece.nom,
                    "reference": piece.reference,
                    "quantity": quantite
                })
                
                # Créer aussi une demande de rechange (80% de chance)
                if random.random() < 0.8:
                    statut_demande = random.choice([
                        StatutDemandeEnum.LIVREE,
                        StatutDemandeEnum.LIVREE,
                        StatutDemandeEnum.LIVREE,
                        StatutDemandeEnum.APPROUVEE,
                        StatutDemandeEnum.EN_ATTENTE,
                    ])
                    
                    # Date de demande = pendant l'intervention
                    date_demande = intervention.date_scan_qr or intervention.date_acceptation or intervention.date_debut
                    
                    demande = DemandeRechange(
                        id_intervention=intervention.id_intervention,
                        id_piece=piece.id_piece,
                        quantite_demandee=quantite,
                        statut=statut_demande,
                        commentaire=f"Pièce nécessaire pour {type_nom.lower()} - {piece.nom}",
                        date_demande=date_demande
                    )
                    db.add(demande)
                    demandes_creees += 1
                    
                    # Si livrée, décrémenter le stock
                    if statut_demande == StatutDemandeEnum.LIVREE:
                        piece.quantite_stock = max(0, piece.quantite_stock - quantite)
            
            rapport.pieces_rechange = pieces_json
            rapports_modifies += 1
        
        db.commit()
        
        print(f"  📋 {rapports_modifies} rapports de panne mis à jour avec les pièces utilisées")
        print(f"  📝 {demandes_creees} demandes de rechange créées")
        
        # ================================================================
        # ÉTAPE 4 : Résumé final
        # ================================================================
        print("\n=== RÉSUMÉ FINAL ===\n")
        
        total_pieces = db.query(PieceRechange).count()
        total_demandes = db.query(DemandeRechange).count()
        total_rapports = db.query(RapportPanne).count()
        from sqlalchemy import cast, String
        rapports_avec_pieces = db.query(RapportPanne).filter(
            RapportPanne.pieces_rechange.isnot(None),
            cast(RapportPanne.pieces_rechange, String) != '[]'
        ).count()
        
        stock_total = sum(p.quantite_stock for p in db.query(PieceRechange).all())
        
        print(f"  📦 Pièces dans le magasin    : {total_pieces}")
        print(f"  📊 Stock total (toutes pièces): {stock_total} unités")
        print(f"  📋 Rapports de panne          : {total_rapports}")
        print(f"  🔧 Rapports avec pièces       : {rapports_avec_pieces}")
        print(f"  📝 Demandes de rechange       : {total_demandes}")
        print(f"\n  ✅ Magasin rempli avec succès !")
        
    except Exception as e:
        print(f"\n  ❌ Erreur: {e}")
        import traceback
        traceback.print_exc()
        db.rollback()
    finally:
        db.close()


if __name__ == "__main__":
    main()
