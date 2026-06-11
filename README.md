# GitCalc 🧮

A premium, beautiful **GitHub-themed Calculator app** built using **Flutter** for Android, iOS, and Web. 

GitCalc is not just a standard calculator; it integrates with the **GitHub API** to fetch developer statistics (followers, public repos, following, gists) and lets you feed those metrics directly into your calculator expressions!

## Features

1. **GitHub Dark-Mode UI**: Designed using the official GitHub Dark palette (`#0d1117`, `#161b22`, `#58a6ff`, `#238636`, etc.).
2. **Standard Calculator Mode**: Supports addition, subtraction, multiplication, division, percentage, floating decimals, deletion, and clear operations.
3. **Developer Stats Lookup**: Integrated search screen that pulls real-time profile details from the public GitHub API.
4. **Git-Expression Integration**: Tap any fetched statistic box (e.g., repository count or follower count) to inject that number directly into the active calculator buffer.

---

## Project Structure

```text
calc/
│
├── lib/
│   ├── main.dart                  # Central controller, state & theme management
│   ├── calculator_logic.dart      # Math expression parsing & evaluation engine
│   ├── github_service.dart        # GitHub REST API service
│   └── screens/
│       ├── calculator_screen.dart # Calculator GUI keypad and display layout
│       └── stats_screen.dart      # Search bar, stats display, contribution graph
│
├── pubspec.yaml                   # Flutter dependencies (http, math_expressions, google_fonts)
├── preview.html                   # Standalone browser prototype of the app
└── README.md                      # Documentation
```

---

## 🚀 How to Test the Project Instantly

Because Git and Flutter are not yet configured in this terminal environment, you can run a **fully interactive local preview** directly in your browser:

1. Locate the `preview.html` file in this directory:
   [preview.html](file:///C:/Users/Asus1/.gemini/antigravity/scratch/calc/preview.html)
2. **Double-click** the file in your File Explorer (or drag and drop it into any web browser).
3. The preview contains a high-fidelity rendering of a smartphone running the app, connected to the **live public GitHub API**. You can search profiles and tap metrics to test the calculator functionality.

---

## 📂 Push to Your GitHub Repository

We have provided a helper PowerShell script [push.ps1](file:///C:/Users/Asus1/.gemini/antigravity/scratch/calc/push.ps1) in this directory that automates the initialization and push commands.

### Option A: Run the Helper Script
1. Right-click [push.ps1](file:///C:/Users/Asus1/.gemini/antigravity/scratch/calc/push.ps1) and select **Run with PowerShell** (or run `./push.ps1` in your terminal).
2. The script will initialize your repo, commit the code, link it to your GitHub repository, and push it.

### Option B: Run Commands Manually
Run these commands in your local terminal (Git Bash, Command Prompt, or PowerShell) inside the project directory:


```bash
# 1. Initialize git
git init

# 2. Add files
git add .

# 3. Commit
git commit -m "Initial commit: GitHub-themed Flutter Calculator"

# 4. Set branch to main
git branch -M main

# 5. Add remote repository URL
git remote add origin https://github.com/kashinathyankanchi-maker/calc.git

# 6. Push to GitHub
git push -u origin main
```

---

## 📱 How to Run the Flutter App on Android/iOS

Once you have the **Flutter SDK** and **Android Studio / Xcode** installed on your development machine, you can run the app:

1. **Install Dependencies**:
   ```bash
   flutter pub get
   ```
2. **Check Connected Devices**:
   ```bash
   flutter devices
   ```
3. **Launch the Application**:
   ```bash
   flutter run
   ```
