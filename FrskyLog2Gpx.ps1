<#
.SYNOPSIS
FrSkyLog2Gpx.ps1 - Convert a frsky log to GPX GPS format for use on sites like https://ayvri.com

.Description
The reason for this script is that finding tools online to convert is a hassle
as well as most don't deal with all the GPS formats in the FrSky logfile
depending on versions of FrSky hardware OS.  I needed to also use the vario
height data for altitude because GPS height data is inherently not as accurate
as GPS height data.  This is an optional thing to do.

.PARAMETER Filename
Source FrSky GPS log filename  (usually ends in .csv)

.PARAMETER UseVarioHeight
Option to use the vario height data instead of the GPS height data... assuming
you also have vario data in the logs.

.EXAMPLE
Frsky2Gpx.ps1 -UseVarioHeight -Filename "Arctus-2022-01-21-13-40-00.csv

.LINK
https://github.com/agibson2/ToolsForFrskyDevices

.NOTES
Author: Adam Gibson  (StatiC) on rcgroups

2022-05-30 1.0.6
 Fixed writing an exception error when it should not have
2022-05-29 1.0.5
 Fix  get-help FrskyLog2Gpx.ps1
2022-05-29 1.0.4
 Spelling error with Latitude in debug output
 Catch EXCEPTION trying to convert date and time
 Change output to show loading file and then start of converting
2022-05-29 1.0.3
 Major problems with detecting of some columns fixed
 Minor spelling
 Made some output text only show if -debug option used
2022-05-29 1.0.2
 Added -UseVarioHeight option to use the vario/altimeter height data (instead of GPS altitude)
2022-02-13 1.0.1
 Added Ethos logfile compatibility
2019-08-23 1.0.0
 Initial version
 

#>

param(
    [Parameter(Mandatory=$true, HelpMessage="FrSky log filename")] [string]$filename,
    [Parameter(HelpMessage="Use vario height data instead of GPS height data")] [switch]$UseVarioHeight
)

if ("$filename" -eq "") {
    write-output "Filename expected as first argument"
    exit 1
}


if (-Not (Test-Path -Path $Filename -PathType leaf)) {
    Write-Output "$Filename does not exist or cannot access it"
    exit 1
}

$basename = ([io.fileinfo]"$Filename").Basename
$directory = ([io.fileinfo]"$Filename").Directory
$OutputFile = "$directory\$basename.gpx"

write-output "Loading '$Filename' to determine columns"

$InCsv = Import-csv -Path $Filename

$GAltFeet = $False
$GaltMeters = $False
$AltFeet = $False
$AltMeters = $False
$AltKey = ""
$GPSInSingleColumn = $False
$LatitudeFound = $False
$LatitudeKey = ""
$LongitudeFound = $False
$LongitudeKey = ""
$GPSKey = ""

$ConvertToMeters = $False
$ColumnUsed = $False

$AltLabels = Get-member -InputObject $InCsv[0] | Where-Object {$_.MemberType -eq "NoteProperty"} | select-Object Name
ForEach ($AltLabel in $AltLabels) {
    if ( $UseVarioHeight -and (($AltLabel.Name -eq 'Alt(ft)') -or ($AltLabel.Name -eq 'Altitude(ft)')) ) {
        $AltFeet = $True
        $AltKey = $AltLabel.Name
        $ConvertToMeters = $True
        $ColumnUsed = $True
    } elseif ( $UseVarioHeight -and (($AltLabel.Name -eq 'Alt(m)') -or ($AltLabel.Name -eq 'Altitude(ft)')) ) {
        $AltMeters = $True
        $AltKey = $AltLabel.Name
        $ColumnUsed = $True
    } elseif ( -Not $UseVarioHeight -and (($AltLabel.Name -eq 'GAlt(m)') -or ($AltLabel.Name -eq 'GPS Alt(m)')) ){
        $GAltMeters = $True
        $AltKey = $AltLabel.Name
        $ColumnUsed = $True
    } elseif ( -Not $UseVarioHeight -and (($AltLabel.Name -eq 'GAlt(ft)') -or ($AltLabel.Name -eq 'GPS Alt(ft)')) ){
        $GAltFeet = $True
        $AltKey = $AltLabel.Name
        $ConvertToMeters = $True
        $ColumnUsed = $True
    } elseif ($altLabel.Name -eq 'GPS') {
        $GpsInSingleColumn = $True
        $GPSKey = $altLabel.Name
        $ColumnUsed = $True
    } elseif ($altLabel.Name -eq 'Longitude') {
        $LongitudeKey = $altLabel.Name
        $ColumnUsed = $True
    } elseif ($altLabel.Name -eq 'Latitude') {
        $LatitudeKey = $altLabel.Name
        $ColumnUsed = $True
    }
    
    If ($DebugPreference) {
        if( $ColumnUsed -eq $True) {
            write-output "Using column $($AltLabel.Name)"
        } else {
            write-output "Skipping column $($AltLabel.Name)"
        }
    }
    
    $ColumnUsed = $False
}

