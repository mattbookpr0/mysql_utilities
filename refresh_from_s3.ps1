$Bucket = 'YourSourceBucketName';
$BkpPath = 'C:\Path\to\your\working\directory\';
$AccessKey = 'YourAWSAccessKey';
$SecretKey = 'YourAWSSecretKey';
$DBUser = 'studio_dba'
$DatabaseEndpoint = "<target_db_endpoint>"
$DatabaseName = "<target_db_name_to_create>"
$RefreshFileDate = $((Get-Date).AddDays(0).ToString('yyyy-MM-dd')) # example for capturing today's date to use in file name
$DbZipFileName = "export_db_" + $RefreshFileDate + '-example.sql.zip'; # the source zip file in S3
$DropFile = $BkpPath + "DropDB.sql" # name for sql file to drop existing database
$PostRefreshScript = $BkpPath + "PostRefresh.sql" # name for sql file to run after refresh
$MySQLBin = "C:\Program` Files\MySQL\MySQL` Server` 8.0\bin\" # path to mysql bin
$env:Path += ";$MySQLBin"

Import-Module "C:\Program Files (x86)\AWS Tools\PowerShell\AWSPowerShell\AWSPowerShell.psd1";
Set-AWSCredential -AccessKey $AccessKey -SecretKey $SecretKey;

$LocalFile = $BkpPath + $DbZipFileName;
Read-S3Object -BucketName $Bucket -Key $DbZipFileName -File $LocalFile;
Expand-Archive -Force $LocalFile -DestinationPath $BkpPath;

$DbSQLFileName = $BkpPath + "export_db_" + $RefreshFileDate + '-example.sql';

if(Test-Path $LocalFile -PathType Leaf) {

    #Remove-Item –path $RefreshFile

    Remove-Item –path $DropFile
    Add-Content $DropFile "drop database $DatabaseName;";
    Add-Content $DropFile "create database $DatabaseName;";

    Remove-Item –path $PostRefreshScript
    Add-Content $PostRefreshScript "drop table last_refresh;";
    Add-Content $PostRefreshScript "create table last_refresh (refresh_file_datetime timestamp);";
    Add-Content $PostRefreshScript "insert into last_refresh values ('$RefreshFileDate');";
    Add-Content $PostRefreshScript "commit;";

    &cmd /c "mysql -h $DatabaseEndpoint -u $DBUser -pXXX --max_allowed_packet=1073741824 --force $DatabaseName < $DropFile"
    &cmd /c "mysql -h $DatabaseEndpoint -u $DBUser -pXXX --max_allowed_packet=1073741824 --force $DatabaseName < $DbSQLFileName"
    &cmd /c "mysql -h $DatabaseEndpoint -u $DBUser -pXXX --max_allowed_packet=1073741824 --force $DatabaseName < $PostRefreshScript"
}

Remove-Item –path $LocalFile -force
Remove-Item –path $DbSQLFileName -force

exit; 
