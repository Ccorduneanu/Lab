# gh CLI Skill

This skill is a simple wrapper script to run gh CLI commands in a reproducible way for repository actions.

Usage:

Windows PowerShell:

  .\scripts\gh-skill.ps1 repo view Ccorduneanu/Lab

It uses your local gh authentication (gh auth status) and requires gh to be installed and authenticated.

Security: Do not store PATs in the script. The script forwards arguments to gh and runs with the current user context.