if ( $AltKey -eq "" ) {
    if( $UseVarioHeight ) {
        write-output "Did not detect any of Alt(ft), Alt(m) columns to use for altitude from vario/altimeter."
    } else {
        write-output "Did not detect GAlt(ft) or GAlt(m) columns to use for altitude from GPS sensor."
    }
    
    write-output "Are you sure this is a FrSky radio logfile? Is altimeter/vario data in the logs? Have you renamed the sensors to something else?"
    exit 1
}

if ( ($GPSKey -eq "") -and (($LatitudeKey -eq "") -or ($LongitudeKey -eq "")) ) {
    write-output "Did not find GPS, Lattitude, or Longitude columns"
    write-output "Are you sure this is a FrSky radio logfile? Is GPS in the logs?  Have you renamed the sensors to something else?"
    exit 1
}

if ($DebugPreference) { write-output "Conversion from feet to meters = $ConvertToMeters" }
if ($DebugPreference) { write-output "Using '$AltKey' for Altitude" }
if ($DebugPreference) {
    if ($GPSKey -ne "") {
        write-output "Using '$GPSKey' for Longitude and Latitude"
    } else {
        write-output "Using '$LongitudeKey' for Longitude"
        write-output "Using '$LatitudeKey' for Latitude"
    }
}

$DotInterval = $InCsv.Count / 100

$OutString = New-Object -TypeName System.Text.StringBuilder

[void]$OutString.Append("<?xml version=`"1.0`" encoding=`"UTF-8`"?>`n")
[void]$OutString.Append("<gpx version=`"1.1`" creator=`"FrskyLog2Gpx`" xmlns=`"http://www.topografix.com/GPX/1/1`" xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`" xsi:schemaLocation=`"http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd`">`n")
#[void]$OutString.Append("<!-- Used $AltKey in FrSky logfile for Altitude information -->`n")
[void]$OutString.Append("  <trk>`n")
[void]$OutString.Append("    <name>$basename</name>`n")
[void]$OutString.Append("    <trkseg>`n")

$NextDot = $DotInterval
$Count = 1
$PercentDone = 0

write-output "Converting '$Filename' to GPX format"

ForEach ($CsvLine in $InCsv) {
    if($GPSInSingleColumn) {
        $lon, $lat = $CsvLine.$GPSKey -Split (" ")
    } else {
        $lon = $CsvLine.$LongitudeKey
        $lat = $CsvLine.$LatitudeKey
    }
    $eledbl = [double] $CsvLine.$AltKey
    if ( $ConvertToMeters -eq $True ) {
        # Convert to meters
        $eledbl = [math]::Round(($eledbl * 0.3048), 1)
    }

    $time = $CsvLine.Time
    $date = $CsvLine.Date
    try {
        $dateandtime = ([datetime]::ParseExact("$date $time", "yyyy-MM-dd HH:mm:ss.fff", $null)).ToUniversalTime()
    }
    catch [System.FormatException] {
        write-output "EXCEPTION: Could not convert date and time '$date $time' using 'yyyy-MM-dd HH:mm:ss.fff' format."
        write-output "           Verify that the FrSky logfile Time column has the correct time data in it."
        write-output "           The only valid format known as an example is '2022-05-30 14:23:04.243'"
        exit 1
    }

    $dateandtimestr = $dateandtime.ToString('yyyy-MM-ddTHH:mm:ss.ff')

    [void]$OutString.Append("      <trkpt lat=`"$lat`" lon=`"$lon`">")
    [void]$OutString.Append("<ele>$eledbl</ele>")
    [void]$OutString.Append("<time>${dateandtimestr}Z</time>")
    [void]$OutString.Append("</trkpt>`n")

    if ($Count -gt $NextDot) {
        write-progress -Activity "Processing $Filename" -Status "$PercentDone% Complete ($Count/$($InCsv.Count):" -PercentComplete $PercentDone
        $NextDot += $DotInterval
        $PercentDone += 1
    }

    $Count += 1
}

[void]$OutString.Append("    </trkseg>`n")
[void]$OutString.Append("  </trk>`n")
[void]$OutString.Append("</gpx>`n")

$OutString2 = $OutString.ToString()

write-output $OutString2 | out-file -encoding utf8 $OutputFile
write-output "GPX file written to '$OutputFile'"
