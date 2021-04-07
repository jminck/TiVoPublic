$sourcefolder = "/tmp/2"
$catcher = "/mount/catcher/vp19/v1"
$assetfolder = "/mount/catcher/vp11/v3/General_Media/*"
dir $sourcefolder/*wfmready -Recurse | remove-item
$i = 0

$assetfolders = Get-ChildItem -Recurse $sourcefolder/*.xml
foreach ($asset in $assetfolders)
    {

       
       # new-item $destpath -ItemType Directory
       # Copy-Item (dir $asset.directoryname) $destpath -Recurse
        Copy-Item $assetfolder $asset.directory -verbose

        $readyfile = $asset.DirectoryName + "/" + $asset.basename + ".wfmready"
        if (!(Test-Path $readyfile))
        {
            new-Item $readyfile -ItemType File 
        }
        dir $readyfile
        $i++
        if ($i -ge 500) {break}
    }
