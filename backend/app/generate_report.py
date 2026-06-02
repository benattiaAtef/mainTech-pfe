import os
import json
from datetime import datetime
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.core.database import SessionLocal
from app.models.users import Utilisateur, Technicien, Superviseur
from app.models.machine import Machine, GroupeMachine
from app.models.panne import Panne, TypePanne
from app.models.intervention import Intervention, RapportPanne

def generate_html_report():
    db = SessionLocal()
    try:
        print("📊 Querying database statistics...")
        
        # 1. Obtenir les statistiques globales
        total_interventions = db.query(Intervention).count()
        total_terminees = db.query(Intervention).filter(Intervention.statut == "TERMINEE").count()
        total_en_cours = db.query(Intervention).filter(Intervention.statut == "EN_COURS").count()
        total_acceptees = db.query(Intervention).filter(Intervention.statut == "ACCEPTEE").count()
        total_en_attente = db.query(Intervention).filter(Intervention.statut == "EN_ATTENTE").count()
        total_annulees = db.query(Intervention).filter(Intervention.statut == "ANNULEE").count()
        
        # 2. Répartition par Statut (pour le Doughnut Chart)
        statut_data = {
            "Terminées": total_terminees,
            "En cours": total_en_cours,
            "Acceptées": total_acceptees,
            "En attente": total_en_attente,
            "Annulées": total_annulees
        }
        
        # 3. Interventions par Technicien
        tech_query = db.query(
            Utilisateur.prenom, Utilisateur.nom, func.count(Intervention.id_intervention)
        ).join(Technicien, Technicien.id_utilisateur == Utilisateur.id_utilisateur)\
         .join(Intervention, Intervention.id_technicien == Technicien.id_technicien)\
         .group_by(Utilisateur.prenom, Utilisateur.nom)\
         .order_by(func.count(Intervention.id_intervention).desc()).all()
         
        tech_data = {f"{t[0]} {t[1]}": t[2] for t in tech_query}
        
        # 4. Pannes par Type (Top 10)
        panne_type_query = db.query(
            TypePanne.nom_panne, func.count(Panne.id_panne)
        ).join(Panne, Panne.id_type_panne == TypePanne.id_type_panne)\
         .group_by(TypePanne.nom_panne)\
         .order_by(func.count(Panne.id_panne).desc()).all()
         
        panne_type_data = {p[0]: p[1] for p in panne_type_query}
        
        # 5. Pannes par Machine
        machine_query = db.query(
            Machine.nom, func.count(Panne.id_panne)
        ).join(Panne, Panne.id_machine == Machine.id_machine)\
         .group_by(Machine.nom)\
         .order_by(func.count(Panne.id_panne).desc()).all()
         
        machine_data = {m[0]: m[1] for m in machine_query}
        
        # 6. Évolution dans le temps (Groupé par date sur les 90 derniers jours)
        # Tronquer la date au jour
        timeline_query = db.query(
            func.date(Intervention.date_debut), func.count(Intervention.id_intervention)
        ).group_by(func.date(Intervention.date_debut))\
         .order_by(func.date(Intervention.date_debut)).all()
         
        timeline_data = {t[0].isoformat() if hasattr(t[0], "isoformat") else str(t[0]): t[1] for t in timeline_query}
        
        # 7. Les 50 interventions les plus récentes avec détails
        recent_interventions_query = db.query(Intervention).order_by(Intervention.date_debut.desc()).limit(100).all()
        
        recent_interventions = []
        for i in recent_interventions_query:
            # Récupérer les informations liées
            tech_name = f"{i.technicien.utilisateur.prenom} {i.technicien.utilisateur.nom}" if i.technicien else "Non assigné"
            machine_name = i.panne.machine.nom if i.panne and i.panne.machine else "Inconnue"
            panne_type = i.panne.type_panne.nom_panne if i.panne and i.panne.type_panne else "Inconnue"
            
            # Rapport de panne
            rapport_info = {}
            if i.rapport:
                rapport_info = {
                    "id_rapport": i.rapport.id_rapport,
                    "description": i.rapport.description_panne,
                    "travaux": i.rapport.travaux_effectues,
                    "type_travail": i.rapport.type_travail,
                    "temps_arret": i.rapport.temps_arret,
                    "causes": i.rapport.causes,
                    "solutions": i.rapport.solutions,
                    "etat_final": i.rapport.etat_final,
                    "pieces": i.rapport.pieces_rechange
                }
            
            recent_interventions.append({
                "id_intervention": i.id_intervention,
                "technicien": tech_name,
                "machine": machine_name,
                "type_panne": panne_type,
                "statut": i.statut.value if hasattr(i.statut, "value") else str(i.statut),
                "date_debut": i.date_debut.isoformat() if i.date_debut else None,
                "date_fin": i.date_fin.isoformat() if i.date_fin else None,
                "type_affectation": i.type_affectation.value if hasattr(i.type_affectation, "value") else str(i.type_affectation),
                "rapport": rapport_info
            })

        print("✨ Compiling HTML data visualization template...")
        
        # Création du contenu HTML
        html_content = f"""<!DOCTYPE html>
<html lang="fr" class="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>mainTech - Visualisation des Données</title>
    <!-- Google Fonts Inter -->
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
    <!-- Tailwind CSS Play CDN -->
    <script src="https://cdn.tailwindcss.com"></script>
    <!-- Chart.js CDN -->
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script>
        tailwind.config = {{
            darkMode: 'class',
            theme: {{
                extend: {{
                    fontFamily: {{
                        sans: ['Inter', 'sans-serif'],
                    }},
                }}
            }}
        }}
    </script>
    <style>
        body {{
            background-color: #080C14;
            background-image: 
                radial-gradient(at 0% 0%, rgba(17, 24, 39, 0.7) 0px, transparent 50%),
                radial-gradient(at 50% 0%, rgba(29, 78, 216, 0.15) 0px, transparent 50%),
                radial-gradient(at 100% 0%, rgba(124, 58, 237, 0.15) 0px, transparent 50%);
            background-attachment: fixed;
        }}
        /* Custom scrollbar */
        ::-webkit-scrollbar {{
            width: 8px;
            height: 8px;
        }}
        ::-webkit-scrollbar-track {{
            background: #0D1321;
        }}
        ::-webkit-scrollbar-thumb {{
            background: #1F2937;
            border-radius: 4px;
        }}
        ::-webkit-scrollbar-thumb:hover {{
            background: #374151;
        }}
    </style>
</head>
<body class="text-gray-100 min-h-screen py-8 px-4 sm:px-6 lg:px-8">

    <div class="max-w-7xl mx-auto space-y-8">
        
        <!-- Header -->
        <header class="flex flex-col md:flex-row justify-between items-start md:items-center pb-6 border-b border-gray-800 gap-4">
            <div>
                <div class="flex items-center gap-3">
                    <div class="bg-gradient-to-r from-blue-600 to-indigo-600 p-2.5 rounded-xl shadow-lg shadow-blue-500/20">
                        <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 002 2h2a2 2 0 002-2"></path></svg>
                    </div>
                    <h1 class="text-3xl font-extrabold tracking-tight bg-gradient-to-r from-white via-gray-100 to-gray-400 bg-clip-text text-transparent">
                        mainTech
                    </h1>
                    <span class="px-2.5 py-0.5 text-xs font-semibold rounded-full bg-blue-500/10 text-blue-400 border border-blue-500/20">
                        Visualisation Live
                    </span>
                </div>
                <p class="text-gray-400 text-sm mt-2">
                    Analyse visuelle et rapports détaillés des 400 interventions factices insérées dans la base de données.
                </p>
            </div>
            
            <div class="flex items-center gap-3 text-xs bg-gray-900/60 backdrop-blur-md border border-gray-800 px-4 py-2.5 rounded-xl">
                <span class="w-2 h-2 rounded-full bg-emerald-500 animate-ping"></span>
                <span class="text-gray-400 font-medium">Base PostgreSQL connectée :</span>
                <span class="text-emerald-400 font-bold">400 Interventions</span>
            </div>
        </header>

        <!-- KPI Counters Grid -->
        <section class="grid grid-cols-2 lg:grid-cols-5 gap-4">
            
            <!-- Card 1 -->
            <div class="bg-gray-900/40 backdrop-blur-md border border-gray-800/80 p-5 rounded-2xl flex flex-col justify-between hover:border-blue-500/40 transition duration-300 shadow-md">
                <span class="text-xs font-semibold text-gray-400 uppercase tracking-wider">Total Interventions</span>
                <div class="flex items-baseline gap-2 mt-2">
                    <span class="text-3xl font-black text-white">{total_interventions}</span>
                    <span class="text-xs text-blue-400 font-medium">100%</span>
                </div>
                <div class="h-1 w-full bg-gray-800 rounded-full mt-3 overflow-hidden">
                    <div class="h-full bg-blue-500" style="width: 100%"></div>
                </div>
            </div>

            <!-- Card 2 -->
            <div class="bg-gray-900/40 backdrop-blur-md border border-gray-800/80 p-5 rounded-2xl flex flex-col justify-between hover:border-emerald-500/40 transition duration-300 shadow-md">
                <span class="text-xs font-semibold text-gray-400 uppercase tracking-wider">Terminées (Rapportées)</span>
                <div class="flex items-baseline gap-2 mt-2">
                    <span class="text-3xl font-black text-emerald-400">{total_terminees}</span>
                    <span class="text-xs text-gray-400 font-medium">{round((total_terminees/total_interventions)*100, 1)}%</span>
                </div>
                <div class="h-1 w-full bg-gray-800 rounded-full mt-3 overflow-hidden">
                    <div class="h-full bg-emerald-500" style="width: {round((total_terminees/total_interventions)*100, 1)}%"></div>
                </div>
            </div>

            <!-- Card 3 -->
            <div class="bg-gray-900/40 backdrop-blur-md border border-gray-800/80 p-5 rounded-2xl flex flex-col justify-between hover:border-amber-500/40 transition duration-300 shadow-md">
                <span class="text-xs font-semibold text-gray-400 uppercase tracking-wider">En cours / Acceptées</span>
                <div class="flex items-baseline gap-2 mt-2">
                    <span class="text-3xl font-black text-amber-400">{total_en_cours + total_acceptees}</span>
                    <span class="text-xs text-gray-400 font-medium">{round(((total_en_cours + total_acceptees)/total_interventions)*100, 1)}%</span>
                </div>
                <div class="h-1 w-full bg-gray-800 rounded-full mt-3 overflow-hidden">
                    <div class="h-full bg-amber-500" style="width: {round(((total_en_cours + total_acceptees)/total_interventions)*100, 1)}%"></div>
                </div>
            </div>

            <!-- Card 4 -->
            <div class="bg-gray-900/40 backdrop-blur-md border border-gray-800/80 p-5 rounded-2xl flex flex-col justify-between hover:border-purple-500/40 transition duration-300 shadow-md">
                <span class="text-xs font-semibold text-gray-400 uppercase tracking-wider">En attente d'attribution</span>
                <div class="flex items-baseline gap-2 mt-2">
                    <span class="text-3xl font-black text-purple-400">{total_en_attente}</span>
                    <span class="text-xs text-gray-400 font-medium">{round((total_en_attente/total_interventions)*100, 1)}%</span>
                </div>
                <div class="h-1 w-full bg-gray-800 rounded-full mt-3 overflow-hidden">
                    <div class="h-full bg-purple-500" style="width: {round((total_en_attente/total_interventions)*100, 1)}%"></div>
                </div>
            </div>

            <!-- Card 5 -->
            <div class="bg-gray-900/40 backdrop-blur-md border border-gray-800/80 p-5 rounded-2xl flex flex-col justify-between hover:border-rose-500/40 transition duration-300 shadow-md col-span-2 lg:col-span-1">
                <span class="text-xs font-semibold text-gray-400 uppercase tracking-wider">Annulées</span>
                <div class="flex items-baseline gap-2 mt-2">
                    <span class="text-3xl font-black text-rose-400">{total_annulees}</span>
                    <span class="text-xs text-gray-400 font-medium">{round((total_annulees/total_interventions)*100, 1)}%</span>
                </div>
                <div class="h-1 w-full bg-gray-800 rounded-full mt-3 overflow-hidden">
                    <div class="h-full bg-rose-500" style="width: {round((total_annulees/total_interventions)*100, 1)}%"></div>
                </div>
            </div>

        </section>

        <!-- Charts Layout Grid -->
        <section class="grid grid-cols-1 lg:grid-cols-3 gap-6">
            
            <!-- Chart 1: Evolution over time -->
            <div class="bg-gray-900/40 backdrop-blur-md border border-gray-800/80 p-6 rounded-3xl shadow-xl lg:col-span-2 flex flex-col">
                <h3 class="text-lg font-bold text-white mb-4">📈 Évolution des Interventions (90 derniers jours)</h3>
                <div class="relative w-full flex-grow" style="height: 320px;">
                    <canvas id="timelineChart"></canvas>
                </div>
            </div>

            <!-- Chart 2: Status distribution -->
            <div class="bg-gray-900/40 backdrop-blur-md border border-gray-800/80 p-6 rounded-3xl shadow-xl flex flex-col">
                <h3 class="text-lg font-bold text-white mb-4">🎯 Répartition par Statut</h3>
                <div class="relative w-full flex-grow flex items-center justify-center" style="height: 320px;">
                    <canvas id="statusChart"></canvas>
                </div>
            </div>

            <!-- Chart 3: Tech performance -->
            <div class="bg-gray-900/40 backdrop-blur-md border border-gray-800/80 p-6 rounded-3xl shadow-xl flex flex-col">
                <h3 class="text-lg font-bold text-white mb-4">👷 Performance par Technicien</h3>
                <div class="relative w-full flex-grow" style="height: 320px;">
                    <canvas id="techChart"></canvas>
                </div>
            </div>

            <!-- Chart 4: Common Pannes -->
            <div class="bg-gray-900/40 backdrop-blur-md border border-gray-800/80 p-6 rounded-3xl shadow-xl flex flex-col">
                <h3 class="text-lg font-bold text-white mb-4">⚙️ Pannes les plus Fréquentes</h3>
                <div class="relative w-full flex-grow" style="height: 320px;">
                    <canvas id="panneChart"></canvas>
                </div>
            </div>

            <!-- Chart 5: Downtime per Machine -->
            <div class="bg-gray-900/40 backdrop-blur-md border border-gray-800/80 p-6 rounded-3xl shadow-xl flex flex-col">
                <h3 class="text-lg font-bold text-white mb-4">🏭 Pannes par Machine</h3>
                <div class="relative w-full flex-grow" style="height: 320px;">
                    <canvas id="machineChart"></canvas>
                </div>
            </div>

        </section>

        <!-- Interactive Table Section -->
        <section class="bg-gray-900/30 backdrop-blur-md border border-gray-800/80 rounded-3xl shadow-2xl overflow-hidden">
            
            <div class="p-6 border-b border-gray-800 flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
                <div>
                    <h3 class="text-xl font-extrabold text-white">📋 Journal des Interventions Récentes</h3>
                    <p class="text-gray-400 text-xs mt-1">Affichage des 100 dernières interventions. Cliquez sur une ligne terminée pour visualiser le rapport de panne.</p>
                </div>
                
                <div class="relative w-full sm:w-80">
                    <span class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-500">
                        <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path></svg>
                    </span>
                    <input id="searchInput" type="text" placeholder="Rechercher par technicien, machine ou panne..." 
                           class="w-full pl-10 pr-4 py-2 text-sm bg-gray-950/80 border border-gray-800 rounded-xl focus:outline-none focus:border-blue-500 text-gray-200 placeholder-gray-500 transition duration-300">
                </div>
            </div>

            <!-- Table Wrapper -->
            <div class="overflow-x-auto max-h-[500px]">
                <table class="min-w-full divide-y divide-gray-800 text-left">
                    <thead class="bg-gray-950/60 sticky top-0 backdrop-blur-md z-10 text-xs uppercase tracking-wider text-gray-400 font-bold border-b border-gray-800">
                        <tr>
                            <th class="px-6 py-4">ID</th>
                            <th class="px-6 py-4">Machine</th>
                            <th class="px-6 py-4">Technicien</th>
                            <th class="px-6 py-4">Type de Panne</th>
                            <th class="px-6 py-4">Date de Début</th>
                            <th class="px-6 py-4 text-center">Statut</th>
                            <th class="px-6 py-4 text-center">Rapport</th>
                        </tr>
                    </thead>
                    <tbody id="tableBody" class="divide-y divide-gray-800/60 bg-gray-900/10 text-sm">
                        <!-- Generative content here via Javascript -->
                    </tbody>
                </table>
            </div>

            <!-- Empty search results state -->
            <div id="noResultsState" class="hidden py-12 flex flex-col items-center justify-center text-center">
                <svg class="w-12 h-12 text-gray-600 mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                <p class="text-gray-400 font-medium">Aucun résultat trouvé pour votre recherche.</p>
            </div>

        </section>

    </div>

    <!-- Live Detailed Maintenance Report Modal -->
    <div id="reportModal" class="hidden fixed inset-0 z-50 overflow-y-auto bg-black/85 backdrop-blur-sm flex items-center justify-center p-4">
        
        <div class="bg-[#0D1321] border border-gray-800 rounded-3xl max-w-2xl w-full max-h-[90vh] overflow-y-auto shadow-2xl flex flex-col">
            
            <!-- Modal Header -->
            <div class="px-6 py-5 border-b border-gray-800 flex justify-between items-center sticky top-0 bg-[#0D1321]/95 backdrop-blur-md z-10">
                <div class="flex items-center gap-2">
                    <div class="bg-gradient-to-r from-emerald-500 to-teal-500 p-1.5 rounded-lg">
                        <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                    </div>
                    <h3 class="text-lg font-black text-white">Bon de Travail / Rapport d'Intervention</h3>
                </div>
                <button onclick="closeModal()" class="text-gray-500 hover:text-white transition p-1 bg-gray-900 rounded-lg hover:bg-gray-800">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
                </button>
            </div>

            <!-- Modal Content -->
            <div class="p-6 space-y-6 overflow-y-auto">
                
                <!-- Intervention Meta Header Grid -->
                <div class="grid grid-cols-2 sm:grid-cols-4 gap-4 p-4 bg-gray-950/60 rounded-2xl border border-gray-800/80">
                    <div class="flex flex-col">
                        <span class="text-[10px] text-gray-500 font-bold uppercase tracking-wider">Intervention</span>
                        <span id="modalInterId" class="text-sm font-extrabold text-blue-400 mt-0.5">#00</span>
                    </div>
                    <div class="flex flex-col">
                        <span class="text-[10px] text-gray-500 font-bold uppercase tracking-wider">Type Travail</span>
                        <span id="modalTypeTravail" class="text-sm font-extrabold text-emerald-400 mt-0.5">MCP</span>
                    </div>
                    <div class="flex flex-col">
                        <span class="text-[10px] text-gray-500 font-bold uppercase tracking-wider">Temps d'arrêt</span>
                        <span id="modalTempsArret" class="text-sm font-extrabold text-amber-400 mt-0.5">60 min</span>
                    </div>
                    <div class="flex flex-col">
                        <span class="text-[10px] text-gray-500 font-bold uppercase tracking-wider">État Final</span>
                        <span id="modalEtatFinal" class="text-sm font-extrabold text-purple-400 mt-0.5">Opérationnel</span>
                    </div>
                </div>

                <!-- Info Cards -->
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <div class="p-4 bg-gray-900/40 border border-gray-800 rounded-2xl">
                        <h4 class="text-xs font-bold text-gray-400 uppercase tracking-wider flex items-center gap-1.5 mb-2">
                            🏭 Machine & Localisation
                        </h4>
                        <p id="modalMachineName" class="text-sm font-extrabold text-white">Machine Name</p>
                        <p id="modalLocation" class="text-xs text-gray-400 mt-1">Localisation de la machine</p>
                    </div>

                    <div class="p-4 bg-gray-900/40 border border-gray-800 rounded-2xl">
                        <h4 class="text-xs font-bold text-gray-400 uppercase tracking-wider flex items-center gap-1.5 mb-2">
                            👷 Technicien
                        </h4>
                        <p id="modalTechName" class="text-sm font-extrabold text-white">Tech Name</p>
                        <p class="text-xs text-gray-400 mt-1">Intervenant agréé</p>
                    </div>
                </div>

                <!-- Text Blocks -->
                <div class="space-y-4">
                    
                    <div class="p-4 bg-gray-900/20 border border-gray-800/80 rounded-2xl">
                        <h4 class="text-xs font-bold text-gray-400 uppercase tracking-wider mb-2">⚠️ Description de la Panne</h4>
                        <p id="modalDescription" class="text-sm text-gray-300 leading-relaxed"></p>
                    </div>

                    <div class="p-4 bg-gray-900/20 border border-gray-800/80 rounded-2xl">
                        <h4 class="text-xs font-bold text-gray-400 uppercase tracking-wider mb-2">🔧 Travaux Effectués</h4>
                        <p id="modalTravaux" class="text-sm text-gray-300 leading-relaxed"></p>
                    </div>

                    <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                        <div class="p-4 bg-gray-900/20 border border-gray-800/80 rounded-2xl">
                            <h4 class="text-xs font-bold text-rose-400 uppercase tracking-wider mb-2">🔍 Cause racine</h4>
                            <p id="modalCauses" class="text-sm text-gray-300 leading-relaxed"></p>
                        </div>
                        <div class="p-4 bg-gray-900/20 border border-gray-800/80 rounded-2xl">
                            <h4 class="text-xs font-bold text-emerald-400 uppercase tracking-wider mb-2">💡 Solution corrective</h4>
                            <p id="modalSolutions" class="text-sm text-gray-300 leading-relaxed"></p>
                        </div>
                    </div>

                    <!-- Spare Parts -->
                    <div class="p-4 bg-gray-900/20 border border-gray-800/80 rounded-2xl">
                        <h4 class="text-xs font-bold text-gray-400 uppercase tracking-wider mb-3">📦 Pièces de Rechange Utilisées</h4>
                        <div id="modalPiecesContainer" class="flex flex-wrap gap-2">
                            <!-- Injected badge items -->
                        </div>
                    </div>

                </div>

            </div>

        </div>

    </div>

    <!-- Data Injection scripts and Chart initialization -->
    <script>
        // Inject data query results directly from Python
        const statsData = {json.dumps(statut_data)};
        const techData = {json.dumps(tech_data)};
        const panneTypeData = {json.dumps(panne_type_data)};
        const machineData = {json.dumps(machine_data)};
        const timelineData = {json.dumps(timeline_data)};
        const recentInterventions = {json.dumps(recent_interventions)};

        // Initialize Timeline Chart (Chart 1)
        const sortedDates = Object.keys(timelineData).sort();
        const timelineCounts = sortedDates.map(date => timelineData[date]);
        
        const ctxTimeline = document.getElementById('timelineChart').getContext('2d');
        new Chart(ctxTimeline, {{
            type: 'line',
            data: {{
                labels: sortedDates.map(d => {{
                    const dateObj = new Date(d);
                    return dateObj.toLocaleDateString('fr-FR', {{ day: 'numeric', month: 'short' }});
                }}),
                datasets: [{{
                    label: 'Interventions',
                    data: timelineCounts,
                    borderColor: '#3B82F6',
                    backgroundColor: 'rgba(59, 130, 246, 0.05)',
                    borderWidth: 3,
                    fill: true,
                    tension: 0.35,
                    pointBackgroundColor: '#2563EB',
                    pointHoverRadius: 6
                }}]
            }},
            options: {{
                responsive: true,
                maintainAspectRatio: false,
                plugins: {{
                    legend: {{ display: false }}
                }},
                scales: {{
                    x: {{ grid: {{ color: 'rgba(255,255,255,0.03)' }}, ticks: {{ color: '#9CA3AF', font: {{ size: 10 }} }} }},
                    y: {{ grid: {{ color: 'rgba(255,255,255,0.03)' }}, ticks: {{ color: '#9CA3AF', font: {{ size: 10 }} }} }}
                }}
            }}
        }});

        // Initialize Status Doughnut Chart (Chart 2)
        const ctxStatus = document.getElementById('statusChart').getContext('2d');
        new Chart(ctxStatus, {{
            type: 'doughnut',
            data: {{
                labels: Object.keys(statsData),
                datasets: [{{
                    data: Object.values(statsData),
                    backgroundColor: [
                        '#10B981', // Terminées
                        '#F59E0B', // En cours
                        '#3B82F6', // Acceptées
                        '#8B5CF6', // En attente
                        '#EF4444'  // Annulées
                    ],
                    borderWidth: 2,
                    borderColor: '#0F172A'
                }}]
            }},
            options: {{
                responsive: true,
                maintainAspectRatio: false,
                plugins: {{
                    legend: {{
                        position: 'bottom',
                        labels: {{ color: '#D1D5DB', boxWidth: 12, font: {{ size: 10, weight: 'bold' }}, padding: 15 }}
                    }}
                }},
                cutout: '72%'
            }}
        }});

        // Initialize Tech Performance Chart (Chart 3)
        const ctxTech = document.getElementById('techChart').getContext('2d');
        new Chart(ctxTech, {{
            type: 'bar',
            data: {{
                labels: Object.keys(techData),
                datasets: [{{
                    data: Object.values(techData),
                    backgroundColor: 'rgba(99, 102, 241, 0.75)',
                    hoverBackgroundColor: '#6366F1',
                    borderRadius: 8
                }}]
            }},
            options: {{
                responsive: true,
                maintainAspectRatio: false,
                plugins: {{ legend: {{ display: false }} }},
                scales: {{
                    x: {{ grid: {{ display: false }}, ticks: {{ color: '#9CA3AF', font: {{ size: 9 }} }} }},
                    y: {{ grid: {{ color: 'rgba(255,255,255,0.03)' }}, ticks: {{ color: '#9CA3AF' }} }}
                }}
            }}
        }});

        // Initialize Common Pannes Chart (Chart 4)
        const ctxPanne = document.getElementById('panneChart').getContext('2d');
        new Chart(ctxPanne, {{
            type: 'bar',
            data: {{
                labels: Object.keys(panneTypeData),
                datasets: [{{
                    data: Object.values(panneTypeData),
                    backgroundColor: 'rgba(236, 72, 153, 0.75)',
                    hoverBackgroundColor: '#EC4899',
                    borderRadius: 6
                }}]
            }},
            options: {{
                indexAxis: 'y',
                responsive: true,
                maintainAspectRatio: false,
                plugins: {{ legend: {{ display: false }} }},
                scales: {{
                    x: {{ grid: {{ color: 'rgba(255,255,255,0.03)' }}, ticks: {{ color: '#9CA3AF' }} }},
                    y: {{ grid: {{ display: false }}, ticks: {{ color: '#9CA3AF', font: {{ size: 9 }} }} }}
                }}
            }}
        }});

        // Initialize Machine Downtime Chart (Chart 5)
        const ctxMachine = document.getElementById('machineChart').getContext('2d');
        new Chart(ctxMachine, {{
            type: 'bar',
            data: {{
                labels: Object.keys(machineData).map(m => m.length > 20 ? m.substring(0, 18) + '...' : m),
                datasets: [{{
                    data: Object.values(machineData),
                    backgroundColor: 'rgba(20, 184, 166, 0.75)',
                    hoverBackgroundColor: '#14B8A6',
                    borderRadius: 8
                }}]
            }},
            options: {{
                responsive: true,
                maintainAspectRatio: false,
                plugins: {{ legend: {{ display: false }} }},
                scales: {{
                    x: {{ grid: {{ display: false }}, ticks: {{ color: '#9CA3AF', font: {{ size: 9 }}, maxRotation: 45, minRotation: 45 }} }},
                    y: {{ grid: {{ color: 'rgba(255,255,255,0.03)' }}, ticks: {{ color: '#9CA3AF' }} }}
                }}
            }}
        }});

        // Populate Table Functionality
        const tableBody = document.getElementById('tableBody');
        const searchInput = document.getElementById('searchInput');
        const noResultsState = document.getElementById('noResultsState');

        function getStatusBadge(statut) {{
            const styles = {{
                'TERMINEE': 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20',
                'EN_COURS': 'bg-amber-500/10 text-amber-400 border border-amber-500/20',
                'ACCEPTEE': 'bg-blue-500/10 text-blue-400 border border-blue-500/20',
                'EN_ATTENTE': 'bg-purple-500/10 text-purple-400 border border-purple-500/20',
                'ANNULEE': 'bg-rose-500/10 text-rose-400 border border-rose-500/20'
            }};
            return `<span class="px-2.5 py-1 text-xs font-semibold rounded-full border ${{(styles[statut] || styles['EN_ATTENTE'])}}">${{statut}}</span>`;
        }}

        function getRapportButton(item) {{
            if (item.statut === 'TERMINEE' && item.rapport && Object.keys(item.rapport).length > 0) {{
                return `<button onclick="openModal(${{item.id_intervention}})" class="text-xs font-semibold px-3 py-1.5 bg-emerald-500/10 hover:bg-emerald-500 text-emerald-400 hover:text-white border border-emerald-500/20 rounded-xl transition duration-300 flex items-center gap-1 mx-auto">
                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path></svg>
                    Voir
                </button>`;
            }}
            return `<span class="text-gray-600 text-xs">-</span>`;
        }}

        function renderTable(items) {{
            tableBody.innerHTML = '';
            if (items.length === 0) {{
                noResultsState.classList.remove('hidden');
                return;
            }}
            noResultsState.classList.add('hidden');
            
            items.forEach(item => {{
                const d = new Date(item.date_debut);
                const formattedDate = d.toLocaleString('fr-FR', {{ day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }});
                const isClickable = item.statut === 'TERMINEE' && item.rapport && Object.keys(item.rapport).length > 0;
                const rowClick = isClickable ? `onclick="openModal(${{item.id_intervention}})" style="cursor: pointer;"` : '';
                
                const row = document.createElement('tr');
                row.className = `hover:bg-gray-800/40 border-b border-gray-800/30 transition duration-150 ${{isClickable ? 'hover:bg-gray-800/60' : ''}}`;
                row.innerHTML = `
                    <td ${{rowClick}} class="px-6 py-4 font-mono font-bold text-gray-400">#${{item.id_intervention}}</td>
                    <td ${{rowClick}} class="px-6 py-4 font-semibold text-white">${{item.machine}}</td>
                    <td ${{rowClick}} class="px-6 py-4 text-gray-300 font-medium">${{item.technicien}}</td>
                    <td ${{rowClick}} class="px-6 py-4 text-gray-400">${{item.type_panne}}</td>
                    <td ${{rowClick}} class="px-6 py-4 text-xs text-gray-400 font-medium">${{formattedDate}}</td>
                    <td ${{rowClick}} class="px-6 py-4 text-center z-10">${{getStatusBadge(item.statut)}}</td>
                    <td class="px-6 py-4 text-center z-20">${{getRapportButton(item)}}</td>
                `;
                tableBody.appendChild(row);
            }});
        }}

        // Search Filter
        searchInput.addEventListener('input', (e) => {{
            const val = e.target.value.toLowerCase().trim();
            const filtered = recentInterventions.filter(item => {{
                return item.technicien.toLowerCase().includes(val) ||
                       item.machine.toLowerCase().includes(val) ||
                       item.type_panne.toLowerCase().includes(val) ||
                       item.id_intervention.toString().includes(val);
            }});
            renderTable(filtered);
        }});

        // Modal Functionality
        const modal = document.getElementById('reportModal');
        
        window.openModal = function(id) {{
            const item = recentInterventions.find(i => i.id_intervention === id);
            if (!item || !item.rapport) return;

            document.getElementById('modalInterId').innerText = `#${{item.id_intervention}}`;
            document.getElementById('modalTypeTravail').innerText = item.rapport.type_travail || 'Correctif';
            document.getElementById('modalTempsArret').innerText = `${{item.rapport.temps_arret}} min`;
            document.getElementById('modalEtatFinal').innerText = item.rapport.etat_final || 'Fonctionnel';
            document.getElementById('modalMachineName').innerText = item.machine;
            
            // Localisation de la machine
            const machMeta = recentInterventions.find(x => x.machine === item.machine);
            document.getElementById('modalLocation').innerText = `Ubic : ${{item.rapport.codes_defaut ? item.rapport.codes_defaut.where : 'Ligne principale'}}`;
            
            document.getElementById('modalTechName').innerText = item.technicien;
            document.getElementById('modalDescription').innerText = item.rapport.description || 'N/A';
            document.getElementById('modalTravaux').innerText = item.rapport.travaux || 'N/A';
            document.getElementById('modalCauses').innerText = item.rapport.causes || 'Usure naturelle.';
            document.getElementById('modalSolutions').innerText = item.rapport.solutions || 'Changement de la pièce défectueuse.';
            
            // Spare parts
            const container = document.getElementById('modalPiecesContainer');
            container.innerHTML = '';
            if (item.rapport.pieces && item.rapport.pieces.length > 0) {{
                item.rapport.pieces.forEach(p => {{
                    container.innerHTML += `<span class="px-3 py-1.5 text-xs font-semibold rounded-lg bg-gray-900 border border-gray-800 text-gray-300 flex items-center gap-1">
                        📦 ${{p.part_name}} <span class="text-blue-400 font-bold">x${{p.quantity}}</span>
                    </span>`;
                }});
            }} else {{
                container.innerHTML = '<span class="text-xs text-gray-500 italic">Aucune pièce consommée</span>';
            }}

            modal.classList.remove('hidden');
            document.body.style.overflow = 'hidden';
        }}

        window.closeModal = function() {{
            modal.classList.add('hidden');
            document.body.style.overflow = '';
        }}

        // Initial Render
        renderTable(recentInterventions);
    </script>
</body>
</html>
"""

        # Enregistrer le fichier dans le dossier monté (/app/app/data/) de sorte qu'il apparaisse instantanément sur l'hôte!
        output_dir = "/app/app/data"
        if not os.path.exists(output_dir):
            os.makedirs(output_dir, exist_ok=True)
            
        file_path = os.path.join(output_dir, "visualiser_donnees.html")
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(html_content)
            
        print(f"✅ HTML report generated successfully at {file_path}!")
        
    except Exception as e:
        print(f"❌ Error while generating HTML report: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    generate_html_report()
