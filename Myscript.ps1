    #Função para download usando cmdlet bit-transfer

function Get-File {
    param (

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [System.Uri]
        $Url,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo]
        $TargetFile,
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Int32]
        $BufferSize = 1,
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('KB, MB')]
        [String]
        $BufferUnit = 'MB',
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('KB, MB')]
        [Int32]
        $Timeout = 10000

    )
    
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $useBitTransfer = $null -ne (Get-Module -Name BitsTransfer -ListAvailable) -and ($PSVersionTable.PSVersion.Major -le 5) -and ((Get-Service -Name BITS).StartType -ne [System.ServiceProcess.ServiceStartMode]::Disabled)

    if ($useBitTransfer)
    {
        Write-Information -MessageData 'Using a fallback BitTransfer method since you are running Windows PowerShell'
        Start-BitsTransfer -Source $Url -Destination "$($TargetFile.FullName)"
    }
    else
    {
        $request = [System.Net.HttpWebRequest]::Create($Url)
        $request.set_Timeout($Timeout) #15 second timeout
        $response = $request.GetResponse()
        $totalLength = [System.Math]::Floor($response.get_ContentLength() / 1024)
        $responseStream = $response.GetResponseStream()
        $targetStream = New-Object -TypeName ([System.IO.FileStream]) -ArgumentList "$($TargetFile.FullName)", Create
        switch ($BufferUnit)
        {
        'KB' { $BufferSize = $BufferSize * 1024 }
        'MB' { $BufferSize = $BufferSize * 1024 * 1024 }
        Default { $BufferSize = 1024 * 1024 }
        }
        Write-Verbose -Message "Buffer size: $BufferSize B ($($BufferSize/("1$BufferUnit")) $BufferUnit)"
        $buffer = New-Object byte[] $BufferSize
        $count = $responseStream.Read($buffer, 0, $buffer.length)
        $downloadedBytes = $count
        $downloadedFileName = $Url -split '/' | Select-Object -Last 1
        while ($count -gt 0)
        {
        $targetStream.Write($buffer, 0, $count)
        $count = $responseStream.Read($buffer, 0, $buffer.length)
        $downloadedBytes = $downloadedBytes + $count
        Write-Progress -Activity "Downloading file '$downloadedFileName'" -Status "Downloaded ($([System.Math]::Floor($downloadedBytes/1024))K of $($totalLength)K): " -PercentComplete ((([System.Math]::Floor($downloadedBytes / 1024)) / $totalLength) * 100)
        }

        Write-Progress -Activity "Finished downloading file '$downloadedFileName'"

        $targetStream.Flush()
        $targetStream.Close()
        $targetStream.Dispose()
        $responseStream.Dispose()
    }
}

$GoogleFileId = '1cXwUbdX2N3YDvLqogrt3JhJB7EZ_NYuA'
$DownloadPath = Join-Path -Path $env:USERPROFILE -ChildPath 'downloads'
$versionspath = Join-Path -Path $env:APPDATA -ChildPath '.minecraft' | Join-path -ChildPath 'versions'

    #Lista de pastas de versions

$array = (Get-ChildItem -Path $versionspath -Directory).Name

for ($i=0; $i -lt $Array.Length; $i++) {
    $x = $i +1
    $a = $Array[$i]
    Write-Output "[$x] = $a"
}

$choice = Read-Host "escolha a pasta do tlauncher para aplicar o patch"
$namepath = $array[$choice-1]
$jsonFilePath = Join-Path -Path $versionspath -ChildPath "$namepath"
$extractpath = Join-Path -Path $jsonFilePath -ChildPath 'mods'


Write-Host "Preparando o download pelo google drive`n"

Invoke-WebRequest -Uri "https://drive.google.com/uc?export=download&id=$GoogleFileId" -OutFile "_tmp.txt" -SessionVariable googleDriveSession

    # Get confirmation code from _tmp.txt

$searchString = Select-String -Path "_tmp.txt" -Pattern "confirm="
$searchString[0] -match "confirm=(?<content>.*)&amp;id="
$confirmCode = $matches['content']

    # Delete _tmp.txt

Remove-Item "_tmp.txt"

Write-Host "Downloading latest patch (mods.zip)...`n"

$FilePath = Join-Path -Path $DownloadPath -ChildPath 'mods.zip'
try
{
    
  $Url = "https://drive.google.com/uc?export=download&confirm=${confirmCode}&id=$GoogleFileId"
  Get-File -Url $Url -TargetFile "$FilePath"
}
catch
{
  Write-Output $_
  Start-Sleep
}
    #Json script

$jsonFileId = '1uPHaWK03wF6bCaianRvGHlNcBcWwjENW'
$jsonFile = Join-Path -Path $jsonFilePath -ChildPath 'TLauncherAdditional.json'
Invoke-WebRequest -Uri "https://drive.google.com/uc?export=download&id=$jsonFileId" -OutFile $jsonFile

$json = Get-Content -Raw -Path $jsonFile | ConvertFrom-Json
$json.modpack.name = "$namepath"
$json | ConvertTo-Json -depth 32 -Compress | Set-Content -path $jsonFile

    #Extract
    
Remove-Item -Path "$extractpath" -Recurse
Expand-Archive -Force -LiteralPath "$FilePath" -DestinationPath $extractpath
Remove-Item -LiteralPath "$FilePath" -Force
