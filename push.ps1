# GitCalc Push Helper Script
Clear-Host

Write-Host "=== GitCalc GitHub Push Helper ===" -ForegroundColor Cyan
Write-Host "This script will initialize Git, commit the files, and push them to your repository." -ForegroundColor Gray
Write-Host ""

# Check if git is installed locally on user's machine
if (!(Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] Git was not found on your local system." -ForegroundColor Red
    Write-Host "Please install Git from https://git-scm.com/ and try again." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit
}

# Run Git initialization
Write-Host "1. Initializing local Git repository..." -ForegroundColor Blue
git init

Write-Host "2. Adding files to staging..." -ForegroundColor Blue
git add .

Write-Host "3. Creating initial commit..." -ForegroundColor Blue
git commit -m "Initial commit: GitHub-themed Flutter Calculator"

Write-Host "4. Setting default branch to 'main'..." -ForegroundColor Blue
git branch -M main

# Check if origin already exists
$existingRemote = git remote get-url origin 2>$null
if ($existingRemote) {
    Write-Host "Removing existing remote origin ($existingRemote)..." -ForegroundColor Gray
    git remote remove origin
}

Write-Host "5. Adding remote origin (https://github.com/kashinathyankanchi-maker/calc.git)..." -ForegroundColor Blue
git remote add origin https://github.com/kashinathyankanchi-maker/calc.git

Write-Host "6. Pushing to GitHub (this may prompt you to log in)..." -ForegroundColor Blue
git push -u origin main

Write-Host ""
Write-Host "=== Process Completed! ===" -ForegroundColor Green
Write-Host "Please refresh your repository page at: https://github.com/kashinathyankanchi-maker/calc" -ForegroundColor Green
Write-Host ""
Read-Host "Press Enter to exit"
