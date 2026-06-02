# Script PowerShell pour démarrer l'ensemble du projet
# Docker pour Backend/DB + Fenêtres natives pour Flutter

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "      DEMARRAGE COMPLET DU PROJET mainTech                " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Lancement de Docker Compose (Backend + PostgreSQL)
Write-Host "" -ForegroundColor Green
Write-Host "[1/3] Lancement des conteneurs Docker (FastAPI, PostgreSQL)..." -ForegroundColor Green
docker compose up -d --build

# Pause pour laisser le temps au backend de démarrer
Start-Sleep -Seconds 3

# 2. Lancement de Desktop Admin (Application de Bureau)
Write-Host "" -ForegroundColor Cyan
Write-Host "[2/3] Lancement de Desktop Admin (Application Windows native)..." -ForegroundColor Cyan
# Ouvre une nouvelle fenêtre PowerShell qui exécute flutter run et reste ouverte (-NoExit)
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd desktop_admin; flutter run -d windows"

# 3. Lancement du Frontend Mobile
Write-Host "" -ForegroundColor Cyan
Write-Host "[3/3] Lancement du Frontend Mobile (sur le téléphone physique)..." -ForegroundColor Cyan
# Ouvre une nouvelle fenêtre PowerShell qui exécute flutter run
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd frontend; flutter run"

Write-Host "" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "   Projet demarre avec succes !" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "Composants lances :" -ForegroundColor Cyan
Write-Host "   - Backend API & DB       : Docker (http://localhost:8000/docs)" -ForegroundColor Yellow
Write-Host "   - Console Desktop Admin  : Fenêtre native Windows" -ForegroundColor Yellow
Write-Host "   - Application Mobile     : Téléphone physique" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Green
