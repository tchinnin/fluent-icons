# Get all icon folders
$assetsPath = ".\fluentui-system-icons\assets"
$iconFolders = Get-ChildItem -Path $assetsPath -Directory
$preferredSize = 24

$iconsList = @()
$noSVGIcons = @()
$progressCount = 0
$totalFolders = $iconFolders.Count

$outputPath = ".\icons.json"
# Start the JSON file with the opening structure
Set-Content -Path $outputPath -Value "{`"icons`": ["

foreach ($folder in $iconFolders) {
    Write-Progress -Activity "Processing Icons" -Status "Processing folder $($folder.Name)" -PercentComplete (($progressCount / $totalFolders) * 100)
    
    $metadataPath = Join-Path $folder.FullName "metadata.json"
    
    if (Test-Path $metadataPath) {
        # Process with metadata
        $metadata = Get-Content $metadataPath | ConvertFrom-Json
        
        # Find size closest to the preferredSize
        $preferredSize = 24
        $sizes = $metadata.size | Sort-Object
        $targetSize = if ($sizes -contains 24) {
            24
        } else {
            $sizes | Sort-Object { [Math]::Abs($_ - $preferredSize) } | Select-Object -First 1
        }
        
        $metadata.style = ($metadata.style | Where-Object { $_ -in @('filled', 'regular') })
        # Process each style
        foreach ($style in $metadata.style) {
            # Create standardized code
            $styleLower = $style.ToLower()
            $nameNormalized = $metadata.name.ToLower() -replace '[^a-z0-9]', ''
            $iconCode = "${nameNormalized}_${styleLower}"
            
            # Find corresponding SVG file
            $svgFileName = "ic_fluent_" + ($metadata.name -replace ' ', '_').ToLower() + "_${targetSize}_${styleLower}.svg"
            $pathParts = @($folder.FullName, "SVG", $svgFileName)
            $svgPath = $pathParts -join [System.IO.Path]::DirectorySeparatorChar
            # Read SVG content
            $svgContent = if (Test-Path $svgPath) {
                [System.IO.File]::ReadAllText($svgPath)
            } else {
                ""
            }
            
            # Create icon object
            $iconObject = [PSCustomObject]@{
                code = $iconCode
                name = $metadata.name
                size = $targetSize
                style = $style
                metaphors = $metadata.metaphor
                description = $metadata.description
                svg = $svgContent.Replace('"','''')
            }
            $iconsList += $iconObject
            $iconJson = ($iconObject | ConvertTo-Json -Compress).Replace('\u003c', '<').Replace('\u003e', '>').Replace('\u0027', "'").Replace('\r\n','')

            if ($folder -ne $iconFolders[-1] -or $style -ne $metadata.style[-1]) {
                $iconJson += ","
            }
            Add-Content $outputPath -Value $iconJson
        }
    } else {
        $svgPath = Join-Path $folder.FullName "SVG"
        $svgFiles = Get-ChildItem -Path $svgPath -Filter "*.svg"
        # if no svg files found, skip this folder
        if ($svgFiles.Count -eq 0) {
            Write-Host "No SVG files found in $($folder.Name)"
            $noSVGIcons += $folder.Name
        }
        if($svgFiles.Count -gt 1) {
            # Group files by style
            $svgFiles = $svgFiles | Where-Object { $_.Name -match "_(filled|regular)\.svg$" }
            $groupedFiles = $svgFiles | Group-Object {
                if ($_.Name -match "_(filled|regular)\.svg$") {
                    $matches[1]
                }
            }

            foreach ($styleGroup in $groupedFiles) {
                # Find file with size preferredSize or closest to it
                $files = $styleGroup.Group | Where-Object {
                    $_.Name -match "_(\d+)_"
                } | ForEach-Object {
                    # Replace ternary operator with if statement
                    $size = if ($_.Name -match "_(\d+)_") {
                        [int]$matches[1]
                    } else {
                        0
                    }
                    
                    [PSCustomObject]@{
                        File = $_
                        Size = $size
                    }
                }
                
                $targetFile = $files | Sort-Object { [Math]::Abs($_.Size - $preferredSize) } | Select-Object -First 1
                
                if ($targetFile) {
                    $svg = $targetFile.File
                    if ($svg.Name -match "ic_fluent_(.+?)_(\d+)_(filled|regular)\.svg") {
                        $iconName = $matches[1] -replace '_', ' '
                        $iconName = (Get-Culture).TextInfo.ToTitleCase($iconName)
                        $size = [int]$matches[2]
                        $style = (Get-Culture).TextInfo.ToTitleCase($matches[3])
                        
                        # Create standardized code
                        $nameNormalized = $iconName.ToLower() -replace '[^a-z0-9]', ''
                        $styleLower = $style.ToLower()
                        $iconCode = "${nameNormalized}_${styleLower}"
                        
                        # Read SVG content
                        $svgPath = $svg.FullName
                        $svgContent = if (Test-Path $svgPath) {
                            [System.IO.File]::ReadAllText($svgPath)
                        } else {
                            ""
                        }
                        
                        # Create icon object
                        $iconObject = [PSCustomObject]@{
                            code = $iconCode
                            name = $iconName
                            size = $size
                            style = $style
                            metaphors = @()
                            description = ""
                            svg = $svgContent.Replace('"','''')
                        }
                        $iconsList += $iconObject
                        $iconJson = ($iconObject | ConvertTo-Json -Compress).Replace('\u003c', '<').Replace('\u003e', '>').Replace('\u0027', "'").Replace('\r\n','')
                        if ($folder -ne $iconFolders[-1] -or $styleGroup -ne $groupedFiles[-1]) {
                            $iconJson += ","
                        }
                        Add-Content $outputPath -Value $iconJson
                    }
                }
            }  
        }
    }
    $progressCount++
}

Write-Progress -Activity "Processing Icons" -Completed

Add-Content -Path $outputPath -Value "]}"

# create a JSON file with all no svg icons
$noSVGIconsPath = ".\no-svg-icons.json"
$noSVGIcons | ConvertTo-Json -Compress | Set-Content $noSVGIconsPath

$finalObject | ConvertTo-Json -Depth 10 -Compress | Set-Content $outputPath

Write-Host "Generated icons.json with $($iconsList.Count) icons"