@{

    ModuleVersion = '1.0.0'


    GUID = 'd3f92c1b-ae3d-4d74-940c-0e56de9c5a89'

    
    Author = 'LouisonCourtois'


    Description = 'PowerShell module to insert, delete, and update user and group data in a SQL Server database.'

    
    FunctionsToExport = @(
        'Insert-User',
        'Insert-List-Users',
        'Insert-Groups',
        'Insert-link-User-Group',
        'Delete-User',
        'Delete-Group',
        'Delete-Link-User-Group'
    )

    CmdletsToExport = @()

    VariablesToExport = @()

   
    AliasesToExport = @()
}
