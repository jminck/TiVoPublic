# wfm-preprocessor

  

wfm-preprocessor adds required TiVo VOD extension fields to ADI files, and adds .wfmready files to asset folders to signal that the asset can be imported by TiVo VOD Workflow Manager.

  

### Preparation

  

##### Set variables in Build-PackagesFromADIFiles.ps1

Set the variable line to the correct root folder of the catcher path:

$adifiles = Get-ChildItem -Recurse __/assets/wfmtest/catcher/*.xml__

  

##### Build packages.xml

Execute Build-PackagesFromADIFiles.ps1 in a PowerShell command prompt to build a skeleton of package tier definitions from ADI folder path.

```sh

PS /wfm-preprocessor> ./Build-PackagesFromADIFiles.ps1

```

The script will produce an XML file with a schema like below. After the skeleton is produced, manually edit the resulting file and define tiers based on your desired SVOD package names, and associated Providers/Content tiers. The Tier name will be the Package_offer_ID field added to the ADI metadata.

  
  

<Assets>

<Provider_Content_Tier>

<Tier>

<Name>basic</Name>

<Providers>

<Provider>ABC</Provider>

</Providers>

<Provider_Content_Tiers>

<Provider_Content_Tier>ADULTSWIM_15</Provider_Content_Tier>

</Provider_Content_Tiers>

</Tier>

</Provider_Content_Tier>

</Assets>

  

##### Set variables in Convert-PitchedAssets.ps1

in Convert-PitchedAssets.ps1, edit the following variables to point to VOD catcher path and SVOD package definition:

$catcher = "/assets/wfmtest/catcher"

[xml]$packages = Get-Content "./packages.xml"

  

##### Execute Convert-PitchedAssets.ps1

Execute Convert-PitchedAssets.ps1 in a PowerShell command prompt to process the ADI folder structure

```sh

PS /wfm-preprocessor> ./Convert-PitchedAssets.ps1

```

The process will perform the folllowing actions:

* Check if a .wfmready file already exists in the folder, and if so, do not process the folder, its already been processed

* Set Gross_price and Net_price fields based on value of existing Suggested_Price field

* Create Package_offer_ID field if:

* Gross_price and Net_price are set to 0

* If a matching Provider_Content_Tier was found in packages.xml it is used as value of the field, otherwise the field is set to NOTFOUND.

* Rename the asset folder as <assetID>_<timestamp> per wfm requirements.

* Check the last modified timestamp of assets in the folder, and if older than x minutes, mark the asset is ready for wfm ingestion by adding a <xml>.wfmready file to the folder, where <xml> is the base file name of the ADI xml file. If last modified time of any asset files is less than n minutes, assume the asset is still being transfered to the catcher and don't mark the folder as ready to ingest

### Running in Linux
Install PowerShell for Linux (tested on PowerShell 7 preview 1 on RHEL 7.6)
```sh
wget https://github.com/PowerShell/PowerShell/releases/download/v7.0.0-preview.1/powershell-preview-7.0.0_preview.1-1.rhel.7.x86_64.rpm
sudo yum install -y powershell-preview-7.0.0_preview.1-1.rhel.7.x86_64.rpm
```
Launch PowerShell prompt by executing:
```sh
/opt/microsoft/powershell/7-preview/pwsh
```

PS /vagrant/TiVoStuff/wfm-preprocessor> dir *.ps1

Mode                 LastWriteTime         Length Name

----                 -------------         ------ ----

--r--            6/9/2019 11:52 AM           3855 Build-PackagesFromADI.ps1

--r--            6/9/2019 11:53 AM           1758 Convert-PitchedAssets.ps1

--r--            6/9/2019  7:29 AM          12871 PreprocessorFunctions.ps1


Execute the script:
```sh
PS /vagrant/TiVoStuff/wfm-preprocessor> ./Convert-PitchedAssets.ps1
```
Gross_price already exists, skipping

Net_price already exists, skipping

ADI.DTD 6/9/2019 11:43:53 AM

File is - -00:41:44.8913235 minutes old

APLH0017067700100002_20190609T122537Z.XML 6/9/2019 12:25:37 PM

File is - -00:00:00.8942146 minutes old


   Directory: /vagrant/assets/catcher/APLH0017067700100002_20190609T122537Z

Mode                 LastWriteTime         Length Name

----                 -------------         ------ ----

--r--            6/9/2019 12:25 PM              0 APLH0017067700100002_20190609T122537Z.wfmready

done
