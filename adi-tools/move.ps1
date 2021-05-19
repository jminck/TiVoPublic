$folders = Import-Csv "/Users/jminckler/OneDrive/TiVo/assets/vp15-complex-offers/out_v1/Users.jminckler.OneDrive.TiVo.assets.vp15-complex-offers.out_v1-assets-2021-04-06-16-42-02.CSV"
foreach ($f in $folders)
{
    $t = $f.Title.Replace(" (HD)","")
    $nf =  "/Users/jminckler/OneDrive/TiVo/assets/vp15-complex-offers/arranged/$t"
    mkdir $nf
    move-item $f.AssetFolder $nf
    dir $nf
}