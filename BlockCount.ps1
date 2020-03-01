<#
_  _ _  _  __  _ _    ____ ____ ____ _  _ ____ ____     
|__| |\/| /__\ | |    [__  |___ |__/ |  | |___ |__/     
|  | |  |/    \| |___ ___] |___ |  \  \/  |___ |  \     
                                                        
____ _ ____ ____ _ _ _  __  _    _       ___   __  _  _ 
|___ | |__/ |___ | | | /__\ |    |       |__] /__\ |\ | 
|    | |  \ |___ |_|_|/    \|___ |___    |__]/    \| \| 

.SYNOPSIS
	Analysis of Blocked IPs (firewall log drops)

.DESCRIPTION
	Counts number of firewall drops for a given number of days

.FUNCTIONALITY
	Run whenever you're curious

.NOTES
	Script runs until there are 0 firewall drops for a given number of days
	
.EXAMPLE

#>

# Include required files
Try {
	.("$PSScriptRoot\Config.ps1")
	.("$PSScriptRoot\CommonCode.ps1")
}
Catch {
	Write-Output "$((get-date).ToString(`"yy/MM/dd HH:mm:ss.ff`")) : ERROR : Unable to load supporting PowerShell Scripts : $query `n$Error[0]" | out-file "$PSScriptRoot\PSError.log" -append
}

$EmailBody = "$PSScriptRoot\BlockCountEmailBody.txt"

#	Delete old files if exist
If (Test-Path $EmailBody) {Remove-Item -Force -Path $EmailBody}

Write-Output '
<!DOCTYPE html> 
<html>
<head>
<title>hMailServer Firewall Ban</title>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
<meta http-equiv="Content-Style-Type" content="text/css">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
body {
	background: #fefefe;
	font-family: "Courier New";
	font-size: 10pt;
	}

a:link, a:active, a:visited {
	color: #FF0000;
	text-transform: underline;
	}

a:hover {
	color: #FF0000;
	text-transform: none;
	}

.header {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    color: #000;
	background: #fefefe;
    z-index: 1;
    overflow: hidden;
    text-align:center;
	}

.header h1 {
	font-size:25px;
    font-weight:normal;
	margin:0 auto;
	}

.header h2 {
	font-size:15px;
    font-weight:normal;
	margin:0 auto;
	}

.wrapper {
	max-width: 920px;
	position: relative;
	margin: 30px auto 30px auto;
	padding-top: 20px;
	}

.clear {
	clear: both;
	}

.banner {
	width: 100%;
	}

.headlinks {
	max-width: 720px;
	position:relative;
	margin: 0px auto;
	}

.headlinkwidth {
	width: 100%;
	min-width: 300px;
	position:relative;
	margin: 0 auto;
	}

.headlinks a:link, a:active, a:visited {
	color: #FF0000;
	text-transform: underline;
	}

.headlinks a:hover {
	color: #FF0000;
	text-transform: none;
	}

.section {
	padding: 5px 0 15px 0;
	margin: 0;
	}

.section h2 {
	font-size:16px;
    font-weight:bold;
	text-align:left;
	}

.section h3 {
	font-size:16px;
    font-weight:bold;
	}

.secleft {
	float: left;
	width: 49%;
	padding-right: 3px;
	}

.secright {
	float: right;
	width: 49%;
	padding-left: 3px;
	}

.secmap {
	float: none;
	width: 920px;
	height: 600px;
	padding: 0 0 10px 0;
	text-align: center;
}

table.section {
	border-collapse: collapse;
	border: 1px solid black;
	width: 100%;
	font-size: 10pt;
	}
	
table.section tr:nth-child(even) {
    background-color: #F8F8F8;
	}

table.section th, table.section td {
	border: 1px solid black;
	}

.footer {
	width: 100%;
	text-align: center;
	}
	
ul {
	list-style-type: none;
	padding: 0;
	}

li {
	padding: 0;
	display: inline;
	}
	
@media only screen and (max-width: 629px) {
	.secleft {
		float: none;
		width: 100%;
		padding: 0 0 10px 0;
		text-align: left;
	}
	.secright {
		float: none ;
		width: 100% ;
	}
	.secmap {
		float: none;
		width: 95%;
		height: 220px;
		padding: 0 0 10px 0;
		text-align: center;
	}
}	
</style>
</head>
<body>
<div class="wrapper">
' | Out-File $EmailBody -append

