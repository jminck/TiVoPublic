$sourcefolder = "/assets/vp19/v1/out/adult"
$catcher = "/mount/catcher/vp19/v1"
$assetfolder = "/mount/catcher/vp11/v3/General_Media/*"
dir $sourcefolder/*wfmready -Recurse | remove-item
$i = 0

$assetfolders = Get-ChildItem -Recurse $sourcefolder/*.xml
foreach ($asset in $assetfolders)
    {
        write-host copying $asset.directoryname
        $destpath = $catcher + "/" +  $asset.directory.name
        if (!(Test-Path $destpath))
        {
        new-item $destpath -ItemType Directory
        Copy-Item (dir $asset.directoryname) $destpath -Recurse
        Copy-Item $assetfolder ($catcher.tostring() + "/" + $asset.Directory.BaseName.ToString()) -verbose
        $readyfile = $catcher + "/" + $asset.basename +"/" + $asset.Name.replace("xml","wfmready")       
        }
        else {
            {write-host $destpath already exists}
        }
        $readyfile = $destpath + "/" + $asset.basename + ".wfmready"
        if (!(Test-Path $readyfile))
        {
            new-Item $readyfile -ItemType File 
        }
        dir $readyfile
        $i++
        if ($i -ge 500) {break}
    }
