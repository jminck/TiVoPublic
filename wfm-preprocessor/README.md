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
PS /wfm-preprocessor> ./Build-PackagesFromADIFiles.ps1
```
The process will perform the folllowing actions:
* Check if a .wfmready file already exists in the folder, and if so, do not process the folder, its already been processed
* Set Gross_price and Net_price fields based on value of existing Suggested_Price field
* Create Package_offer_ID field if:
    * Gross_price and Net_price are set to 0 
        * If a matching Provider_Content_Tier was found in packages.xml it is used as value of the field, otherwise the field is set to NOTFOUND.
* Rename the asset folder as <assetID>_<timestamp> per wfm requirements. 
* Check the last modified timestamp of assets in the folder, and if older than x minutes, mark the asset is ready for wfm ingestion by adding a <xml>.wfmready file to the folder, where <xml> is the base file name of the ADI xml file. If last modified time of any asset files is less than n minutes, assume the asset is still being transfered to the catcher and don't mark the folder as ready to ingest  