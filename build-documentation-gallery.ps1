Add-Type -AssemblyName PresentationCore

$sourceRoot = Join-Path $PSScriptRoot 'Documentation'
$outputRoot = Join-Path $sourceRoot 'Optimized'
$collections = [System.Collections.Generic.List[object]]::new()
$preferredOrder = @(
  'Learning Episodes 1 to 3 _ August 12, 2026',
  'Learning Episodes 4 to 6 _ August 19, 2026',
  'Learning Episodes 7 to 9 _ August 27, 2026',
  'Learning Episodes 10 to 12 _ September 2, 4 and 7, 2026',
  'Learning Episodes 13 and 14 _ September 9, 10, and 11, 2026',
  'Learning Episodes 15 and 16 _ September 16 and 23, 2026',
  'School Facilities and Learning Environment _ August 13, 2026'
)
$collectionFolders = foreach ($name in $preferredOrder) {
  $path = Join-Path $sourceRoot $name
  if (Test-Path $path) { Get-Item $path }
}

foreach ($folder in $collectionFolders) {
  $isSubjectCollection = $folder.Name -like 'Learning Episodes 13 and 14*'
  if ($isSubjectCollection) {
    $parts = foreach ($period in @('Mathematics Period', 'GMRC Period', 'TLE Period')) {
      $path = Join-Path $folder.FullName $period
      if (Test-Path $path) { Get-Item $path }
    }
  } else {
    $parts = @($folder)
  }
  $groups = [System.Collections.Generic.List[object]]::new()

  foreach ($part in $parts) {
    $images = [System.Collections.Generic.List[string]]::new()
    $sourceFiles = Get-ChildItem $part.FullName -File -Recurse | Where-Object Extension -Match '^\.(heic|jpg)$' | Sort-Object Name

    foreach ($source in $sourceFiles) {
      $relative = $source.FullName.Substring($sourceRoot.Length + 1)
      $targetRelative = [System.IO.Path]::ChangeExtension($relative, '.jpg')
      $target = Join-Path $outputRoot $targetRelative
      [System.IO.Directory]::CreateDirectory((Split-Path $target)) | Out-Null

      $stream = [System.IO.File]::OpenRead($source.FullName)
      try {
        $frame = [System.Windows.Media.Imaging.BitmapFrame]::Create(
          $stream,
          [System.Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat,
          [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        )
      } finally {
        $stream.Dispose()
      }

      $longestSide = [Math]::Max($frame.PixelWidth, $frame.PixelHeight)
      $scale = [Math]::Min(1.0, 1440.0 / $longestSide)
      if ($scale -lt 1.0) {
        $transform = [System.Windows.Media.ScaleTransform]::new($scale, $scale)
        $bitmap = [System.Windows.Media.Imaging.TransformedBitmap]::new($frame, $transform)
      } else {
        $bitmap = $frame
      }

      $encoder = [System.Windows.Media.Imaging.JpegBitmapEncoder]::new()
      $encoder.QualityLevel = 78
      $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
      $output = [System.IO.File]::Create($target)
      try {
        $encoder.Save($output)
      } finally {
        $output.Dispose()
      }

      $encodedPath = ($targetRelative -split '[\\/]+' | ForEach-Object { [System.Uri]::EscapeDataString($_) }) -join '/'
      $images.Add("Documentation/Optimized/$encodedPath")
    }

    $partTitle = if ($isSubjectCollection) { $part.Name } else { $null }
    $groups.Add([PSCustomObject]@{ title = $partTitle; images = @($images) })
  }

  $title = if ($folder.Name -like 'School Facilities*') {
    'School and Learning Environment | August 13, 2026'
  } else {
    $folder.Name -replace ' _ ', ' | '
  }
  $collections.Add([PSCustomObject]@{ title = $title; groups = @($groups) })
}

$manifest = 'window.documentationCollections = ' + (ConvertTo-Json -InputObject @($collections) -Depth 6) + ';'
Set-Content -Path (Join-Path $PSScriptRoot 'documentation-images.js') -Value $manifest -Encoding utf8

Write-Output "Built $($collections.Count) documentation collections and $((Get-ChildItem $outputRoot -Recurse -File -Filter '*.jpg').Count) optimized photos."