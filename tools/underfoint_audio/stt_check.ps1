# Windows dictation over every .wav in a folder (16 kHz copies made by stt_check.py): prints "<name><TAB><what it heard>". A rough intelligibility check, nothing more.
param([string]$Dir)
Add-Type -AssemblyName System.Speech
foreach ($f in Get-ChildItem -Path $Dir -Filter *.wav | Sort-Object Name) {
    $eng = New-Object System.Speech.Recognition.SpeechRecognitionEngine([System.Globalization.CultureInfo]::GetCultureInfo("en-US"))
    $eng.LoadGrammar((New-Object System.Speech.Recognition.DictationGrammar))
    $eng.SetInputToWaveFile($f.FullName)
    $eng.InitialSilenceTimeout = [TimeSpan]::FromSeconds(3)
    $eng.BabbleTimeout = [TimeSpan]::FromSeconds(4)
    $eng.EndSilenceTimeout = [TimeSpan]::FromSeconds(0.5)
    $heard = @()
    for ($i = 0; $i -lt 8; $i++) {
        try { $r = $eng.Recognize(); if ($r -eq $null) { break }; $heard += $r.Text } catch { break }
    }
    $eng.Dispose()
    $f.BaseName + "`t" + ($heard -join " ")
}
