<#
.VERSION
1.0.2

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
you also have verio data in the logs.

.EXAMPLE
powershell Frsky2Gpx.ps1 -UseVarioHeight -Filename "Arctus-2022-01-21-13-40-00.csv

.NOTES
Author: Adam Gibson  (StatiC) on rcgroups

.CHANGELOG
2022-05-29 1.0.2
 Added use-vario-height option to use the vario height data (instead of hard coding it)
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

write-output "Converting $Filename to GPX format"

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

$ConvertToMeters = $False

$AltLabels = Get-member -InputObject $InCsv[0] | Where-Object {$_.MemberType -eq "NoteProperty"} | select-Object Name
ForEach ($AltLabel in $AltLabels) {
    if ($UseVarioHeight -and ($AltLabel.Name -eq 'Alt(ft)') -or ($AltLabel.Name -eq 'Altitude(ft)')) {
		write-output "Detecting Alt(ft)"
        $AltFeet = $True
		$AltKey = $AltLabel.Name
		$ConvertToMeters = $True
    } elseif ($UseVarioHeight -and ($AltLabel.Name -eq 'Alt(m)') -or ($AltLabel.Name -eq 'Altitude(ft)')) {
		write-output "Detecting Alt(m)"
        $AltMeters = $True
		$AltKey = $AltLabel.Name
    } elseif (-Not $UseVarioHeight -and ($AltLabel.Name -eq 'GAlt(m)') -or ($AltLabel.Name -eq 'GPS Alt(m)')){
		write-output "Detecting GAlt(ft)"
        $GAltMeters = $True
		$AltKey = $AltLabal.Name
    } elseif (-Not $UseVarioHeight -and ($AltLabel.Name -eq 'GAlt(ft)') -or ($AltLabel.Name -eq 'GPS Alt(ft)')){
		write-output "Detecting GAlt(ft)"
        $GAltFeet = $True
		$AltKey = $AltLabel.Name
		$ConvertToMeters = $True
	} elseif ($altLabel.Name -eq 'GPS') {
		$GpsInSingleColumn = $True
		$GPSKey = $altLabel.Name
	} elseif ($altLabel.Name -eq 'Longitude') {
		$LongitudeKey = $altLabel.Name
	} elseif ($altLabel.Name -eq 'Latitude') {
		$LatitudeKey = $altLabel.Name
	}
    If ($DebugPreference) { write-output "Column Name found: $($AltLabel.Name)" }
}

if ( $AltKey -eq "" ) {
	if( $UseVarioHeight ) {
		write-output "Did not detect any of Alt(ft), Alt(m) columns"
	} else {
		write-output "Did not detect any of GAlt(ft), or GAlt(m) columns"
	}
	
    write-output "Are you sure this is a FrSky radio logfile or have you renamed the sensors to something else?"
    exit 1
}

if ( ($GPSKey -eq "") -or (($LatitudeKey -eq "") -or ($LongitudeKey -eq "")) ) {
	if ($DebugPreference) { write-output "GPSKey=$GPSKey LatitudeKey=$LatitudeKey LongitudeKey=$LongitudeKey" }
	write-output "Did not find GPS, Lattitude, or Longitude columns"
    write-output "Are you sure this is a FrSky radio logfile or have you renamed the sensors to something else?"
	exit 1
}

if ($DebugPreference) { write-output "Conversion from feet to meters = $ConvertToMeters" }
if ($DebugPreference) { write-output "Using '$AltKey' for Altitude" }

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
    $dateandtime = ([datetime]::ParseExact("$date $time", "yyyy-MM-dd HH:mm:ss.fff", $null)).ToUniversalTime()
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
write-output "GPX file written to $OutputFile"