Write-Output '

hMailServer Firewall Ban Project<br>
Block Count<br>
Count number of drops from firewall log<br><br>

' | out-file $EmailBody -append

$StartTime = get-date

Write-Output "Run : $(Get-Date -f g)<br><br>" | out-file $EmailBody -append

#	Find oldest database entry and count days.
$Query = "Select MIN(timestamp) AS mints FROM hm_fwban"
MySQLQuery($Query) | ForEach {
	$Oldest = $_.mints
}
$NumDays = (New-TimeSpan $Oldest $(Get-Date)).Days

Write-Output ("{0,7} : Number of days data in database<br><br>" -f ($NumDays).ToString("#,###")) | out-file $EmailBody -append

#	Count number of bans in firewall ban database
$Query = "Select COUNT(ipaddress) AS countip from hm_fwban WHERE flag IS NULL"
MySQLQuery($Query) | ForEach {
	$TotalRules = $_.countip
}
Write-Output ("{0,7} : Total number of firewall rules<br><br>" -f ($TotalRules).ToString("#,###")) | out-file $EmailBody -append

#	Count number of distinct IPs recorded in repeat hit database
$Query = "Select COUNT(DISTINCT(ipaddress)) AS totalreturnips, COUNT(ipaddress) AS totalhits FROM hm_fwban_rh"
MySQLQuery($Query) | ForEach {
	$TotalReturnIPs = $_.totalreturnips
}

#	Subtract distinct IPs in RH database from number of bans in FWB database to derive number of FWBans that never returned
$PercentReturns = ([int]$TotalReturnIPs / [int]$TotalRules).ToString("P")
$NeverBlocked = ([int]$TotalRules - [int]$TotalReturnIPs)
$PercentNever = ([int]$NeverBlocked / [int]$TotalRules).ToString("P")
Write-Output ("{0,7} : {1,6} : Number of return IPs never blocked<br><br>" -f ($NeverBlocked).ToString("#,###"), $PercentNever) | out-file $EmailBody -append

#	Find number of distinct IPs that were blocked for a given number of days and continue until no results are found
$a = 0
Write-Output "<table cellpadding='5'>" | out-file $EmailBody -append
Do {
	$Query = "SELECT COUNT(*) AS countips FROM (SELECT ipaddress, COUNT(DISTINCT(DATE(timestamp))) AS countdate FROM hm_fwban_rh GROUP BY ipaddress HAVING countdate > $a) AS returnhits"
	MySQLQuery($Query) | ForEach {
		$ReturnIPs = $_.countips
	}
	$PercentReturns = ($ReturnIPs / $TotalRules)
	If ($ReturnIPs -lt 1) {
		Write-Output "<tr><td></td><td></td><td>No more results</td></tr>" | out-file $EmailBody -append
		$TimeElapsed = (New-TimeSpan $StartTime $(get-date))
		If (($TimeElapsed).Minutes -eq 1) {$sm = ""} Else {$sm = "s"}
		If (($TimeElapsed).Seconds -eq 1) {$ss = ""} Else {$ss = "s"}
		Write-Output ("<tr><td></td><td></td><td>Time Elapsed: {0:%m} minute$sm {0:%s} second$ss</td></tr>" -f $TimeElapsed) | out-file $EmailBody -append
	} Else {
		If ($a -eq 0) {$sd = ""} Else {$sd = "s"}
		Write-Output ("<tr><td style='text-align:right;'> {0,7} </td><td style='text-align:right;'> {1,6} </td><td> Number of return IPs blocked on at least <a href='$wwwURI/blocks-view.php?submit=Search&days=$($a + 1)'>$($a + 1) day$sd</a></td></tr>" -f ($ReturnIPs).ToString("#,###"), $PercentReturns.ToString("P")) | out-file $EmailBody -append
	}
	$a++
} Until ($ReturnIPs -lt 1)

Write-Output '
</table>
<br><br>
<div class="footer"></div>
</div> <!-- end WRAPPER -->
</body>
</html>
' | Out-File $EmailBody -append

$HTML = 'True'
EmailResults $HTML