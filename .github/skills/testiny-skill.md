# Testiny Skill (updated)

Commands:
- store-token <token>
- list-projects
- list-testcases [projectId] [testplanId]
- print-curl

Examples:
- .\scripts\testiny-skill.ps1 list-testcases                # lists testcases for all projects
- .\scripts\testiny-skill.ps1 list-testcases 1              # lists testcases for project id 1
- .\scripts\testiny-skill.ps1 list-testcases 1 2            # lists testcases for project 1, testplan 2
