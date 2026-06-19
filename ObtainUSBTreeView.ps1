Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing


function Get-DeviceChain {
    param ([string]$InstanceId)

    $device = Get-PnpDevice -InstanceId $InstanceId -ErrorAction SilentlyContinue
    if (-not $device) { return }

    $parentProp = Get-PnpDeviceProperty -InstanceId $InstanceId `
        -KeyName 'DEVPKEY_Device_Parent' -ErrorAction SilentlyContinue

    [PSCustomObject]@{
        FriendlyName = $device.FriendlyName
        InstanceId   = $device.InstanceId
        Parent       = $parentProp.Data
    }

    if ($parentProp.Data -and $parentProp.Data -ne $InstanceId) {
        Get-DeviceChain -InstanceId $parentProp.Data
    }
}

function Collect-Data {
    Get-PnpDevice -Class Ports -ErrorAction SilentlyContinue | ForEach-Object {
        Get-DeviceChain -InstanceId $_.InstanceId
    }
}


$form = New-Object System.Windows.Forms.Form
$form.Text            = "Device Chain Viewer"
$form.Size            = New-Object System.Drawing.Size(1000, 600)
$form.StartPosition   = "CenterScreen"
$form.MinimumSize     = New-Object System.Drawing.Size(640, 400)
$form.Font            = New-Object System.Drawing.Font("Segoe UI", 9)


$dgv = New-Object System.Windows.Forms.DataGridView
$dgv.Dock                        = "Fill"
$dgv.ReadOnly                    = $true
$dgv.AllowUserToAddRows          = $false
$dgv.AllowUserToDeleteRows       = $false
$dgv.AllowUserToResizeRows       = $false
$dgv.RowHeadersVisible           = $false
$dgv.AutoSizeColumnsMode         = "Fill"
$dgv.SelectionMode               = "FullRowSelect"
$dgv.MultiSelect                 = $false
$dgv.BackgroundColor             = [System.Drawing.Color]::FromArgb(250, 250, 250)
$dgv.BorderStyle                 = "None"
$dgv.CellBorderStyle             = "SingleHorizontal"
$dgv.GridColor                   = [System.Drawing.Color]::FromArgb(220, 220, 220)
$dgv.Font                        = New-Object System.Drawing.Font("Consolas", 8.5)
$dgv.ColumnHeadersDefaultCellStyle.BackColor  = [System.Drawing.Color]::FromArgb(45, 45, 48)
$dgv.ColumnHeadersDefaultCellStyle.ForeColor  = [System.Drawing.Color]::White
$dgv.ColumnHeadersDefaultCellStyle.Font       = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$dgv.ColumnHeadersHeightSizeMode = "DisableResizing"
$dgv.ColumnHeadersHeight         = 30
$dgv.EnableHeadersVisualStyles   = $false
$dgv.DefaultCellStyle.Padding    = New-Object System.Windows.Forms.Padding(4, 0, 4, 0)
$dgv.RowTemplate.Height          = 24
$dgv.AlternatingRowsDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(240, 245, 255)
$form.Controls.Add($dgv)


$toolbar = New-Object System.Windows.Forms.Panel
$toolbar.Dock         = "Top"
$toolbar.Height       = 44
$toolbar.BackColor    = [System.Drawing.Color]::FromArgb(30, 30, 30)
$form.Controls.Add($toolbar)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text        = "COM / Serial Device Chain"
$lblTitle.ForeColor   = [System.Drawing.Color]::White
$lblTitle.Font        = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$lblTitle.AutoSize    = $true
$lblTitle.Location    = New-Object System.Drawing.Point(12, 12)
$toolbar.Controls.Add($lblTitle)

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text      = "Refresh"
$btnRefresh.Size      = New-Object System.Drawing.Size(90, 26)
$btnRefresh.Location  = New-Object System.Drawing.Point(870, 9)
$btnRefresh.FlatStyle = "Flat"
$btnRefresh.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
$btnRefresh.ForeColor = [System.Drawing.Color]::White
$btnRefresh.FlatAppearance.BorderSize = 0
$toolbar.Controls.Add($btnRefresh)


$statusBar = New-Object System.Windows.Forms.StatusStrip
$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text     = "Ready"
$statusBar.Items.Add($statusLabel) | Out-Null
$form.Controls.Add($statusBar)

function Load-Data {
    $statusLabel.Text = "Scanning devices"
    $form.Cursor      = [System.Windows.Forms.Cursors]::WaitCursor
    $dgv.DataSource   = $null
    $form.Refresh()

    try {
        $rows = @(Collect-Data)

        $table = New-Object System.Data.DataTable
        $table.Columns.Add("FriendlyName") | Out-Null
        $table.Columns.Add("InstanceId")   | Out-Null
        $table.Columns.Add("Parent")       | Out-Null

        foreach ($r in $rows) {
            $table.Rows.Add($r.FriendlyName, $r.InstanceId, $r.Parent) | Out-Null
        }

        $dgv.DataSource = $table

        
        if ($dgv.Columns.Count -ge 3) {
            $dgv.Columns[0].FillWeight = 25   
            $dgv.Columns[1].FillWeight = 40   
            $dgv.Columns[2].FillWeight = 35   
        }

        $statusLabel.Text = "$($rows.Count) row(s) loaded – $(Get-Date -Format 'HH:mm:ss')"
    }
    catch {
        $statusLabel.Text = "Error: $_"
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to enumerate devices:`n$_", "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
    finally {
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
}


$btnRefresh.Add_Click({ Load-Data })


$form.Add_Resize({
    $btnRefresh.Location = New-Object System.Drawing.Point(($toolbar.Width - 100), 9)
})


$form.Add_Shown({ Load-Data })

[System.Windows.Forms.Application]::Run($form)