# Testiny Skill

This skill provides a small PowerShell wrapper to call the Testiny API using a stored, encrypted token.

Usage:
- Store token (one-time):
  .\scripts\testiny-skill.ps1 store-token <your-token>
- List projects:
  .\scripts\testiny-skill.ps1 list-projects

Token storage:
- Token is stored encrypted per-user at: $env:USERPROFILE\.testiny\token.txt
- The token is NOT committed to the repository.
