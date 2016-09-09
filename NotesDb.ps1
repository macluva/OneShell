function New-NotesOdbcDbObject
{
    New-Object PSObject -Property @{
        _Dsn = ""
        _ViewName = ""
        _bXmlFriendly = $true
        _OdbcConnectionStringBuilder = (New-Object System.Data.Odbc.OdbcConnectionStringBuilder)
        _OdbcConnection = (New-Object System.Data.Odbc.OdbcConnection)
        _OdbcCommand = (New-Object System.Data.Odbc.OdbcCommand)
        _OdbcDataAdapter = (New-Object System.Data.Odbc.OdbcDataAdapter)
    }
}

function New-NotesOdbcDbViewTableObject
{
    New-Object PSObject -Property @{
        _Dsn = ""
        _ViewName = ""
        _bXmlFriendly = $true
        _OdbcConnectionStringBuilder = (New-Object System.Data.Odbc.OdbcConnectionStringBuilder)
        _OdbcConnection = (New-Object System.Data.Odbc.OdbcConnection)
        _OdbcCommand = (New-Object System.Data.Odbc.OdbcCommand)
        _OdbcDataAdapter = (New-Object System.Data.Odbc.OdbcDataAdapter)
        _DataSetName = ""
        _DataTableName = ""
        _DataSet = ([System.Data.DataSet] $null)
        _DataTable = ([System.Data.DataTable] $null)
    }
}

function Initialize-NotesOdbcDb
{
    param(
        [Object] $_LNotesDb
    )

    $_LNotesDb._OdbcConnectionStringBuilder.Driver = "Lotus NotesSQL Driver (*.nsf)"
    $_LNotesDb._OdbcConnectionStringBuilder.Dsn = $_LNotesDb._Dsn
    $_LNotesDb._OdbcConnection.ConnectionString = $_LNotesDb._OdbcConnectionStringBuilder.ConnectionString
}

function Mount-NotesOdbcDb
{
    param(
        [Object] $_LNotesDb
    )

    $result = $_LNotesDb._OdbcConnection.Open()
}

function Select-NotesOdbcDbView
{
    param(
        [Object] $_LNotesDb
    )
    
    $_LNotesDb._Viewname = $_LNotesDb._ViewName
    ## Link the Connection object to the Command object
    $_LNotesDb._OdbcCommand.Connection = $_LNotesDb._OdbcConnection
    $_LNotesDb._OdbcCommand.CommandText = "SELECT * FROM ""$($_LNotesDb._ViewName)"""

    ## Link the Comand object to the Adapter object
    $_LNotesDb._OdbcDataAdapter.SelectCommand = $_LNotesDb._OdbcCommand
}

function Export-NotesDbViewTable
{
    param(
        [Object] $_LNotesDb
    )

    $_LNotesDb._DataSet = New-Object "System.Data.DataSet" $_LNotesDb._DataSetName
    $_LNotesDb._DataTable = New-Object "System.Data.DataTable" $_LNotesDb._DataTableName
    $_result = $_LNotesDb._DataSet.Tables.Add($_LNotesDb._DataTable)

    ## Fill the $_DataTable object with the results
    $_result = $_LNotesDb._OdbcDataAdapter.Fill($_LNotesDb._DataTable)
    
    ## Rename columns to use acceptable alpha-numerics
    if ($_LNotesDb._bXmlFriendly)
    {
        $_LNotesDb._DataTable.Columns `
        |
        % `
        {
            if ( $_.ColumnName -match "^_\d.*" )
            {
                $_.ColumnName = $_.ColumnName `
                    -replace "^_", "F"
            }
            $_.ColumnName = $_.ColumnName `
                -replace "\#", "Num" `
                -replace "[^a-z^A-Z^0-9_]", ""
        }
    }
    $_LNotesDb._DataTable = $_LNotesDb._DataSet.Tables[$_LNotesDb._DataTableName]
}

function Dismount-NotesOdbcDb
{
    param(
        [Object] $_LNotesDb
    )
    
    ## close the connection 
    $_LNotesDb._OdbcConnection.Close() 
    $_LNotesDb._OleDbConnection.State
}

function Remove-NotesDbTable
{
    param(
        [Object] $_LNotesDb
    )
    
    $_LNotesDb._DataSet.Tables[$_LNotesDb._DataTableName].Dispose()
    $_LNotesDb._DataSet.Dispose()
}

function Remove-NotesOdbcDb
{
    param(
        [Object] $_LNotesDb
    )
    ## Clean up, because it is not done autmatically
    $_LNotesDb._OdbcConnection.Dispose()
    $_LNotesDb._OdbcCommand.Dispose()
    $_LNotesDb._OdbcDataAdapter.Dispose()
}

function Exit-NotesOdbcDb
{
    param(
        [Object] $_LNotesDb
    )

    try
    {
        Dismount-NotesOdbcDb $_LNotesDb
    }
    finally
    {
        try
        {
            Remove-NotesDbTable $_LNotesDb
        }
        finally
        {
            try
            {
                Remove-NotesOdbcDb $_LNotesDb
            }
            finally
            {
            }
        }
    }
}

function Get-NotesOdbcDbViewTable
{
    param(
        [String] $_Dsn,
        [String] $_ViewName,
        [String] $_DataSetName,
        [String] $_DataTableName,
        [Boolean] $_bXmlFriendly
    )
    
    $_LNotesDb = New-NotesOdbcDbViewTableObject
    $_LNotesDb._Dsn = $_Dsn
    $_LNotesDb._ViewName = $_ViewName
    $_LNotesDb._DataSetName = $_DataSetName
    $_LNotesDb._DataTableName = $_DataTableName
    $_LNotesDb._bXmlFriendly = $_bXmlFriendly

    Initialize-NotesOdbcDb $_LNotesDb
    Mount-NotesOdbcDb $_LNotesDb
    Select-NotesOdbcDbView $_LNotesDb
    Export-NotesDbViewTable $_LNotesDb
    
    $_LNotesDb
}

function Test-NotesOdbcDb
{
    param(
        [string] $_db,
        [string] $_view,
        [string] $_XmlRoot,
        [string] $_XmlNode
    )
    try
    {
        $_LNotesDb = Get-NotesOdbcDbViewTable `
            $_db `
            $_view `
            $_XmlRoot `
            $_XmlNode `
            $true

        $_DataTable = $_LNotesDb._DataSet.Tables[$_LNotesDb._DataTableName] ## Optimize table lookup
        
<#
        $_SortedDataTable = $_DataTable.Select( "", "ServerName ASC" )
        
        $_SortedDataTable `
        |
        Out-GridView -Title "sorted table"

        $_SortedDataTable `
        |
        Select-Object `
            -Property `
                ServerName, `
                ServerDescription, `
                SysSerial, `
                NumberCPU, `
                OfficeIndicator, `
                NotesGroupName `
        |
        ConvertTo-Html -CssUri test.css -As TABLE `
            > test.htm
#>
        
        $_csv = ($_DataTable | ConvertTo-Csv)[1..$_LNotesDb._DataTable.Rows.Count]
        $_csv > test.csv
        # $_DataTable.Rows | Out-GridView -Title "raw table"
        # Write-Output $_DataTable.rows[0]["Servername"] ## Access a column by name
        # Write-Output $_DataTable.rows | % { $_["ServerName"] } ## Access a column on all rows
    }
    finally
    {
        Exit-NotesOdbcDb $_LNotesDb
    }
}
