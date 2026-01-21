# ============================================
# Demo 2: GitHub Advanced Security (GHAS)
# ============================================
# Scenario: Demo 1 files contain hardcoded secrets (Service Bus SharedAccessKey, RabbitMQ credentials)
# Goal: Push to GitHub and demonstrate how GHAS automatically detects these vulnerabilities
# After push: Security > Secret scanning on GitHub

git add .
git commit -m "Demo 1: Add AKS deployment with hardcoded secrets (for GHAS detection)"
git push -u origin master
