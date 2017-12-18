    <#
        AUTHER      : Garvey Snow
        VERSION     : 1.0b
        DESCRIPTION : Polls Domain Controller's array for free space. If space is less than 30% move logfiles to storage
        DEPENDANCIES: RPC Server accepting connections
        DATE        : 23/11/2017
        SOURCES     : o--Clearing Event Log
                        |--https://serverfault.com/questions/460862/how-to-clear-windows-event-logs-using-command-line
    #>
    #================================#
    ######## DEDITION ################
    #================================#
    $destination_path = "\\ndc-nas\calvaryCareData\domain-controller-log-files"

    #=============================================#
    ######## PSDRIVE - WORKING DIRECTORY ##########
    #=============================================#
    New-PSDrive -Name 'SCRIPT_C_ROOT' -PSProvider FileSystem -Root "\\vprdscript\C$\Scripts\domain-controller-log-backups"
    
    #=================================#
    ###### HASH TABLE #################
    #=================================#
    $hash_container = @()

    #=================================#
    ### Generate Date Object ##########
    #=================================#
    $rawdate = (Get-Date | select datetime).datetime
    $formated_date = $rawdate.ToString() -replace ' ','-' -replace ',','' -replace ':','-'
    
    #================================#
    ####### HTML STRING START#########
    #================================#
    $html += '<h1>Log File Size Poller - Domain Controllers</h1>'
    $html += "<h style='color:lightblue;'>$rawdate</h3>"
    $html += "<h style='color:lightblue;'>ARCHIVE UNC PATH: $destination_path </h3>"
    $html += '<table style="border: 1px solid #f4f4f4" border="1">'
    $html += '<tbody>'
    $html += '<tr style="background-color: lightblue"><th>Site</th> <th>ServerName</th> <th>ProvisonedSpace</th> <th>FreeSpace</th> <th>PercentageFree</th> <th>ArchiveFiles</th> <td>ArchiveTotal</td> <th>LogFolderSize</th></tr>'
    
    #=================================#
    ###### START FOREACH LOOP #########
    #=================================#
    foreach($dc in (Import-Csv SCRIPT_C_ROOT:\domain-controllers.csv))
    {
        #==========================#
        ### RETRIVE Logical Disk ###
        #==========================#
        $logical_disk = Get-WmiObject -ComputerName $dc.Server -class win32_logicaldisk | ? { $_.DeviceID -eq "C:" }
        
        #==========================#
        ### CALCULATE Percentage ###
        #==========================#
        $FreeSpace_GB = [math]::round(($logical_disk.FreeSpace / 1GB),2)
        $Size_GB = [math]::round(($logical_disk.Size / 1GB),2)
        $Percentage_free = [math]::round(($logical_disk.FreeSpace / $logical_disk.Size * 100),2)
        
        #==============================#
        ### Generate Admin Share UNC ###
        #==============================#        
        $admin_c_share = "\\" + $dc.Server + "\c$" + "\Windows\System32\winevt\Logs"
        
        #==============================#
        ### Restrive Archive Files #####
        #==============================#         
        $archive_files = Get-ChildItem -Path $admin_c_share | where { $_.name -like "*Archive*" }
        $all_files_bytes_total = 0
        $all_files = Get-ChildItem -Recurse -Path $admin_c_share | % { $all_files_bytes_total += $_.length }
        #========================================================================#
        ### Restrive Archive Files #####
        ### $found_ac_container - Hold the contents of *archive logfile per loop*
        #========================================================================#           
        $found_ac_container = ''; # Container string to house found archive files - reset to $NUll per loop
        $archive_file_length_object = 0;# Lenth object - reset to 0 after every folder calculation
        foreach ($ac in $archive_files){ 
                                            <#Calculate total archive logfile size total#>
                                            $archive_file_length_object += $ac.Length
                                            
                                            <# Concat to String#>
                                            $found_ac_container += $ac.BaseName.toString() + '</br>' 
                                       }
        
        #===================================#
        ## Check if DC folder Exists ########
        #===================================#
        $dc_destination_folder_path = $destination_path + '\' + $dc.Server
        if(Test-Path -Path $dc_destination_folder_path){ <# No Nothing if folder exist #> }else{ mkdir $dc_destination_folder_path}
        
        #===================================#
        ## BUILD HTML REPORT OBJECT BODY ####
        #===================================#
        $html += '<tr >'
            $html += '<td>'; $html += $dc.Site;       $html += '</td>'
            $html += '<td>'; $html += $dc.Server;     $html += '</td>'
            $html += '<td>'; $html += $Size_GB;       $html += ' GB</td>'
            $html += '<td>'; $html += $FreeSpace_GB;  $html += ' GB</td>'

        if($Percentage_free -lt 10.00)
        {
            write-host -ForegroundColor gray 'Moving archive logfile ==>' -NoNewline; Write-Host -ForegroundColor Yellow $dc_destination_folder_path
            $html += '<td style="color:red">'; $html += $Percentage_free.ToString() + ' %' ; $html += '</td>'
            Robocopy.exe $admin_c_share $dc_destination_folder_path "*archive*.evtx" /z /move
        }
        
        elseif($Percentage_free -lt 30.00)
        {
            write-host -ForegroundColor gray 'Moving archive logfile ==>' -NoNewline; Write-Host -ForegroundColor Yellow $dc_destination_folder_path
            $html += '<td style="color:orange">'; $html += $Percentage_free.ToString() + ' %' ; $html += '</td>'
            Robocopy.exe $admin_c_share $dc_destination_folder_path "*archive*.evtx" /z /move
        }
        else
        {
            write-host -ForegroundColor gray 'No Archive file found' -NoNewline; Write-Host -ForegroundColor Yellow "--------------------"
            $html += '<td style="color:green">'; $html += $Percentage_free.ToString() + ' %' ; $html += '</td>'
            Robocopy.exe $admin_c_share $dc_destination_folder_path "*archive*.evtx" /z /move
        }
        
            $html += '<td>'; $html += $found_ac_container ; $html += '</td>'
            $html += '<td>'; $html += [math]::round(($archive_file_length_object / 1MB),2)  ; $html += ' MB</td>'
            $html += '<td>'; $html += [math]::round(($all_files_bytes_total / 1MB),2); $html += ' MB</td>'
        $html += '</tr>'


        ##################################
        # BUILD REPORT OBJECT IF NEEDED  #
        # • Alows export to csv          #
        ##################################
        $hash_container += New-Object -TypeName PSObject -Property @{
        
                                                                    
        
        
                                                                    }

    }#END FOREACH LOOP

$html += '</table>'

$to = ""

Send-MailMessage -To $to -From "" -Subject "" -Body $html -BodyAsHtml -SmtpServer ''

# TRUCATE STRING
$html = ''